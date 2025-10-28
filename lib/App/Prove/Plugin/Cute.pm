package App::Prove::Plugin::Cute;
use strict;
use warnings;

sub load {
    my ($class, $p) = @_;
    my @args = @{ $p->{args} };
    my $app = $p->{app_prove};

    # Set T2_FORMATTER environment variable for test execution
    $ENV{T2_FORMATTER} = 'Cute';

    # Set HARNESS_SUBCLASS to use our custom harness
    $ENV{HARNESS_SUBCLASS} = 'TAP::Harness::Cute';

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

    # Pass verbose setting to formatter
    unless (defined $ENV{T2_FORMATTER_CUTE_VERBOSE}) {
        # App::Prove stores verbose setting in the 'verbose' attribute
        if (defined $app->verbose) {
            $ENV{T2_FORMATTER_CUTE_VERBOSE} = $app->verbose ? 1 : 0;
        }
    }

    return 1;
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
by configuring L<Test2::Formatter::Cute> as the test formatter and
L<TAP::Harness::Cute> as the test harness.

This plugin is designed for making a small number of tests more readable and
visually appealing. It sets the C<HARNESS_SUBCLASS> environment variable to
C<TAP::Harness::Cute>, which runs tests sequentially and formats output using
Test2::Formatter::Cute.

B<Note:> This plugin does not support parallel test execution (C<-j> option).
For large test suites that require parallel execution, use the standard test
harness without this plugin.

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

=head1 OPTIONS

This plugin respects the following prove options:

=over 4

=item --color / --nocolor

Controls whether to use color in the output. When C<--nocolor> is specified,
the plugin sets C<T2_FORMATTER_CUTE_COLOR=0> to disable colors.

=item -v / --verbose

Controls verbosity. In verbose mode, full test output is displayed. In
non-verbose mode, only file headers are shown.

=back

B<Unsupported options:>

=over 4

=item -j / --jobs

Parallel test execution is not supported. Tests are always run sequentially
to ensure proper output formatting and readability.

=back

=head1 ENVIRONMENT

=over 4

=item T2_FORMATTER

Set to C<Cute> by this plugin to enable Test2::Formatter::Cute.

=item HARNESS_SUBCLASS

Set to C<TAP::Harness::Cute> by this plugin to use the custom harness.

=item T2_FORMATTER_CUTE_COLOR

Controls color output (0 = disabled, 1 = enabled). Set automatically based on
the C<--color>/C<--nocolor> options unless already defined.

=back

=head1 SEE ALSO

L<Test2::Formatter::Cute>, L<TAP::Harness::Cute>, L<App::Prove>

