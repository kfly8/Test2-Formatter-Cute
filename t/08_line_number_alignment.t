use strict;
use warnings;
use utf8;
use Test2::V0;

use lib 't/lib';
use TestHelper;

# Test that line numbers are right-aligned in source code context
# This is especially important when line numbers transition from
# single digit (9) to double digit (10) or double (99) to triple (100)

subtest 'line number alignment with single to double digit transition' => sub {
    my $result = run_test_with_formatter('t/examples/multiline.pl', { allow_fail => 1 });
    my $stdout = $result->{stdout};

    # The multiline.pl test shows lines 7-16, transitioning from single to double digits
    # All line numbers should be right-aligned:
    #      7 |         3,
    #      8 |         4,
    #      9 |         5), '12345', 'should pass';
    #     10 |     
    #   ✘ 11 |     is join('',

    # Check that single-digit line numbers have leading spaces
    like($stdout, qr/     7 \|/, 'line 7 has correct padding (5 spaces before single digit)');
    like($stdout, qr/     8 \|/, 'line 8 has correct padding');
    like($stdout, qr/     9 \|/, 'line 9 has correct padding');
    
    # Check that double-digit line numbers align properly
    like($stdout, qr/    10 \|/, 'line 10 has correct padding (4 spaces before double digit)');
    like($stdout, qr/  ✘ 11 \|/, 'line 11 has correct padding with marker');
    like($stdout, qr/  ✘ 12 \|/, 'line 12 has correct padding with marker');
    
    # Verify alignment by checking that all " | " separators line up
    # Extract all lines with line numbers
    my @code_lines = $stdout =~ /^(  [✘ ] *\d+ \|)/mg;
    if (@code_lines) {
        # Check that all lines have the same total width before the |
        my $first_width = length($code_lines[0]);
        for my $line (@code_lines) {
            is(length($line), $first_width, "all line number prefixes have same width: '$line'");
        }
    } else {
        fail('no source code lines found in output');
    }
};

done_testing;
