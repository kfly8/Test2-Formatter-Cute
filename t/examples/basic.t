use Test2::V0;

subtest 'foo' => sub {
    subtest 'nested foo1' => sub {
        ok 1, 'case1';
        ok 1, 'case2';
    };

    subtest 'nested foo2' => sub {
        ok 1, 'case1';
        ok 1, 'case2';
    };
};

done_testing;
