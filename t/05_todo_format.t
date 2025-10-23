use Test2::V0;

use lib 't/lib';
use TestHelper;

my $result = run_test_with_formatter('t/examples/todo.pl');
my $stdout = $result->{stdout};

subtest 'file and subtest show success despite TODO failures' => sub {
    like($stdout, qr/^✓ t[\/\\]examples[\/\\]todo.pl/m, 'file header shows checkmark');
    like($stdout, qr/^\s{2}✓ todo/m, 'subtest shows checkmark despite TODO failures');
};

subtest 'TODO tests display with # TODO suffix' => sub {
    like($stdout, qr/✘ .* # TODO fail todo/, 'failing TODO test shows # TODO suffix');
    like($stdout, qr/✓ .* # TODO pass todo/, 'passing TODO test shows # TODO suffix');
};

subtest 'TODO tests excluded from counts' => sub {
    like($stdout, qr/^\sPASS\s+All tests successful\.$/m, 'shows PASS All tests successful (TODO failures excluded)');
    like($stdout, qr/^Files=1, Tests=1/m, 'shows Tests=1 (TODO tests excluded)');
    unlike($stdout, qr/Pass=/, 'no Pass count when all pass');
    unlike($stdout, qr/Fail=/, 'no Fail count when all pass');
    like($stdout, qr/Todo=2/m, 'shows Todo=2 for TODO tests');
};

subtest 'exit code shows success' => sub {
    is($result->{exit}, 0, 'exits with 0 even with TODO failures');
};

subtest 'TODO failure details are displayed' => sub {
    like($stdout, qr/\sFAIL\s+t\/examples\/todo.pl > todo > 1 \+ 1 should equal 3/, 'shows FAIL path for TODO failure');
    like($stdout, qr/Received.*eq.*Expected/s, 'shows Received eq Expected for TODO failure');
    like($stdout, qr/Expected:\s*3/, 'shows expected value 3 for TODO failure');
    like($stdout, qr/Received:\s*2/, 'shows received value 2 for TODO failure');
    like($stdout, qr/❯ .*todo.pl:\d+/, 'shows file and line number for TODO failure');
};

done_testing;
