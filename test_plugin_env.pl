#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

# Test plugin with HARNESS_SUBCLASS
BEGIN {
    $ENV{T2_FORMATTER} = 'Cute';
    $ENV{HARNESS_SUBCLASS} = 'TAP::Harness::Cute';
    $ENV{T2_FORMATTER_CUTE_COLOR} = 1;
}

require App::Prove;

# Create App::Prove instance
my $app = App::Prove->new;
$app->process_args('-l', 't/simple_test1.t', 't/simple_test2.t');

print "Running tests with HARNESS_SUBCLASS=TAP::Harness::Cute...\n\n";

# Load the plugin (should set environment variables)
require App::Prove::Plugin::Cute;
App::Prove::Plugin::Cute->load({
    args => [],
    app_prove => $app,
});

print "Environment after plugin load:\n";
print "  T2_FORMATTER = $ENV{T2_FORMATTER}\n";
print "  HARNESS_SUBCLASS = $ENV{HARNESS_SUBCLASS}\n";
print "  T2_FORMATTER_CUTE_COLOR = $ENV{T2_FORMATTER_CUTE_COLOR}\n\n";

# Run tests
my $result = $app->run;
print "\nTest run completed with result: $result\n";
