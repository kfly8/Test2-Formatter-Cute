use Test2::V0;
use Test2::Plugin::UTF8;

use lib 't/lib';
use TestHelper;

my $result = run_test_with_formatter('t/examples/basic.t');
my $stdout = $result->{stdout};

subtest 'file header with checkmark and path' => sub {
    # spec: ✓ ./t/test.t [1.10ms]
    like($stdout, qr/✓ t[\/\\]examples[\/\\]basic\.t/, 'has file header with checkmark');
    like($stdout, qr/✓ .*basic\.t \[\d+\.\d+m?s\]/, 'has time display');
};

subtest 'subtest hierarchy' => sub {
    # spec: インデント2でsubtest 'foo'
    like($stdout, qr/^\s{2}✓ foo/m, 'has subtest foo with indent 2');

    # spec: インデント4でsubtest 'nested foo1'と'nested foo2'
    like($stdout, qr/^\s{4}✓ nested foo1/m, 'has subtest nested foo1 with indent 4');
    like($stdout, qr/^\s{4}✓ nested foo2/m, 'has subtest nested foo2 with indent 4');

    # spec: インデント6で個別テストケース
    like($stdout, qr/^\s{6}✓ case1/m, 'has test case1 with indent 6');
    like($stdout, qr/^\s{6}✓ case2/m, 'has test case2 with indent 6');
};

subtest 'summary display' => sub {
    # spec: All passed shows " PASS  All tests successful."
    like($stdout, qr/^\sPASS\s+All tests successful\.$/m, 'shows PASS All tests successful when all tests pass');

    # spec: Files=1, Tests=7, Duration=0.58ms (no Pass/Fail counts when all pass)
    like($stdout, qr/^Files=1, Tests=7, Duration=\d+(?:\.\d+)?(?:ms|s)/m, 'shows file, test counts and duration');
    unlike($stdout, qr/Pass=/, 'no Pass count when all tests pass');
    unlike($stdout, qr/Fail=/, 'no Fail count when all tests pass');
    like($stdout, qr/StartAt=\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/m, 'shows start time');
    like($stdout, qr/Seed=\d+/m, 'shows seed');
};

subtest 'checkmarks are green (when color enabled)' => sub {
    # 色無効化でテストしているので、このテストはスキップ
    skip_all 'color testing requires separate test with color enabled';
};

done_testing;
