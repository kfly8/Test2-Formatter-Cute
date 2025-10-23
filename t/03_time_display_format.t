use Test2::V0;

use lib 't/lib';
use TestHelper;

# spec: [1.10ms] 形式で時間を表示
# - テストファイル、subtest、結果に表示
# - 灰色文字表示

my $result = run_test_with_formatter('t/examples/basic.pl');
my $stdout = $result->{stdout};

subtest 'file level time display' => sub {
    # ファイルレベルの時間
    like($stdout, qr/basic.pl \[\d+\.\d+m?s\]/, 'file has time display');
};

subtest 'subtest level time display' => sub {
    # subtestレベルの時間
    like($stdout, qr/✓ foo \[\d+\.\d+m?s\]/, 'subtest has time display');
    like($stdout, qr/✓ nested foo1 \[\d+\.\d+m?s\]/, 'nested subtest has time display');
};

subtest 'summary time display' => sub {
    # 結果の時間
    like($stdout, qr/Duration=\d+\.\d+m?s/, 'summary has time display');
};

done_testing;
