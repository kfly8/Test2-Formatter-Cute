#!/usr/bin/env perl
use strict;
use warnings;

# Test statistics extraction
my $output = <<'END';
[32m✓[0m t/simple_test1.t
  [32m✓[0m test 1
  [32m✓[0m test 2
  [32m✓[0m test 3

[42m[1m[38;5;16m PASS [0m [32mAll tests successful.[0m
Files=1, Tests=3
END

# Remove ANSI codes (ESC is \x1b or \033 or \e)
my $clean_output = $output;
$clean_output =~ s/\x1b\[[0-9;]*m//g;

print "=== Original output ===\n$output\n";
print "=== Clean output ===\n$clean_output\n";

my %stats = (
    tests => 0,
    pass => 0,
    fail => 0,
);

my @lines = split /\n/, $clean_output;
for my $line (@lines) {
    print "Checking line: [$line]\n";
    if ($line =~ /Files=\d+/) {
        print "  Found Files line!\n";
        if ($line =~ /Tests=(\d+)/) {
            $stats{tests} += $1;
            print "  Extracted Tests=$1\n";
        }
    }
}

print "\n=== Final stats ===\n";
print "Tests: $stats{tests}\n";
