package App::Prove::Plugin::Cute;
use strict;
use warnings;

=head1 NAME

App::Prove::Plugin::Cute - Prove plugin to enable Test2::Formatter::Cute

=head1 SYNOPSIS

  # Use with prove
  prove -PCute -l t/

  # Run multiple tests
  prove -PCute -l t/*.t

  # Enable debug mode
  T2_FORMATTER_CUTE_DEBUG=1 prove -PCute -l t/

=head1 DESCRIPTION

This plugin enables Test2::Formatter::Cute to work with the prove command by:

1. Setting T2_FORMATTER=Cute environment variable
2. Monkey-patching App::Prove::_runtests to bypass TAP::Harness
3. Running tests directly with Test2::Formatter::Cute
4. Providing a test summary

This approach completely bypasses TAP parsing, allowing the cute emoji format
to be displayed properly.

=cut

sub load {
    my ($class, $p) = @_;
    my @args = @{ $p->{args} };
    my $app = $p->{app_prove};

    # Set T2_FORMATTER environment variable for test execution
    $ENV{T2_FORMATTER} = 'Cute';

    # Enable color by default (since we capture output, -t check fails)
    # Users can still disable with T2_FORMATTER_CUTE_COLOR=0
    $ENV{T2_FORMATTER_CUTE_COLOR} = 1 unless defined $ENV{T2_FORMATTER_CUTE_COLOR};

    # Monkey patch App::Prove::_runtests to bypass TAP::Harness
    # and run tests directly with Test2::Formatter::Cute
    {
        no warnings 'redefine';
        my $original_runtests = \&App::Prove::_runtests;

        *App::Prove::_runtests = sub {
            my ( $self, $args, @tests ) = @_;

            # Build lib arguments
            my @lib_args = ();
            if ($args->{lib}) {
                @lib_args = map { ("-I", $_) } @{ $args->{lib} };
            }

            # Build switches arguments
            my @switches = ();
            if ($args->{switches}) {
                @switches = @{ $args->{switches} };
            }

            # Track results
            my $total_files = scalar @tests;
            my $total_tests = 0;
            my $total_pass = 0;
            my $total_fail = 0;
            my $total_todo = 0;
            my $total_duration = 0;
            my @failed_files = ();

            # Run each test directly
            for my $test (@tests) {
                my @cmd = ($^X, @switches, @lib_args, $test);

                # Show command in debug mode
                if ($ENV{T2_FORMATTER_CUTE_DEBUG}) {
                    print "# Running: @cmd\n\n";
                }

                # Capture output for parsing
                open my $fh, '-|', @cmd or die "Cannot run test: $!";

                my $output = '';
                while (my $line = <$fh>) {
                    $output .= $line;
                }
                close $fh;
                my $exit_code = $?;

                # Parse summary line from output
                my $summary = _parse_summary($output);

                # Accumulate statistics
                my $tests = $summary->{tests} || 0;
                my $pass = $summary->{pass};
                my $fail = $summary->{fail};

                # If Pass/Fail not explicitly provided, calculate from exit code
                if (!defined $pass && !defined $fail) {
                    if ($exit_code == 0) {
                        $pass = $tests;
                        $fail = 0;
                    } else {
                        # Cannot determine exact pass/fail split without explicit counts
                        # But we know there was at least one failure
                        $pass = 0;
                        $fail = 0;
                    }
                }

                $total_tests += $tests;
                $total_pass += (defined $pass ? $pass : 0);
                $total_fail += (defined $fail ? $fail : 0);
                $total_todo += $summary->{todo} || 0;
                $total_duration += $summary->{duration} || 0;

                if ($exit_code != 0) {
                    push @failed_files, $test;
                }

                # Filter out summary lines and print
                my $filtered_output = _remove_summary_lines($output);
                print $filtered_output;
                print "\n";
            }

            # Print final summary
            _print_final_summary(
                files => $total_files,
                tests => $total_tests,
                pass => $total_pass,
                fail => $total_fail,
                todo => $total_todo,
                duration => $total_duration,
                failed_files => \@failed_files,
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

    # Find summary line like: Files=1, Tests=7, Duration=1.10ms, ...
    if ($output =~ /Files=\d+.*?Duration=[\d.]+\w+/) {
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

    # Check if color is disabled
    my $use_color = 1;
    if (defined $ENV{T2_FORMATTER_CUTE_COLOR}) {
        $use_color = $ENV{T2_FORMATTER_CUTE_COLOR} ? 1 : 0;
    }

    # Color codes
    my $GRAY = $use_color ? "\e[90m" : '';
    my $GREEN = $use_color ? "\e[32m" : '';
    my $RED = $use_color ? "\e[31m" : '';
    my $GREEN_BG = $use_color ? "\e[42m\e[1m\e[38;5;16m" : '';
    my $RED_BG = $use_color ? "\e[41m\e[1m\e[38;5;16m" : '';
    my $RESET = $use_color ? "\e[0m" : '';

    # Print separator line
    print $GRAY . ('━' x 80) . $RESET . "\n\n";

    # Determine if all tests passed
    my $all_passed = scalar(@$failed_files) == 0;

    if ($all_passed) {
        # Success case
        print $GREEN_BG . " PASS " . $RESET . "  " . $GREEN . "All tests successful." . $RESET . "\n";

        # Build summary line
        my @parts = ("Files=$files", "Tests=$tests");
        push @parts, "Todo=$todo" if $todo > 0;
        push @parts, sprintf("Duration=%.2fms", $duration);

        print join(", ", @parts) . "\n";
    } else {
        # Failure case
        print $RED_BG . " FAIL " . $RESET . "  " . $RED . "Tests failed." . $RESET . "\n";

        # Build summary line
        my @parts = ("Files=$files", "Tests=$tests");
        push @parts, "Pass=$pass" if $pass > 0;
        push @parts, "Fail=$fail" if $fail > 0;
        push @parts, "FailedFiles=" . scalar(@$failed_files);
        push @parts, "Todo=$todo" if $todo > 0;
        push @parts, sprintf("Duration=%.2fms", $duration);

        print join(", ", @parts) . "\n";

        # Print failed files list
        if (@$failed_files) {
            print "\nFailed files:\n";
            for my $file (@$failed_files) {
                print "  " . $RED . $file . $RESET . "\n";
            }
        }
    }
}

1;

__END__

=head1 HOW IT WORKS

This plugin uses monkey-patching to override App::Prove::_runtests:

1. Sets T2_FORMATTER=Cute environment variable
2. Overrides App::Prove::_runtests method
3. Bypasses TAP::Harness completely
4. Runs each test file directly: perl -I lib t/test.t
5. Collects exit codes and displays a summary

=head1 ALTERNATIVES

If you prefer a more official approach, consider using Test2::Harness:

  # Install yath
  cpanm Test2::Harness

  # Run tests with yath (native Test2::Formatter support)
  yath test t/

Or run tests directly:

  T2_FORMATTER=Cute perl -Ilib t/test.t

=head1 ENVIRONMENT VARIABLES

=over 4

=item * C<T2_FORMATTER_CUTE_DEBUG>

When set to 1, displays the exact command being run for each test.

  T2_FORMATTER_CUTE_DEBUG=1 prove -PCuteFormatter -l t/

=back

=cut
