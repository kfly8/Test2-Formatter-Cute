package TAP::Harness::Cute;
use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

TAP::Harness::Cute - Harness for Test2::Formatter::Cute

=head1 SYNOPSIS

    use TAP::Harness::Cute;
    my $harness = TAP::Harness::Cute->new({
        verbosity => 1,
        jobs => 4,  # parallel execution
        lib => ['lib'],
        switches => ['-w'],
    });
    my $result = $harness->runtests(@test_files);

=head1 DESCRIPTION

TAP::Harness::Cute is a test harness that supports Test2::Formatter::Cute's
non-TAP output format while providing parallel test execution and other
features expected from a test harness.

Unlike TAP::Harness which expects TAP format, this harness works with
Test2::Formatter::Cute's custom output format.

=cut

sub new {
    my ($class, $args) = @_;
    $args ||= {};

    my $self = bless {
        verbosity => $args->{verbosity} || 0,
        jobs => $args->{jobs} || 1,
        lib => $args->{lib} || [],
        switches => $args->{switches} || [],
        color => $args->{color} // 1,
        test_args => $args->{test_args} || [],
    }, $class;

    return $self;
}

sub runtests {
    my ($self, @tests) = @_;

    return unless @tests;

    my $jobs = $self->{jobs};
    my $verbose = $self->{verbosity} > 0;

    # Build command line options
    my @lib_args = map { ("-I", $_) } @{ $self->{lib} };
    my @switches = @{ $self->{switches} };

    # Track statistics
    my %stats = (
        files => scalar(@tests),
        tests => 0,
        pass => 0,
        fail => 0,
        todo => 0,
        duration => 0,
        seed => undef,
        failed_files => [],
    );

    if ($jobs > 1) {
        # Parallel execution
        %stats = $self->_run_parallel(\@tests, \@lib_args, \@switches, $verbose);
    } else {
        # Sequential execution
        %stats = $self->_run_sequential(\@tests, \@lib_args, \@switches, $verbose);
    }

    return \%stats;
}

sub _run_sequential {
    my ($self, $tests, $lib_args, $switches, $verbose) = @_;

    my %stats = (
        files => scalar(@$tests),
        tests => 0,
        pass => 0,
        fail => 0,
        todo => 0,
        duration => 0,
        seed => undef,
        failed_files => [],
    );

    for my $test (@$tests) {
        my $result = $self->_run_single_test($test, $lib_args, $switches, $verbose);

        # Aggregate statistics
        $stats{tests} += $result->{tests} || 0;
        $stats{pass} += $result->{pass} || 0;
        $stats{fail} += $result->{fail} || 0;
        $stats{todo} += $result->{todo} || 0;
        $stats{duration} += $result->{duration} || 0;

        # Capture first seed
        $stats{seed} ||= $result->{seed};

        # Track failed files
        push @{$stats{failed_files}}, $test if $result->{failed};
    }

    return %stats;
}

sub _run_parallel {
    my ($self, $tests, $lib_args, $switches, $verbose) = @_;

    # For now, fall back to sequential
    # TODO: Implement parallel execution using fork or Parallel::ForkManager
    return $self->_run_sequential($tests, $lib_args, $switches, $verbose);
}

sub _run_single_test {
    my ($self, $test, $lib_args, $switches, $verbose) = @_;

    my @cmd = ($^X, @$switches, @$lib_args, $test);

    # Run test and capture output
    open my $fh, '-|', @cmd or die "Cannot run test $test: $!";

    my $output = '';
    while (my $line = <$fh>) {
        $output .= $line;
    }
    close $fh;
    my $exit_code = $?;

    # Display output
    if ($verbose) {
        # Verbose mode: show full output without summary lines
        my $filtered = $self->_remove_summary_lines($output);
        print $filtered if $filtered;
    } else {
        # Non-verbose mode: show only file header
        my @lines = split /\n/, $output;
        my $found_header = 0;
        for my $line (@lines) {
            # Print file header line (e.g., "✓ t/test.t [1.23ms]")
            my $clean = $line;
            $clean =~ s/\x1b\[[0-9;]*m//g;
            if ($clean =~ /^✓\s+/ || $clean =~ /^✘\s+/) {
                print $line . "\n";
                $found_header = 1;
                last;
            }
        }
        # If no header found, print first non-empty line
        unless ($found_header) {
            for my $line (@lines) {
                next if $line =~ /^\s*$/;
                next if $line =~ /use_numbers/;  # Skip warning
                print $line . "\n";
                last;
            }
        }
    }

    # Parse statistics from output
    my $stats = $self->_parse_test_output($output);
    $stats->{failed} = ($exit_code != 0);

    return $stats;
}

sub _parse_test_output {
    my ($self, $output) = @_;

    my %result = (
        tests => 0,
        pass => 0,
        fail => 0,
        todo => 0,
        duration => 0,
        seed => undef,
    );

    # Remove ANSI codes
    my $clean = $output;
    $clean =~ s/\x1b\[[0-9;]*m//g;

    # Check if all tests passed
    my $all_passed = $clean =~ /PASS.*All\s+tests\s+successful/;

    # Find summary line like: "Files=1, Tests=7, Duration=1.10ms, Seed=12345"
    my @lines = split /\n/, $clean;
    for my $line (@lines) {
        if ($line =~ /Files=\d+/) {
            $line =~ /Tests=(\d+)/ and $result{tests} = $1;
            $line =~ /Pass=(\d+)/ and $result{pass} = $1;
            $line =~ /Fail=(\d+)/ and $result{fail} = $1;
            $line =~ /Todo=(\d+)/ and $result{todo} = $1;
            if ($line =~ /Duration=([\d.]+)(ms|s)/) {
                $result{duration} = $1;
                $result{duration} *= 1000 if $2 eq 's';
            }
            $line =~ /Seed=([^,\s]+)/ and $result{seed} = $1;
        }
    }

    # If all tests passed and Pass was not explicitly stated, assume Tests=Pass
    if ($all_passed && $result{pass} == 0 && $result{fail} == 0 && $result{tests} > 0) {
        $result{pass} = $result{tests};
    }

    return \%result;
}

sub _remove_summary_lines {
    my ($self, $output) = @_;

    my @lines = split /\n/, $output, -1;
    my @filtered;

    for my $line (@lines) {
        # Skip summary lines
        next if $line =~ /PASS.*All\s+tests\s+successful/;
        next if $line =~ /FAIL.*Tests\s+failed/;
        next if $line =~ /^Files=\d+/;

        push @filtered, $line;
    }

    return join("\n", @filtered);
}

1;

__END__

=head1 METHODS

=head2 new

    my $harness = TAP::Harness::Cute->new(\%args);

Creates a new harness. Accepts the following options:

=over 4

=item * verbosity - Verbosity level (0 = quiet, 1+ = verbose)

=item * jobs - Number of parallel jobs (default: 1)

=item * lib - Array ref of library paths

=item * switches - Array ref of Perl switches

=item * color - Enable/disable color output (default: 1)

=back

=head2 runtests

    my $result = $harness->runtests(@test_files);

Runs the specified test files and returns aggregated statistics.

=head1 SEE ALSO

L<TAP::Harness>, L<Test2::Formatter::Cute>

=cut
