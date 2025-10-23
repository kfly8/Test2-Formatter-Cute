package TestHelper;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw(
    run_test_with_formatter
    strip_ansi
    match_file_header
    match_subtest
    match_test_case
    match_summary
    match_failed_test_header
    match_fail_path
);

use Capture::Tiny qw(capture);
use Encode qw(decode_utf8);
use File::Spec ();

# ANSI escape codes を削除する（色情報を除去してテストしやすくする）
sub strip_ansi {
    my ($text) = @_;
    $text =~ s/\e\[[0-9;]*m//g;
    return $text;
}

# T2_FORMATTER=Cute でテストファイルを実行し、出力を取得
sub run_test_with_formatter {
    my ($test_file, $opts) = @_;
    $opts //= {};

    local $ENV{T2_FORMATTER} = 'Cute';
    local $ENV{CURE_COLOR} = 0;  # 色を無効化してテストしやすくする

    my $file = File::Spec->catfile(split m!/!, $test_file);

    my ($stdout, $stderr, $exit) = capture {
        system($^X, '-Ilib', $file);
    };
    $stdout = decode_utf8($stdout);
    $stderr = decode_utf8($stderr);

    if ($opts->{allow_fail}) {
        # テストが失敗することを期待する場合
        return {
            stdout => $stdout,
            stderr => $stderr,
            exit   => $exit >> 8,
        };
    }

    my $err = $exit >> 8;
    if ($err != 0 && !$opts->{expect_fail}) {
        die "Test file '$test_file' exited with code $err. STDERR:\n$stderr\nSTDOUT:\n$stdout\n";
    }

    return {
        stdout => $stdout,
        stderr => $stderr,
        exit   => $err,
    };
}

# ファイルヘッダーのマッチパターン: ✓ ./t/test.t [1.10ms]
sub match_file_header {
    my ($file_path) = @_;
    # ✓ または ✘ + ファイルパス + オプションの時間表示
    return qr/^[✓✘] \Q$file_path\E(?:\s+\[\d+(?:\.\d+)?(?:ms|s)\])?$/m;
}

# subtestのマッチパターン: インデント + ✓ + 名前 + オプションの時間
sub match_subtest {
    my ($name, $opts) = @_;
    $opts //= {};
    my $indent = $opts->{indent} // 2;  # デフォルトはインデント2
    my $spaces = ' ' x $indent;

    return qr/^$spaces[✓✘] \Q$name\E(?:\s+\[\d+(?:\.\d+)?(?:ms|s)\])?$/m;
}

# 個別テストケースのマッチパターン
sub match_test_case {
    my ($name, $opts) = @_;
    $opts //= {};
    my $indent = $opts->{indent} // 4;  # デフォルトはインデント4
    my $spaces = ' ' x $indent;

    return qr/^$spaces[✓✘] \Q$name\E$/m;
}

# サマリー表示のマッチパターン: 8 PASS, 0 FAIL, Files=1, Tests=8 [1.10ms]
sub match_summary {
    return {
        pass_count  => qr/^\d+ PASS$/m,
        fail_count  => qr/^\d+ FAIL$/m,
        files_tests => qr/^Files=\d+, Tests=\d+(?:\s+\[\d+(?:\.\d+)?(?:ms|s)\])?$/m,
    };
}

# 失敗テストのヘッダー: ⎯⎯⎯⎯⎯⎯⎯⎯  FAILED TEST 1 ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
sub match_failed_test_header {
    my ($number) = @_;
    return qr/⎯+\s+FAILED TEST $number\s+⎯+/;
}

# 失敗パスの表示: FAIL ./t/failed-test.t > foo > case2
sub match_fail_path {
    my ($path_parts) = @_;  # ['./t/failed-test.t', 'foo', 'case2']
    my $path = join(' > ', @$path_parts);
    return qr/^FAIL \Q$path\E$/m;
}

1;
