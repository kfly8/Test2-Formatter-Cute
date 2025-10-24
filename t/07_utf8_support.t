use strict;
use warnings;
use utf8;
use Test2::V0;

use lib 't/lib';
use TestHelper;

# Test UTF-8 characters in source code context display
# This test verifies that when displaying source code context for failures,
# UTF-8 characters (like emoji) are displayed correctly and not garbled.

subtest 'UTF-8 source code display' => sub {
    my $test_file = 't/examples/failed.pl';

    skip_all "Test file $test_file not found" unless -f $test_file;

    # Read the test file to verify it contains UTF-8
    open my $fh, '<:utf8', $test_file or die "Cannot open $test_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Check that the source file actually contains UTF-8 emoji
    like($content, qr/☺️/, 'Test file contains UTF-8 emoji');

    # Run the test with Cute formatter and capture output
    my $result = run_test_with_formatter($test_file, { allow_fail => 1 });
    my $output = $result->{stdout};

    # Verify UTF-8 characters are displayed correctly in output
    like($output, qr/foo☺️/, 'UTF-8 emoji displayed correctly in source context');
    unlike($output, qr/fooâº/, 'No garbled UTF-8 characters (â)');
    unlike($output, qr/fooï¸/, 'No garbled UTF-8 characters (ï¸)');
};

done_testing;
