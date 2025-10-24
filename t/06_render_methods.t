use Test2::V0;
use Test2::Plugin::UTF8;
use Test2::Formatter::Cute;
use File::Temp qw(tempfile);

# Create a formatter instance for testing
sub create_formatter {
    my %opts = @_;
    my $formatter = Test2::Formatter::Cute->new(
        color => $opts{color} // 0,  # Default: no color for easier testing
    );
    return $formatter;
}

subtest '_render_test_line' => sub {
    subtest 'basic passing test without color' => sub {
        my $f = create_formatter();
        my $result = $f->_render_test_line(
            pass => 1,
            name => 'test name',
            indent_level => 2,
        );

        is($result, "    ✓ test name\n", 'renders passing test with correct indent');
    };

    subtest 'basic failing test without color' => sub {
        my $f = create_formatter();
        my $result = $f->_render_test_line(
            pass => 0,
            name => 'failed test',
            indent_level => 1,
        );

        is($result, "  ✘ failed test\n", 'renders failing test with X mark');
    };

    subtest 'test with time display' => sub {
        my $f = create_formatter();
        my $result = $f->_render_test_line(
            pass => 1,
            name => 'subtest',
            indent_level => 1,
            time_str => ' [12.34ms]',
        );

        is($result, "  ✓ subtest [12.34ms]\n", 'includes time string');
    };

    subtest 'TODO test' => sub {
        my $f = create_formatter();
        my $result = $f->_render_test_line(
            pass => 0,
            name => 'todo test',
            indent_level => 2,
            is_todo => 1,
            todo_reason => 'not implemented yet',
        );

        is($result, "    ✘ todo test # TODO not implemented yet\n", 'includes TODO suffix');
    };

    subtest 'TODO test with empty reason' => sub {
        my $f = create_formatter();
        my $result = $f->_render_test_line(
            pass => 1,
            name => 'passing todo',
            indent_level => 1,
            is_todo => 1,
            todo_reason => '',
        );

        is($result, "  ✓ passing todo # TODO \n", 'includes TODO with empty reason');
    };

    subtest 'zero indent level' => sub {
        my $f = create_formatter();
        my $result = $f->_render_test_line(
            pass => 1,
            name => 'top level',
            indent_level => 0,
        );

        is($result, "✓ top level\n", 'no indent for level 0');
    };

    subtest 'with color enabled' => sub {
        my $f = create_formatter(color => 1);
        my $result = $f->_render_test_line(
            pass => 1,
            name => 'colored',
            indent_level => 1,
        );

        like($result, qr/\e\[32m✓\e\[0m/, 'checkmark is green');
        like($result, qr/colored/, 'contains test name');
    };

    subtest 'TODO with color shows gray' => sub {
        my $f = create_formatter(color => 1);
        my $result = $f->_render_test_line(
            pass => 0,
            name => 'todo fail',
            indent_level => 1,
            is_todo => 1,
            todo_reason => 'later',
        );

        like($result, qr/\e\[90m✘\e\[0m/, 'TODO failure shows gray');
    };
};

subtest '_render_file_header' => sub {
    subtest 'passing file without color' => sub {
        my $f = create_formatter();
        my $result = $f->_render_file_header(
            file => 't/test.t',
            total_time_str => '',
            fail_count => 0,
        );

        is($result, "✓ t/test.t\n", 'renders passing file header');
    };

    subtest 'failing file without color' => sub {
        my $f = create_formatter();
        my $result = $f->_render_file_header(
            file => 't/failed.t',
            total_time_str => '',
            fail_count => 3,
        );

        is($result, "✘ t/failed.t\n", 'renders failing file header with X mark');
    };

    subtest 'with time display' => sub {
        my $f = create_formatter();
        my $result = $f->_render_file_header(
            file => 't/test.t',
            total_time_str => ' [123.45ms]',
            fail_count => 0,
        );

        is($result, "✓ t/test.t [123.45ms]\n", 'includes time string');
    };

    subtest 'with color enabled - passing' => sub {
        my $f = create_formatter(color => 1);
        my $result = $f->_render_file_header(
            file => 't/pass.t',
            total_time_str => '',
            fail_count => 0,
        );

        like($result, qr/\e\[32m✓\e\[0m/, 'checkmark is green for passing');
    };

    subtest 'with color enabled - failing' => sub {
        my $f = create_formatter(color => 1);
        my $result = $f->_render_file_header(
            file => 't/fail.t',
            total_time_str => '',
            fail_count => 1,
        );

        like($result, qr/\e\[31m✘\e\[0m/, 'X mark is red for failing');
    };
};

subtest '_render_failure_header' => sub {
    subtest 'basic failure header without color' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_header(
            file_path => 't/test.t',
            path_parts => ['subtest', 'test case'],
        );

        is($result, " FAIL  t/test.t > subtest > test case\n", 'renders failure path');
    };

    subtest 'single level path' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_header(
            file_path => 't/simple.t',
            path_parts => ['only test'],
        );

        is($result, " FAIL  t/simple.t > only test\n", 'renders single level path');
    };

    subtest 'deeply nested path' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_header(
            file_path => 't/nested.t',
            path_parts => ['level1', 'level2', 'level3', 'test'],
        );

        is($result, " FAIL  t/nested.t > level1 > level2 > level3 > test\n",
            'renders deeply nested path');
    };

    subtest 'with color enabled' => sub {
        my $f = create_formatter(color => 1);
        my $result = $f->_render_failure_header(
            file_path => 't/test.t',
            path_parts => ['sub', 'test'],
        );

        like($result, qr/\e\[41m\e\[1m\e\[38;5;16m FAIL \e\[0m/, 'FAIL label has red background');
        like($result, qr/\e\[90m>\e\[0m/, 'separator is gray');
    };
};

subtest '_render_failure_comparison' => sub {
    subtest 'basic comparison without color' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_comparison(
            received => '0',
            op => 'eq',
            expected => '1',
        );

        like($result, qr/Received eq Expected/, 'shows operator line');
        like($result, qr/Expected: 1/, 'shows expected value');
        like($result, qr/Received: 0/, 'shows received value');
    };

    subtest 'with color enabled' => sub {
        my $f = create_formatter(color => 1);
        my $result = $f->_render_failure_comparison(
            received => 'bar',
            op => 'eq',
            expected => 'foo',
        );

        like($result, qr/\e\[31mReceived\e\[0m/, 'Received label is red');
        like($result, qr/\e\[32mExpected\e\[0m/, 'Expected label is green');
        like($result, qr/\e\[1meq\e\[0m/, 'operator is bold');
        like($result, qr/\e\[32mExpected:\e\[0m foo/, 'Expected: label is green, value is normal');
        like($result, qr/\e\[31mReceived:\e\[0m bar/, 'Received: label is red, value is normal');
    };

    subtest 'empty values' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_comparison(
            received => '',
            op => '',
            expected => '',
        );

        like($result, qr/Received  Expected/, 'handles empty operator');
        like($result, qr/Expected:\s*$/m, 'handles empty expected');
        like($result, qr/Received:\s*$/m, 'handles empty received');
    };

    subtest 'different operators' => sub {
        my $f = create_formatter();

        for my $op (qw(== != eq ne < > <= >=)) {
            my $result = $f->_render_failure_comparison(
                received => '1',
                op => $op,
                expected => '2',
            );
            like($result, qr/Received \Q$op\E Expected/, "handles $op operator");
        }
    };
};

subtest '_render_failure_source' => sub {
    # Create a temporary test file
    my ($fh, $temp_file) = tempfile(UNLINK => 1, SUFFIX => '.t');
    print $fh <<'CODE';
use Test2::V0;

subtest 'example' => sub {
    ok 1, 'pass';
    is 1+1, 3, 'fail';
    ok 1, 'another';
};

done_testing;
CODE
    close $fh;

    subtest 'basic source display without color' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_source(
            file => $temp_file,
            line => 5,
        );

        like($result, qr/❯ \Q$temp_file\E:5/, 'shows file and line number');
        like($result, qr/1 \| use Test2::V0;/, 'shows line 1');
        like($result, qr/2 \|/, 'shows line 2 (empty)');
        like($result, qr/3 \| subtest/, 'shows line 3');
        like($result, qr/4 \|.*ok 1/, 'shows line 4');
        like($result, qr/✘ 5 \|.*is 1\+1, 3/, 'shows line 5 with X mark');
    };

    subtest 'line with semicolon stops' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_source(
            file => $temp_file,
            line => 5,
        );

        # Line 5 has semicolon, so should not show line 6+
        unlike($result, qr/6 \|/, 'does not show line 6');
    };

    subtest 'with color enabled' => sub {
        my $f = create_formatter(color => 1);
        my $result = $f->_render_failure_source(
            file => $temp_file,
            line => 5,
        );

        like($result, qr/\e\[90m❯\e\[0m/, 'arrow is gray');
        like($result, qr/\e\[31m✘\e\[0m/, 'X mark is red');
    };

    subtest 'file does not exist' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_source(
            file => '/nonexistent/file.t',
            line => 10,
        );

        is($result, '', 'returns empty string for nonexistent file');
    };

    subtest 'no file provided' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_source(
            file => '',
            line => 10,
        );

        is($result, '', 'returns empty string when no file');
    };

    subtest 'no line provided' => sub {
        my $f = create_formatter();
        my $result = $f->_render_failure_source(
            file => $temp_file,
            line => 0,
        );

        is($result, '', 'returns empty string when no line');
    };
};

subtest '_render_summary' => sub {
    subtest 'all tests passed without color' => sub {
        my $f = create_formatter();
        my $result = $f->_render_summary(
            fail_count => 0,
            pass_count => 5,
            total_count => 5,
            todo_count => 0,
            start_time => 1000.0,
            start_at => '2025-09-08T17:26:43',
            seed => 12345,
            end_time => 1001.234,
        );

        like($result, qr/ PASS  All tests successful\./, 'shows PASS message');
        like($result, qr/Files=1, Tests=5/, 'shows file and test count');
        unlike($result, qr/Pass=/, 'no Pass count when all pass');
        unlike($result, qr/Fail=/, 'no Fail count when all pass');
        like($result, qr/Duration=1\.23s/, 'shows duration in seconds when over 1s');
        like($result, qr/StartAt=2025-09-08T17:26:43/, 'shows start time');
        like($result, qr/Seed=12345/, 'shows seed');
    };

    subtest 'some tests failed without color' => sub {
        my $f = create_formatter();
        my $result = $f->_render_summary(
            fail_count => 2,
            pass_count => 3,
            total_count => 5,
            todo_count => 0,
            start_time => 1000.0,
            start_at => '2025-09-08T17:26:43',
            seed => 12345,
            end_time => 1001.5,
        );

        like($result, qr/ FAIL  Tests failed\./, 'shows FAIL message');
        like($result, qr/Files=1, Tests=5/, 'shows file and test count');
        like($result, qr/Pass=3, Fail=2/, 'shows Pass and Fail counts');
    };

    subtest 'with TODO tests' => sub {
        my $f = create_formatter();
        my $result = $f->_render_summary(
            fail_count => 0,
            pass_count => 3,
            total_count => 3,
            todo_count => 2,
            start_time => 1000.0,
            start_at => '2025-09-08T17:26:43',
            seed => 12345,
            end_time => 1001.0,
        );

        like($result, qr/Todo=2/, 'shows TODO count');
        like($result, qr/Tests=3/, 'TODO tests not included in total');
    };

    subtest 'duration over 1 second' => sub {
        my $f = create_formatter();
        my $result = $f->_render_summary(
            fail_count => 0,
            pass_count => 10,
            total_count => 10,
            todo_count => 0,
            start_time => 1000.0,
            start_at => '2025-09-08T17:26:43',
            seed => 12345,
            end_time => 1002.5,
        );

        like($result, qr/Duration=2\.50s/, 'shows duration in seconds');
    };

    subtest 'without optional fields' => sub {
        my $f = create_formatter();
        my $result = $f->_render_summary(
            fail_count => 0,
            pass_count => 1,
            total_count => 1,
            todo_count => 0,
            start_time => undef,
            start_at => undef,
            seed => undef,
            end_time => 1000.0,
        );

        like($result, qr/ PASS  All tests successful\./, 'shows PASS message');
        like($result, qr/Files=1, Tests=1/, 'shows basic counts');
        unlike($result, qr/Duration=/, 'no duration without start_time');
        unlike($result, qr/StartAt=/, 'no start time');
        unlike($result, qr/Seed=/, 'no seed');
    };

    subtest 'with color enabled - passing' => sub {
        my $f = create_formatter(color => 1);
        my $result = $f->_render_summary(
            fail_count => 0,
            pass_count => 5,
            total_count => 5,
            todo_count => 0,
            start_time => 1000.0,
            start_at => '2025-09-08T17:26:43',
            seed => 12345,
            end_time => 1001.0,
        );

        like($result, qr/\e\[42m\e\[1m\e\[38;5;16m PASS \e\[0m/, 'PASS label has green background');
        like($result, qr/\e\[32mAll tests successful\.\e\[0m/, 'success message is green');
    };

    subtest 'with color enabled - failing' => sub {
        my $f = create_formatter(color => 1);
        my $result = $f->_render_summary(
            fail_count => 1,
            pass_count => 4,
            total_count => 5,
            todo_count => 0,
            start_time => 1000.0,
            start_at => '2025-09-08T17:26:43',
            seed => 12345,
            end_time => 1001.0,
        );

        like($result, qr/\e\[41m\e\[1m\e\[38;5;16m FAIL \e\[0m/, 'FAIL label has red background');
        like($result, qr/\e\[31mTests failed\.\e\[0m/, 'failure message is red');
    };
};

done_testing;
