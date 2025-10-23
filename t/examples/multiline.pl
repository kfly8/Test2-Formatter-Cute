use Test2::V0;

subtest 'multiline test' => sub {
    is join('',
        1,
        2,
        3,
        4,
        5), '12345', 'should pass';
    
    is join('',
        1,
        2,
        3,
        4,
        5), 'wrong', 'should fail - 5 lines';
};

done_testing;
