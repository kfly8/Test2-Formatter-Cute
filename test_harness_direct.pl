#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

require TAP::Harness::Cute;

# Set environment for Cute formatter
$ENV{T2_FORMATTER} = 'Cute';
$ENV{T2_FORMATTER_CUTE_COLOR} = 1;

# Create harness
my $harness = TAP::Harness::Cute->new({
    verbosity => 0,
    jobs => 1,
    lib => ['lib'],
});

print "Running test with TAP::Harness::Cute...\n\n";

# Run tests
my $stats = $harness->runtests('t/simple_test1.t', 't/simple_test2.t');

print "\n=== Statistics ===\n";
print "Files: $stats->{files}\n";
print "Tests: $stats->{tests}\n";
print "Pass: $stats->{pass}\n";
print "Fail: $stats->{fail}\n";
print "Failed files: " . join(", ", @{$stats->{failed_files}}) . "\n";
