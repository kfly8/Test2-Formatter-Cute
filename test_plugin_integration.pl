#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

# Directly test if the plugin works by loading it and calling _runtests

BEGIN {
    $ENV{T2_FORMATTER} = 'Cute';
    $ENV{T2_FORMATTER_CUTE_COLOR} = 1;
}

require App::Prove;
require App::Prove::Plugin::Cute;

# Create App::Prove instance
my $app = App::Prove->new;
$app->process_args('-l', 't/simple_test1.t');

# Load the plugin
App::Prove::Plugin::Cute->load({
    args => [],
    app_prove => $app,
});

print "Plugin loaded successfully\n";
print "T2_FORMATTER = $ENV{T2_FORMATTER}\n";
print "T2_FORMATTER_CUTE_COLOR = $ENV{T2_FORMATTER_CUTE_COLOR}\n";

# Try to run tests
print "\nAttempting to run tests...\n";
my $result = $app->run;
print "\nTest run completed with result: $result\n";
