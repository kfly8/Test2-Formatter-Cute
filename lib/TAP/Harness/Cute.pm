package TAP::Harness::Cute;
use strict;
use warnings;
use base 'TAP::Harness';

our $VERSION = '0.01';

=head1 NAME

TAP::Harness::Cute - Harness for Test2::Formatter::Cute

=head1 SYNOPSIS

    use TAP::Harness::Cute;
    my $harness = TAP::Harness::Cute->new({
        verbosity => 1,
        lib => ['lib'],
        switches => ['-w'],
    });
    my $result = $harness->runtests(@test_files);

=head1 DESCRIPTION

TAP::Harness::Cute is a test harness that supports Test2::Formatter::Cute's
non-TAP output format. This harness is designed for making a small number of
tests more readable and visually appealing.

Unlike TAP::Harness which expects TAP format, this harness works with
Test2::Formatter::Cute's custom output format.

B<Note:> This harness does not support parallel test execution (C<-j> option).
It runs tests sequentially to ensure proper output formatting and readability.
For large test suites that require parallel execution, use the standard
TAP::Harness instead.

=cut

sub new {
    my ($class, $args) = @_;
    $args ||= {};

    # Call parent constructor
    my $self = $class->SUPER::new($args);

    return $self;
}

sub runtests {
    my ($self, @tests) = @_;

    return unless @tests;

    my $verbose = ($self->{verbosity} || 0) > 0;

    # Build command line options from TAP::Harness settings
    my @lib_args = ();
    if ($self->{lib}) {
        @lib_args = map { ("-I", $_) } @{ $self->{lib} };
    }
    my @switches = $self->{switches} ? @{ $self->{switches} } : ();

    # Run tests sequentially
    my %stats = $self->_run_sequential(\@tests, \@lib_args, \@switches, $verbose);

    # Print final summary
    $self->_print_final_summary(\%stats, $verbose);

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

sub _print_final_summary {
    my ($self, $stats, $verbose) = @_;

    my $files = $stats->{files};
    my $tests = $stats->{tests};
    my $pass = $stats->{pass};
    my $fail = $stats->{fail};
    my $todo = $stats->{todo};
    my $duration = $stats->{duration};
    my $failed_files = $stats->{failed_files} || [];
    my $seed = $stats->{seed};

    # Check if color is disabled
    my $use_color = 1;
    if (defined $ENV{T2_FORMATTER_CUTE_COLOR}) {
        $use_color = $ENV{T2_FORMATTER_CUTE_COLOR} ? 1 : 0;
    }

    # Color codes
    my $GREEN = $use_color ? "\e[32m" : '';
    my $RED = $use_color ? "\e[31m" : '';
    my $GREEN_BG = $use_color ? "\e[42m\e[1m\e[38;5;16m" : '';
    my $RED_BG = $use_color ? "\e[41m\e[1m\e[38;5;16m" : '';
    my $RESET = $use_color ? "\e[0m" : '';

    # Determine if all tests passed
    my $all_passed = scalar(@$failed_files) == 0;

    if ($all_passed) {
        # Success case
        print $GREEN_BG . " PASS " . $RESET . " " . $GREEN . "All tests successful." . $RESET . "\n";
        # Build summary line
        my @parts = ("Files=$files", "Tests=$tests");
        push @parts, "Todo=$todo" if $todo > 0;
        push @parts, sprintf("Duration=%.2fms", $duration);
        push @parts, "Seed=$seed" if defined $seed;
        print join(", ", @parts) . "\n";
    } else {
        # Failure case
        print $RED_BG . " FAIL " . $RESET . " " . $RED . "Tests failed." . $RESET . "\n";
        # Build summary line
        my @parts = ("Files=$files", "Tests=$tests");
        push @parts, "Pass=$pass" if $pass > 0;
        push @parts, "Fail=$fail" if $fail > 0;
        push @parts, "Todo=$todo" if $todo > 0;
        push @parts, sprintf("Duration=%.2fms", $duration);
        push @parts, "Seed=$seed" if defined $seed;
        print join(", ", @parts) . "\n";
        # Print failed files list (only in verbose mode)
        if ($verbose && @$failed_files) {
            print "Failed files:\n";
            for my $file (@$failed_files) {
                print "  " . $RED . $file . $RESET . "\n";
            }
        }
    }
}

1;

__END__

=head1 METHODS

=head2 new

    my $harness = TAP::Harness::Cute->new(\%args);

Creates a new harness. Accepts the following options:

=over 4

=item * verbosity - Verbosity level (0 = quiet, 1+ = verbose)

=item * lib - Array ref of library paths to include

=item * switches - Array ref of Perl switches (e.g., C<['-w']>)

=item * color - Enable/disable color output (default: 1)

=back

B<Note:> Unlike TAP::Harness, this harness does not support the C<jobs>
parameter for parallel test execution.

=head2 runtests

    my $result = $harness->runtests(@test_files);

Runs the specified test files and returns aggregated statistics.

=head1 SEE ALSO

L<TAP::Harness>, L<Test2::Formatter::Cute>

=cut
