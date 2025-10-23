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
    local $ENV{T2_FORMATTER_CUTE_COLOR} = 1;  # カラーを有効化

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
    local $ENV{T2_FORMATTER_CUTE_COLOR} = 0;  # カラーを無効化

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
    my $result = run_test_with_color('t/examples/basic.pl');
    my $stdout = $result->{stdout};
    
    # ANSIエスケープコードが含まれていることを確認
    like($stdout, qr/\e\[/, 'output contains ANSI escape codes when color enabled');

    # 緑色のチェックマーク（成功）
    like($stdout, qr/\e\[32m✓\e\[0m/, 'checkmarks are green');

    # 緑背景の " PASS " と緑文字の "All tests successful."
    like($stdout, qr/\e\[42m\e\[1m\e\[38;5;16m PASS \e\[0m/, 'PASS label has green background');
    like($stdout, qr/\e\[32mAll tests successful\.\e\[0m/, 'success message is green text');

    # 灰色の時間表示
    like($stdout, qr/\e\[90m\[\d+\.\d+ms\]\e\[0m/, 'time display is gray');
};

subtest 'color disabled tests' => sub {
    my $result = run_test_without_color('t/examples/basic.pl');
    my $stdout = $result->{stdout};
    
    # ANSIエスケープコードが含まれていないことを確認
    unlike($stdout, qr/\e\[/, 'output contains no ANSI escape codes when color disabled');
    
    # strip_ansiした結果と構造的に同じであることを確認（時間の差は無視）
    my $result_with_color = run_test_with_color('t/examples/basic.pl');
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
    my $result = run_test_with_color('t/examples/failed.pl');
    my $stdout = $result->{stdout};

    # 赤いXマーク（失敗）
    like($stdout, qr/\e\[31m✘\e\[0m/, 'X marks are red for failures');

    # 赤背景の " FAIL " ラベル（失敗詳細とサマリー）
    like($stdout, qr/\e\[41m\e\[1m\e\[38;5;16m FAIL \e\[0m/, 'FAIL label has red background');

    # 赤文字の "Tests failed." メッセージ
    like($stdout, qr/\e\[31mTests failed\.\e\[0m/, 'failure message is red text');

    # 赤文字のReceivedラベル
    like($stdout, qr/\e\[31mReceived:\e\[0m/, 'Received label is red');

    # 緑文字のExpectedラベル
    like($stdout, qr/\e\[32mExpected:\e\[0m/, 'Expected label is green');

    # 灰色の区切り文字 >
    like($stdout, qr/\e\[90m>\e\[0m/, 'path separators are gray');
};

subtest 'environment variable handling' => sub {
    # T2_FORMATTER_CUTE_COLOR環境変数のテスト

    # T2_FORMATTER_CUTE_COLOR=1の場合
    my $result1 = run_test_with_color('t/examples/basic.pl');
    like($result1->{stdout}, qr/\e\[/, 'T2_FORMATTER_CUTE_COLOR=1 enables colors');

    # T2_FORMATTER_CUTE_COLOR=0の場合
    my $result2 = run_test_without_color('t/examples/basic.pl');
    unlike($result2->{stdout}, qr/\e\[/, 'T2_FORMATTER_CUTE_COLOR=0 disables colors');
};

done_testing;
