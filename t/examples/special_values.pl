use strict;
use warnings;
use Test2::V0;

subtest 'special value handling' => sub {
    # Test with undef
    my $undef_val = undef;
    is($undef_val, 'expected', 'undef value');

    # Test with newlines
    my $multiline = "foo\nbar";
    is($multiline, 'expected', 'value with newlines');

    # Test with long string
    my $long_str = 'x' x 150;
    is($long_str, 'expected', 'very long string');

    # Test with mixed control characters
    my $mixed = "line1\nline2\ttab\rcarriage";
    is($mixed, 'expected', 'mixed control characters');
};

done_testing;
