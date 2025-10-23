use Test2::V0;

subtest 'todo' => sub {
    ok 1, 'pass case';
    todo 'fail todo' => sub {
        is(1 + 1, 3, '1 + 1 should equal 3 (but it does not)');
    };
    todo 'pass todo' => sub {
        is(2 * 2, 4, '2 * 2 should equal 4 (and it does)');
    };
};

done_testing;
