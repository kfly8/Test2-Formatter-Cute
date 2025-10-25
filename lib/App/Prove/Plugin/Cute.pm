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

    # Monkey patch App::Prove::_runtests to delegate test execution to TAP::Harness
    # while preserving Test2::Formatter::Cute output formatting
    {
        no warnings 'redefine';
        my $original_runtests = \&App::Prove::_runtests;

        *App::Prove::_runtests = sub {
            my ( $self, $args, @tests ) = @_;

            # Check verbose mode (verbosity > 0 means -v was passed)
            my $verbose = ($args->{verbosity} || 0) > 0;

            # Get the harness that App::Prove would use
            # This supports parallel execution via -j option, etc.
            my $harness = $self->make_harness;

            # Capture harness output to parse Cute formatter summary
            my $output = '';
            {
                # Temporarily redirect STDOUT to capture harness output
                local *STDOUT;
                open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";

                # Run tests through TAP::Harness (supports -j for parallel execution)
                $harness->runtests(@tests);
            }

            # Parse the captured output for statistics
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

            # Extract and aggregate statistics from each test file's Cute formatter output
            my @lines = split /\n/, $output;
            for my $line (@lines) {
                # Each test file outputs its own summary line like:
                # "Files=1, Tests=7, Duration=1.10ms, Seed=12345"
                # We need to aggregate these
                if ($line =~ /Files=\d+/) {
                    # Summary line found, parse it
                    if ($line =~ /Tests=(\d+)/) {
                        $stats{tests} += $1;
                    }
                    if ($line =~ /Pass=(\d+)/) {
                        $stats{pass} += $1;
                    }
                    if ($line =~ /Fail=(\d+)/) {
                        $stats{fail} += $1;
                    }
                    if ($line =~ /Todo=(\d+)/) {
                        $stats{todo} += $1;
                    }
                    if ($line =~ /Duration=([\d.]+)(ms|s)/) {
                        my $duration = $1;
                        my $unit = $2;
                        # Convert to ms if needed
                        $duration *= 1000 if $unit eq 's';
                        $stats{duration} += $duration;
                    }
                    # Capture seed from first test (if available)
                    if (!defined $stats{seed} && $line =~ /Seed=([^,\s]+)/) {
                        $stats{seed} = $1;
                    }
                }
            }

            # Display the captured output (preserves Cute formatting)
            if ($verbose) {
                # Verbose mode: show full output without final summaries
                my $filtered = _remove_summary_lines($output);
                print $filtered . "\n" if $filtered;
            } else {
                # Non-verbose mode: show only file headers (first line of each test)
                for my $line (@lines) {
                    # Print lines that look like file headers (e.g., "✓ t/test.t [1.23ms]")
                    if ($line =~ /^[✓✘] /) {
                        print $line . "\n";
                    }
                }
            }

            # Get test results from harness
            my $aggregator = $harness->aggregator;
            my @failed_files = ();
            if ($aggregator) {
                # Collect failed test files
                for my $parser ($aggregator->parsers) {
                    if ($parser->has_problems) {
                        push @failed_files, $parser->name;
                    }
                }
            }

            # Print final summary in Cute format
            _print_final_summary(
                files => $stats{files},
                tests => $stats{tests},
                pass => $stats{pass},
                fail => $stats{fail},
                todo => $stats{todo},
                duration => $stats{duration},
                failed_files => \@failed_files,
                verbose => $verbose,
                seed => $stats{seed},
            );

            return scalar(@failed_files) == 0;
        };
    }

    return 1;
}

sub _parse_summary {
    my ($output) = @_;

    my %result = (
        tests => 0,
        todo => 0,
        duration => 0,
        # pass and fail are undefined by default to distinguish
        # "no explicit Pass/Fail in summary" from "Pass=0, Fail=0"
    );

    # Find summary line like: Files=1, Tests=7, Duration=1.10ms, Seed=12345
    # Match the entire line after Files=
    if ($output =~ /Files=\d+[^\n]*/) {
        my $summary_line = $&;

        if ($summary_line =~ /Tests=(\d+)/) {
            $result{tests} = $1;
        }
        if ($summary_line =~ /Pass=(\d+)/) {
            $result{pass} = $1;
        }
        if ($summary_line =~ /Fail=(\d+)/) {
            $result{fail} = $1;
        }
        if ($summary_line =~ /Todo=(\d+)/) {
            $result{todo} = $1;
        }
        if ($summary_line =~ /Duration=([\d.]+)(ms|s)/) {
            $result{duration} = $1;
            $result{duration_unit} = $2;
        }
        if ($summary_line =~ /Seed=([^,\s]+)/) {
            $result{seed} = $1;
        }
    }

    return \%result;
}

sub _remove_summary_lines {
    my ($output) = @_;

    my @lines = split /\n/, $output, -1;
    my @filtered;

    for my $line (@lines) {
        # Skip only final summary lines (not failure details)
        # Note: Lines may contain ANSI color codes like \e[42m\e[1m\e[38;5;16m PASS \e[0m
        # Use a flexible pattern that allows for escape sequences

        # Remove " PASS  All tests successful." (with possible color codes)
        next if $line =~ /PASS.*All\s+tests\s+successful/;
        # Remove " FAIL  Tests failed." (with possible color codes)
        next if $line =~ /FAIL.*Tests\s+failed/;
        # Remove "Files=..." summary statistics line
        next if $line =~ /^Files=\d+/;

        push @filtered, $line;
    }

    return join("\n", @filtered);
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

