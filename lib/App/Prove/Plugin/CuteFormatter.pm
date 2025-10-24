package App::Prove::Plugin::CuteFormatter;
use strict;
use warnings;

=head1 NAME

App::Prove::Plugin::CuteFormatter - Prove plugin to enable Test2::Formatter::Cute

=head1 SYNOPSIS

  # Use with prove
  prove -PCuteFormatter -l t/

  # Run multiple tests
  prove -PCuteFormatter -l t/*.t

  # Enable debug mode
  T2_FORMATTER_CUTE_DEBUG=1 prove -PCuteFormatter -l t/

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

    print "Loading CuteFormatter plugin...\n";

    # Set T2_FORMATTER environment variable for test execution
    $ENV{T2_FORMATTER} = 'Cute';
    print "Set T2_FORMATTER=Cute for test execution\n";

    # Monkey patch App::Prove::_runtests to bypass TAP::Harness
    # and run tests directly with Test2::Formatter::Cute
    {
        no warnings 'redefine';
        my $original_runtests = \&App::Prove::_runtests;

        *App::Prove::_runtests = sub {
            my ( $self, $args, @tests ) = @_;

            print "Running tests with Test2::Formatter::Cute (bypassing TAP::Harness)...\n\n";

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
            my $total_tests = scalar @tests;
            my $passed_tests = 0;
            my $failed_tests = 0;

            # Run each test directly
            for my $test (@tests) {
                my @cmd = ($^X, @switches, @lib_args, $test);

                # Show command in debug mode
                if ($ENV{T2_FORMATTER_CUTE_DEBUG}) {
                    print "# Running: @cmd\n\n";
                }

                my $exit_code = system(@cmd);

                if ($exit_code == 0) {
                    $passed_tests++;
                } else {
                    $failed_tests++;
                }

                print "\n";
            }

            # Print summary
            print "=" x 70, "\n";
            print "Test Summary:\n";
            print "  Total: $total_tests\n";
            print "  Passed: $passed_tests\n";
            print "  Failed: $failed_tests\n";
            print "=" x 70, "\n";

            return $failed_tests == 0;
        };
    }

    print "Monkey-patched App::Prove::_runtests\n";

    return 1;
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
