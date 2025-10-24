use Test2::V0;

use lib 't/lib';
use TestHelper;

my $result = run_test_with_formatter('t/examples/failed.pl', { allow_fail => 1 });
my $stdout = $result->{stdout};

subtest 'file header shows failure' => sub {
    # spec: ✘ ./t/failed-test.t [1.10ms]
    like($stdout, qr/✘ t[\/\\]examples[\/\\]failed.pl/, 'file header shows X mark for failure');
};

subtest 'subtest and test case status' => sub {
    # spec: ✘ foo (subtest with failures)
    like($stdout, qr/^\s{2}✘ foo/m, 'subtest foo shows X mark');

    # spec: ✓ case1 (passing test)
    like($stdout, qr/^\s{4}✓ case1/m, 'passing test case1 shows checkmark');

    # spec: ✘ case2, ✘ case3 (failing tests)
    like($stdout, qr/^\s{4}✘ case2/m, 'failing test case2 shows X mark');
    like($stdout, qr/^\s{4}✘ case3/m, 'failing test case3 shows X mark');
};

subtest 'failure details - no separator lines' => sub {
    # Separators are removed to keep output simple
    # FAIL lines are sufficient to identify each failure
    pass('no separator lines needed');
};

subtest 'failure details - test path' => sub {
    # spec: FAIL  t/failed-test.t > foo > case2 (no ./ prefix, extra space after FAIL)
    like($stdout, qr/\sFAIL\s+t\/examples\/failed.pl > foo☺️ > case2/, 'shows failure path for case2');
    like($stdout, qr/\sFAIL\s+t\/examples\/failed.pl > foo☺️ > case3/, 'shows failure path for case3');
};

subtest 'failure details - comparison format' => sub {
    # spec: Received eq Expected
    #
    #       Expected: 1
    #       Received: 0
    like($stdout, qr/Received.*eq.*Expected/s, 'has Received eq Expected header');
    like($stdout, qr/Expected:\s*1/, 'shows expected value 1');
    like($stdout, qr/Received:\s*0/, 'shows received value 0 for case2');
    like($stdout, qr/Received:\s*-1/, 'shows received value -1 for case3');
};

subtest 'failure details - source code context' => sub {
    # spec: ❯ t/failed-test.t:7
    #       5 | subtest 'foo' => sub {
    #       6 |   is 1+1, 2, 'case1';
    #       7 |   is 1-1, 1, 'case2'; (該当行を太字にする)
    like($stdout, qr/❯ .*failed.pl:\d+/, 'shows file and line number');
    like($stdout, qr/is 1-1, 1, 'case2'/, 'shows source code for case2');
    # case3 is split across multiple lines, so check both parts
    like($stdout, qr/is 0-1,/, 'shows source code for case3 (line 1)');
    like($stdout, qr/'case3'/, 'shows source code for case3 (line 2)');
};

subtest 'summary shows failures' => sub {
    # spec: Shows " FAIL  Tests failed." and includes Pass/Fail counts in summary
    like($stdout, qr/^\sFAIL\s+Tests failed\.$/m, 'shows FAIL Tests failed when tests fail');
    like($stdout, qr/^Files=1, Tests=3, Pass=1, Fail=2/m, 'shows Pass and Fail counts in summary');
};

subtest 'exit code indicates failure' => sub {
    isnt($result->{exit}, 0, 'exits with non-zero code on failure');
};

done_testing;
