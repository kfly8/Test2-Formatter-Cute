package App::Prove::Plugin::Cute;
use strict;
use warnings;

sub load {
    my ($class, $p) = @_;
    my @args = @{ $p->{args} };
    my $app = $p->{app_prove};

    # Set T2_FORMATTER environment variable for test execution
    $ENV{T2_FORMATTER} = 'Cute';

    # Check if color is disabled via --nocolor option
    # App::Prove stores color setting in the 'color' attribute
    unless (defined $ENV{T2_FORMATTER_CUTE_COLOR}) {
        # If --nocolor was passed, $app->color will be 0
        # If --color was passed or color is auto-detected, $app->color will be 1
        if (defined $app->color) {
            $ENV{T2_FORMATTER_CUTE_COLOR} = $app->color;
        } else {
            # Default to enabled (since we capture output, -t check fails)
            $ENV{T2_FORMATTER_CUTE_COLOR} = 1;
        }
    }

    # Monkey patch App::Prove::_runtests to use TAP::Harness::Cute
    # which supports Test2::Formatter::Cute's non-TAP output
    {
        no warnings 'redefine';
        my $original_runtests = \&App::Prove::_runtests;

        *App::Prove::_runtests = sub {
            my ( $self, $args, @tests ) = @_;

            # Load our custom harness
            require TAP::Harness::Cute;

            # Create harness with App::Prove's settings
            my $harness = TAP::Harness::Cute->new({
                verbosity => $args->{verbosity} || 0,
                jobs => $args->{jobs} || 1,
                lib => $args->{lib} || [],
                switches => $args->{switches} || [],
                color => $ENV{T2_FORMATTER_CUTE_COLOR} // 1,
            });

            # Run tests through our custom harness
            my $stats = $harness->runtests(@tests);

            # Print final summary in Cute format
            _print_final_summary(
                files => $stats->{files},
                tests => $stats->{tests},
                pass => $stats->{pass},
                fail => $stats->{fail},
                todo => $stats->{todo},
                duration => $stats->{duration},
                failed_files => $stats->{failed_files},
                verbose => ($args->{verbosity} || 0) > 0,
                seed => $stats->{seed},
            );

            return scalar(@{$stats->{failed_files}}) == 0;
        };
    }

    return 1;
}

sub _print_final_summary {
    my %args = @_;

    my $files = $args{files};
    my $tests = $args{tests};
    my $pass = $args{pass};
    my $fail = $args{fail};
    my $todo = $args{todo};
    my $duration = $args{duration};
    my $failed_files = $args{failed_files} || [];
    my $verbose = $args{verbose} || 0;
    my $seed = $args{seed};

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

=encoding utf8

=head1 NAME

App::Prove::Plugin::Cute - Makes your test output cute and easy

=head1 SYNOPSIS

  prove -PCute -lvr t/

=head1 DESCRIPTION

App::Prove::Plugin::Cute makes your Perl test output visually clearer and easier
by configuring L<Test2::Formatter::Cute> as the test formatter.

This plugin delegates test execution to TAP::Harness (via C<make_harness>),
which supports features like parallel test execution (C<-j> option). The plugin
preserves the Cute formatter output while providing an aggregated summary.

The following is an example output:

  ✘ t/examples/failed.pl [0.75ms]
    ✘ foo [0.52ms]
      ✓ case1
      ✘ case2
      ✘ case3

   FAIL t/examples/failed.pl > foo > case2

    Received eq Expected

    Expected: 1
    Received: 0

    ❯ t/examples/failed.pl:5
      1 | use Test2::V0;
      2 |
      3 | subtest 'foo' => sub {
      4 |     is 1+1, 2, 'case1';
    ✘ 5 |     is 1-1, 1, 'case2';

  FAIL Tests failed.
  Files=1, Tests=3, Pass=1, Fail=2, Duration=0.71ms, Seed=20251024
  Failed files:
    t/examples/failed.pl

=head1 SEE ALSO

L<Test2::Formatter::Cute>

