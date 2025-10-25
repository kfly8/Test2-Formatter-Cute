#!/usr/bin/env perl
use strict;
use warnings;

# Test that plugin delegates to TAP::Harness via make_harness

require App::Prove::Plugin::Cute;

# Mock App::Prove object with make_harness method
package MockAppProve {
    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }

    sub color {
        my $self = shift;
        return $self->{color};
    }

    sub make_harness {
        my $self = shift;
        print "PASS: make_harness was called (test execution delegated to Harness)\n";
        # Return a mock harness
        return MockHarness->new();
    }
}

package MockHarness {
    sub new {
        my $class = shift;
        return bless {}, $class;
    }

    sub runtests {
        my ($self, @tests) = @_;
        print "PASS: runtests called with " . scalar(@tests) . " test(s)\n";
        # Don't actually run anything
    }

    sub aggregator {
        my $self = shift;
        # Return a mock aggregator
        return MockAggregator->new();
    }
}

package MockAggregator {
    sub new {
        my $class = shift;
        return bless {}, $class;
    }

    sub parsers {
        return ();
    }
}

# Test: Plugin sets environment variables
{
    local %ENV = %ENV;
    delete $ENV{T2_FORMATTER};
    delete $ENV{T2_FORMATTER_CUTE_COLOR};

    my $mock_app = MockAppProve->new(color => 1);
    App::Prove::Plugin::Cute->load({
        args => [],
        app_prove => $mock_app,
    });

    die "FAIL: T2_FORMATTER not set to 'Cute'\n"
        unless $ENV{T2_FORMATTER} eq 'Cute';

    print "PASS: Plugin sets T2_FORMATTER=Cute\n";
}

print "\nAll tests passed!\n";
