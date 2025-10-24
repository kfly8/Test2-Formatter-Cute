use Test2::V0;

subtest 'foo☺️' => sub {
    is 1+1, 2, 'case1';
    is 1-1, 1, 'case2';
    is 0-1, 1, 'case3';
};

done_testing;
