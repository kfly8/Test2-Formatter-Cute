package App::Prove::Plugin::CuteFormatter;
use strict;
use warnings;

=head1 NAME

App::Prove::Plugin::CuteFormatter - Prove plugin to enable Test2::Formatter::Cute

=head1 SYNOPSIS

  prove -PCuteFormatter t/

=head1 DESCRIPTION

This plugin attempts to bridge the gap between prove's TAP-based architecture
and Test2::Formatter::Cute's event-based formatting.

WARNING: This is experimental and may not work as expected due to fundamental
architectural differences between TAP::Harness and Test2::Formatter.

=cut

sub load {
    my ($class, $p) = @_;
    my @args = @{ $p->{args} };
    my $app = $p->{app_prove};

    print "Loading CuteFormatter plugin...\n";

    # The key insight: We need to set T2_FORMATTER environment variable
    # so that the TEST ITSELF uses Test2::Formatter::Cute when it runs
    $ENV{T2_FORMATTER} = 'Cute';
    print "Set T2_FORMATTER=Cute for test execution\n";

    # We also need a TAP::Formatter that just passes through
    # or we can leave it as default and let prove show TAP parsing results
    # $app->formatter('TAP::Formatter::Console');

    # Disable prove's verbose mode to avoid double output
    # $app->quiet(1);

    return 1;
}

1;

__END__

=head1 ARCHITECTURE NOTES

The fundamental problem:

1. prove runs tests and captures STDOUT (TAP format: "ok 1", "1..5", etc.)
2. TAP::Parser parses this TAP string into Result objects
3. TAP::Formatter::Console formats the Results for display

But Test2::Formatter::Cute works differently:

1. Tests emit Test2::Event objects directly
2. Test2::Formatter::Cute receives these events
3. It formats them into cute emoji output

When using prove:
- Tests using Test2 will still emit events to Test2::Formatter (set via T2_FORMATTER)
- But prove also expects TAP output for its own parsing
- These two paths are independent

=head1 RECOMMENDATION

For proper Test2::Formatter::Cute support, use 'yath' instead of 'prove':

  yath test t/

Or set T2_FORMATTER environment variable:

  T2_FORMATTER=Cute perl t/test.t

=cut
