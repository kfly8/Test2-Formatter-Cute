use Test2::V0;

use lib 't/lib';
use TestHelper;
use Capture::Tiny qw(capture);
use Encode qw(decode_utf8);
use File::Spec ();

# spec:
# - ✓は緑文字、✘は赤文字
# - PASS は緑背景表示
# - FAIL は赤背景表示（1件以上）、灰色文字（0件）
# - 時間表示は灰色文字
# - 失敗時のFAILは赤背景文字
# - 失敗時の > は灰色文字

# カラー有効でテスト実行
sub run_test_with_color {
    my ($test_file) = @_;
    
    local $ENV{T2_FORMATTER} = 'Cute';
    local $ENV{CURE_COLOR} = 1;  # カラーを有効化
    
    my $file = File::Spec->catfile(split m!/!, $test_file);
    
    my ($stdout, $stderr, $exit) = capture {
        system($^X, '-Ilib', $file);
    };
    $stdout = decode_utf8($stdout);
    $stderr = decode_utf8($stderr);
    
    return {
        stdout => $stdout,
        stderr => $stderr,
        exit   => $exit >> 8,
    };
}

# カラー無効でテスト実行
sub run_test_without_color {
    my ($test_file) = @_;
    
    local $ENV{T2_FORMATTER} = 'Cute';
    local $ENV{CURE_COLOR} = 0;  # カラーを無効化
    
    my $file = File::Spec->catfile(split m!/!, $test_file);
    
    my ($stdout, $stderr, $exit) = capture {
        system($^X, '-Ilib', $file);
    };
    $stdout = decode_utf8($stdout);
    $stderr = decode_utf8($stderr);
    
    return {
        stdout => $stdout,
        stderr => $stderr,
        exit   => $exit >> 8,
    };
}

subtest 'color enabled tests' => sub {
    my $result = run_test_with_color('t/examples/basic.t');
    my $stdout = $result->{stdout};
    
    # ANSIエスケープコードが含まれていることを確認
    like($stdout, qr/\e\[/, 'output contains ANSI escape codes when color enabled');
    
    # 緑色のチェックマーク（成功）
    like($stdout, qr/\e\[32m✓\e\[0m/, 'checkmarks are green');
    
    # 緑背景のPASS
    like($stdout, qr/\e\[42m\e\[30m\d+ PASS\e\[0m/, 'PASS count has green background');
    
    # 灰色のFAIL（0件の場合）
    like($stdout, qr/\e\[90m0 FAIL\e\[0m/, 'FAIL count is gray when zero');
    
    # 灰色の時間表示
    like($stdout, qr/\e\[90m\[\d+\.\d+ms\]\e\[0m/, 'time display is gray');
};

subtest 'color disabled tests' => sub {
    my $result = run_test_without_color('t/examples/basic.t');
    my $stdout = $result->{stdout};
    
    # ANSIエスケープコードが含まれていないことを確認
    unlike($stdout, qr/\e\[/, 'output contains no ANSI escape codes when color disabled');
    
    # strip_ansiした結果と構造的に同じであることを確認（時間の差は無視）
    my $result_with_color = run_test_with_color('t/examples/basic.t');
    my $stripped = strip_ansi($result_with_color->{stdout});
    
    # 時間部分を正規化して比較
    my $normalized_stdout = $stdout;
    my $normalized_stripped = $stripped;
    
    # Duration と時間表示を統一
    $normalized_stdout =~ s/Duration=\d+\.\d+ms/Duration=X.XXms/g;
    $normalized_stripped =~ s/Duration=\d+\.\d+ms/Duration=X.XXms/g;
    $normalized_stdout =~ s/\[\d+\.\d+ms\]/[X.XXms]/g;
    $normalized_stripped =~ s/\[\d+\.\d+ms\]/[X.XXms]/g;
    $normalized_stdout =~ s/StartAt=\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/StartAt=XXXX-XX-XXTXX:XX:XX/g;
    $normalized_stripped =~ s/StartAt=\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/StartAt=XXXX-XX-XXTXX:XX:XX/g;
    
    is($normalized_stdout, $normalized_stripped, 'color disabled output matches stripped color output (normalized)');
};

subtest 'failed test colors' => sub {
    my $result = run_test_with_color('t/examples/failed.t');
    my $stdout = $result->{stdout};
    
    # 赤いXマーク（失敗）
    like($stdout, qr/\e\[31m✘\e\[0m/, 'X marks are red for failures');
    
    # 赤背景のFAIL
    like($stdout, qr/\e\[41m\e\[97mFAIL\e\[0m/, 'FAIL label has red background');
    
    # 赤背景のFAIL count（1件以上の場合）
    like($stdout, qr/\e\[41m\e\[97m\d+ FAIL\e\[0m/, 'FAIL count has red background when > 0');
    
    # 灰色の区切り文字 >
    like($stdout, qr/\e\[90m>\e\[0m/, 'path separators are gray');
};

subtest 'environment variable handling' => sub {
    # CURE_COLOR環境変数のテスト
    
    # CURE_COLOR=1の場合
    my $result1 = run_test_with_color('t/examples/basic.t');
    like($result1->{stdout}, qr/\e\[/, 'CURE_COLOR=1 enables colors');
    
    # CURE_COLOR=0の場合
    my $result2 = run_test_without_color('t/examples/basic.t');
    unlike($result2->{stdout}, qr/\e\[/, 'CURE_COLOR=0 disables colors');
};

done_testing;
