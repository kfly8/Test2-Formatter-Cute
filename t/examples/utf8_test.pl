use strict;
use warnings;
use utf8;
use Test2::V0;

subtest 'UTF-8 character length' => sub {
    # Test that character length (not byte length) is used
    # "あ" is 3 bytes but 1 character
    my $long_utf8 = 'あ' x 60;  # 60 characters (180 bytes)
    is($long_utf8, 'expected', 'UTF-8 string under limit');

    # This should be truncated
    my $very_long_utf8 = 'あ' x 110;  # 110 characters, should be truncated
    is($very_long_utf8, 'expected', 'UTF-8 string over limit');
};

done_testing;
