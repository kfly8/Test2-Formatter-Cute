use strict;
use warnings;
use Test2::V0;
use File::Temp qw(tempfile);
use File::Spec;

# Run test file with Cute formatter and capture output
my $test_file = File::Spec->catfile('t', 'examples', 'special_values.pl');
my $perl = $^X;

# Set environment to disable color for easier testing
local $ENV{T2_FORMATTER_CUTE_COLOR} = 0;

my $cmd = qq{"$perl" -Ilib -MTest2::Formatter::Cute "$test_file" 2>&1};
my $stdout = `$cmd`;

subtest 'undef value is displayed as <UNDEF>' => sub {
    like($stdout, qr/Received: <UNDEF>/, 'undef is shown as <UNDEF>');
};

subtest 'newlines are escaped' => sub {
    like($stdout, qr/Received: foo\\nbar/, 'newlines are escaped as \\n');
};

subtest 'long strings are truncated' => sub {
    # Should have '...' at the end and be about 100 chars
    like($stdout, qr/Received: x+\.\.\./, 'long string is truncated with ...');
    # Make sure it's not showing all 150 x's
    unlike($stdout, qr/Received: x{140,}/, 'long string is not shown in full');
};

subtest 'mixed control characters are escaped' => sub {
    like($stdout, qr/line1\\nline2\\ttab\\rcarriage/, 'all control chars are escaped');
};

done_testing;
