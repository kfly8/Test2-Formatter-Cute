package Test2::Formatter::Cute;
use strict;
use warnings;

use Time::HiRes qw(time);
use Test2::Util qw(clone_io);
use Test2::Util::HashBase qw(
    handles _encoding color
    _file_printed _test_file
    _pass_count _fail_count _total_count
    _output_buffer
    _start_time _start_at
    _failures
    _subtest_stack
    _seed
);

use parent 'Test2::Formatter';

sub OUT_STD() { 0 }
sub OUT_ERR() { 1 }

sub hide_buffered { 1 }

sub init {
    my $self = shift;
    $self->{+HANDLES} ||= $self->_open_handles;

    # Check if color is enabled via environment or parameter
    if (!defined $self->{+COLOR}) {
        # Check environment variables
        $self->{+COLOR} = $ENV{CURE_COLOR} || $ENV{HARNESS_IS_VERBOSE} || (-t STDOUT ? 1 : 0);
    }

    # Initialize counters and state
    $self->{+_FILE_PRINTED} = 0;
    $self->{+_TEST_FILE} = undef;
    $self->{+_PASS_COUNT} = 0;
    $self->{+_FAIL_COUNT} = 0;
    $self->{+_TOTAL_COUNT} = 0;
    $self->{+_OUTPUT_BUFFER} = '';
    $self->{+_START_TIME} = undef;
    $self->{+_START_AT} = undef;
    $self->{+_FAILURES} = [];
    $self->{+_SUBTEST_STACK} = [];
    $self->{+_SEED} = $ENV{T2_RAND_SEED} || undef;

    if (my $enc = delete $self->{encoding}) {
        $self->encoding($enc);
    }
}

sub _colorize {
    my ($self, $text, $color) = @_;

    return $text unless $self->{+COLOR};

    my %colors = (
        bold  => "\e[1m",
        green => "\e[32m",            # Green text (same color as green_bg)
        red   => "\e[31m",            # Red text (same color as red_bg)
        gray  => "\e[90m",
        reset => "\e[0m",
        green_bg => "\e[42m\e[1m\e[38;5;16m",  # Green background with darker black text and bold
        red_bg   => "\e[41m\e[1m\e[38;5;16m",  # Red background with darker black text and bold
    );

    return $text unless exists $colors{$color};
    return "$colors{$color}$text$colors{reset}";
}

sub _format_duration {
    my ($self, $start, $end, $with_brackets, $with_color) = @_;
    return '' unless defined $start && defined $end;

    my $duration = $end - $start;
    my $formatted;

    if ($duration < 1) {
        # Less than 1 second: show in milliseconds
        $formatted = sprintf("%.2fms", $duration * 1000);
    } else {
        # 1 second or more: show in seconds
        $formatted = sprintf("%.2fs", $duration);
    }

    # Default to brackets for backward compatibility
    $with_brackets = 1 unless defined $with_brackets;
    # Default to gray color for backward compatibility
    $with_color = 1 unless defined $with_color;
    
    my $text = $with_brackets ? "[$formatted]" : $formatted;
    return ($self->{+COLOR} && $with_color) ? $self->_colorize($text, 'gray') : $text;
}

sub _open_handles {
    my $self = shift;

    require Test2::API;
    my $out = clone_io(Test2::API::test2_stdout());
    my $err = clone_io(Test2::API::test2_stderr());

    # Enable UTF-8 for emoji output
    binmode($out, ":utf8");
    binmode($err, ":utf8");

    return [$out, $err];
}

sub encoding {
    my $self = shift;

    if (@_) {
        my ($enc) = @_;
        my $handles = $self->{+HANDLES};

        if ($enc =~ m/^utf-?8$/i) {
            binmode($_, ":utf8") for @$handles;
        }
        else {
            binmode($_, ":encoding($enc)") for @$handles;
        }
        $self->{+_ENCODING} = $enc;
    }

    return $self->{+_ENCODING};
}

sub write {
    my ($self, $e, $num) = @_;

    my $f = $e->facet_data;

    # Handle control events (like encoding)
    $self->encoding($f->{control}{encoding}) if $f->{control} && $f->{control}{encoding};

    # Capture file name and start time from first event with assertion
    # (Skip non-test events like SRand plugin)
    if (!$self->{+_FILE_PRINTED} && $f->{assert} && $f->{trace}) {
        my $file = $f->{trace}{frame}[1];
        if ($file) {
            $self->{+_TEST_FILE} = $file;
            $self->{+_FILE_PRINTED} = 1;
            # Record start time from parent if available
            if ($f->{parent} && defined $f->{parent}{start_stamp}) {
                $self->{+_START_TIME} = $f->{parent}{start_stamp};
                # Format start time as ISO 8601
                my @t = localtime($self->{+_START_TIME});
                $self->{+_START_AT} = sprintf("%04d-%02d-%02dT%02d:%02d:%02d",
                    $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
            }
        }
    }

    # Skip plan events - we don't output them in our format
    return if $f->{plan} && !$f->{assert};

    # Process assertions (tests and subtests)
    if ($f->{assert}) {
        my $pass = $f->{assert}{pass};
        my $name = $f->{assert}{details} || '(no name)';
        my $nesting = $f->{trace}{nested} || 0;

        # Check if this is a TODO test
        my $is_todo = 0;
        my $todo_reason = '';
        if ($f->{amnesty} && @{$f->{amnesty}}) {
            for my $amnesty (@{$f->{amnesty}}) {
                if ($amnesty->{tag} eq 'TODO') {
                    $is_todo = 1;
                    $todo_reason = $amnesty->{details} || '';
                    last;
                }
            }
        }

        # For top-level events (nesting=0), add 1 to indent under file header
        my $indent_level = $nesting + 1;
        my $indent = '  ' x $indent_level;

        # Choose emoji based on pass/fail
        my $emoji = $pass ? "\x{2713}" : "\x{2718}";  # ✓ or ✘
        my $color = $is_todo ? 'gray' : ($pass ? 'green' : 'red');
        $emoji = $self->_colorize($emoji, $color);

        # If this is a subtest with children, output all children recursively
        if ($f->{parent} && $f->{parent}{children}) {
            # Count this subtest only if it has nested subtests (not just individual tests)
            # Check if any child is also a subtest
            my $has_nested_subtests = 0;
            for my $child (@{$f->{parent}{children}}) {
                if ($child->{parent} && $child->{parent}{children}) {
                    $has_nested_subtests = 1;
                    last;
                }
            }

            # Count top-level subtest only if it contains nested subtests and not TODO
            if ($nesting == 0 && $has_nested_subtests && !$is_todo) {
                $self->{+_TOTAL_COUNT}++;
                if ($pass) {
                    $self->{+_PASS_COUNT}++;
                } else {
                    $self->{+_FAIL_COUNT}++;
                }
            }

            # Format time for subtest
            my $time_str = '';
            if ($f->{parent}{start_stamp} && $f->{parent}{stop_stamp}) {
                $time_str = ' ' . $self->_format_duration(
                    $f->{parent}{start_stamp},
                    $f->{parent}{stop_stamp}
                );
            }
            my $todo_suffix = $is_todo ? " # TODO $todo_reason" : '';
            $self->{+_OUTPUT_BUFFER} .= "$indent$emoji $name$time_str$todo_suffix\n";

            # Push subtest name to stack for tracking path
            push @{$self->{+_SUBTEST_STACK}}, $name;
            $self->_write_children($f->{parent}{children}, $indent_level + 1);
            pop @{$self->{+_SUBTEST_STACK}};
        }
        else {
            # Regular test - count it (for top-level tests without children) and not TODO
            if (!$is_todo) {
                $self->{+_TOTAL_COUNT}++;
                if ($pass) {
                    $self->{+_PASS_COUNT}++;
                } else {
                    $self->{+_FAIL_COUNT}++;
                }
            }

            # Record failure information (including TODO failures)
            if (!$pass) {
                $self->_record_failure($f, $name);
            }
            my $todo_suffix = $is_todo ? " # TODO $todo_reason" : '';
            $self->{+_OUTPUT_BUFFER} .= "$indent$emoji $name$todo_suffix\n";
        }
    }

    # Handle errors
    if ($f->{errors}) {
        my $nesting = $f->{trace}{nested} || 0;
        my $indent_level = $nesting + 1;
        my $indent = '  ' x $indent_level;
        for my $error (@{$f->{errors}}) {
            my $error_emoji = $self->_colorize("\x{2718}", 'red');
            $self->{+_OUTPUT_BUFFER} .= "$indent$error_emoji Error: $error->{details}\n";
        }
    }
}

sub _write_children {
    my ($self, $children, $indent_level) = @_;

    my $indent = '  ' x $indent_level;

    for my $child (@$children) {
        # Skip plan events
        next if $child->{plan};

        # Skip info/note events for cleaner output
        next if $child->{info} && !$child->{assert};

        if ($child->{assert}) {
            my $pass = $child->{assert}{pass};
            my $name = $child->{assert}{details} || '(no name)';

            # Check if this is a TODO test
            my $is_todo = 0;
            my $todo_reason = '';
            if ($child->{amnesty} && @{$child->{amnesty}}) {
                for my $amnesty (@{$child->{amnesty}}) {
                    if ($amnesty->{tag} eq 'TODO') {
                        $is_todo = 1;
                        $todo_reason = $amnesty->{details} || '';
                        last;
                    }
                }
            }

            my $emoji = $pass ? "\x{2713}" : "\x{2718}";  # ✓ or ✘
            my $color = $is_todo ? 'gray' : ($pass ? 'green' : 'red');
            $emoji = $self->_colorize($emoji, $color);

            # Count this assertion (skip TODO tests)
            if (!$is_todo) {
                $self->{+_TOTAL_COUNT}++;
                if ($pass) {
                    $self->{+_PASS_COUNT}++;
                } else {
                    $self->{+_FAIL_COUNT}++;
                }
            }

            # If this child is a subtest with children
            if ($child->{parent} && $child->{parent}{children}) {
                # Format time for nested subtest
                my $time_str = '';
                if ($child->{parent}{start_stamp} && $child->{parent}{stop_stamp}) {
                    $time_str = ' ' . $self->_format_duration(
                        $child->{parent}{start_stamp},
                        $child->{parent}{stop_stamp}
                    );
                }
                my $todo_suffix = $is_todo ? " # TODO $todo_reason" : '';
                $self->{+_OUTPUT_BUFFER} .= "$indent$emoji $name$time_str$todo_suffix\n";

                # Push subtest name to stack
                push @{$self->{+_SUBTEST_STACK}}, $name;
                $self->_write_children($child->{parent}{children}, $indent_level + 1);
                pop @{$self->{+_SUBTEST_STACK}};
            }
            else {
                # Regular test (no time display for individual assertions)
                my $todo_suffix = $is_todo ? " # TODO $todo_reason" : '';
                $self->{+_OUTPUT_BUFFER} .= "$indent$emoji $name$todo_suffix\n";

                # Record failure for individual test (including TODO failures)
                if (!$pass) {
                    $self->_record_failure($child, $name);
                }
            }
        }

        # Handle errors in children
        if ($child->{errors}) {
            for my $error (@{$child->{errors}}) {
                my $error_emoji = $self->_colorize("\x{2718}", 'red');
                $self->{+_OUTPUT_BUFFER} .= "$indent$error_emoji Error: $error->{details}\n";
            }
        }
    }
}

sub _record_failure {
    my ($self, $facet_data, $test_name) = @_;

    # Build the subtest path
    my @path = (@{$self->{+_SUBTEST_STACK}}, $test_name);

    # Extract failure details from facet data
    my $failure_info = {
        name => $test_name,
        path => \@path,
        file => $facet_data->{trace}{frame}[1] || $self->{+_TEST_FILE},
        line => $facet_data->{trace}{frame}[2] || 0,
        facet => $facet_data,
    };

    push @{$self->{+_FAILURES}}, $failure_info;
}

sub finalize {
    my ($self, $options) = @_;
    my $io = $self->{+HANDLES}[OUT_STD];

    # Calculate total time
    my $end_time = time;
    my $total_time_str = '';
    if (defined $self->{+_START_TIME}) {
        $total_time_str = ' ' . $self->_format_duration($self->{+_START_TIME}, $end_time);
    }

    # Get seed from Test2::Plugin::SRand if available
    if (!$self->{+_SEED}) {
        eval {
            require Test2::Plugin::SRand;
            $self->{+_SEED} = Test2::Plugin::SRand->seed;
        };
    }

    # Print file header (now we know if there were failures)
    if ($self->{+_TEST_FILE}) {
        my $file = $self->{+_TEST_FILE};
        my $has_failures = $self->{+_FAIL_COUNT} > 0;
        my $emoji = $has_failures ? "\x{2718}" : "\x{2713}";
        my $color = $has_failures ? 'red' : 'green';
        $emoji = $self->_colorize($emoji, $color);

        print $io "$emoji $file$total_time_str\n";
    }

    # Print buffered output
    print $io $self->{+_OUTPUT_BUFFER};

    # Print failure details
    if (@{$self->{+_FAILURES}}) {
        print $io "\n";
        my $failure_num = 1;
        for my $failure (@{$self->{+_FAILURES}}) {
            # Fail path: FAIL  file > subtest > test
            my @path_parts = @{$failure->{path}};
            my $file_path = $failure->{file};
            my $fail_label = " FAIL ";
            $fail_label = $self->_colorize($fail_label, 'red_bg') if $self->{+COLOR};

            my $separator_color = $self->{+COLOR} ? $self->_colorize('>', 'gray') : '>';
            my $path_str = join(" $separator_color ", @path_parts);
            print $io "$fail_label $file_path $separator_color $path_str\n";

            # Extract GOT/OP/CHECK data from facet
            my $facet = $failure->{facet};
            if ($facet->{info}) {
                for my $info (@{$facet->{info}}) {
                    if ($info->{table}) {
                        my $table = $info->{table};
                        # Get the comparison data
                        if ($table->{rows} && @{$table->{rows}}) {
                            my $row = $table->{rows}[0];
                            # Extract GOT, OP, CHECK based on header positions
                            my $received = $row->[2] // '';
                            my $op = $row->[3] // '';
                            my $expected = $row->[4] // '';

                            print $io "\n";
                            # First line: "Received {op} Expected" with bold operator
                            my $received_label = $self->{+COLOR} ? $self->_colorize('Received', 'red') : 'Received';
                            my $expected_label = $self->{+COLOR} ? $self->_colorize('Expected', 'green') : 'Expected';
                            my $op_bold = $self->{+COLOR} ? $self->_colorize($op, 'bold') : $op;
                            print $io "  $received_label $op_bold $expected_label\n";

                            print $io "\n";
                            # Second line: "Expected: {value}" - only label colored in green
                            my $expected_label_only = $self->{+COLOR} ? $self->_colorize('Expected:', 'green') : 'Expected:';
                            print $io "  $expected_label_only $expected\n";

                            # Third line: "Received: {value}" - only label colored in red
                            my $received_label_only = $self->{+COLOR} ? $self->_colorize('Received:', 'red') : 'Received:';
                            print $io "  $received_label_only $received\n";
                        }
                    }
                }
            }

            # Source code context
            my $file = $failure->{file};
            my $line = $failure->{line};
            if ($file && $line && -f $file) {
                print $io "\n";
                # Show file path and line number: ❯ t/failed-test.t:7
                my $arrow = "\x{276F}";  # ❯
                $arrow = $self->_colorize($arrow, 'gray') if $self->{+COLOR};
                print $io "  $arrow $file:$line\n";

                if (open my $fh, '<', $file) {
                    my @lines = <$fh>;
                    close $fh;

                    # Show context: 4 lines before the failing line
                    my $start = $line - 5 > 0 ? $line - 5 : 0;

                    # Determine end: if failing line has ';', show up to that line
                    # Otherwise, show up to 5 lines after, but stop at first ';'
                    my $end;
                    my $statement_end;  # Track where the statement ends (for bolding)
                    if ($line - 1 < @lines && $lines[$line - 1] =~ /;/) {
                        # Failing line has ';', show only up to that line
                        $end = $line - 1;
                        $statement_end = $line;
                    } else {
                        # Failing line doesn't have ';', look ahead up to 5 lines
                        my $max_end = $line + 4 < @lines ? $line + 4 : $#lines;
                        $end = $max_end;
                        $statement_end = $line;  # Default to failing line only

                        # Search for ';' in the next 5 lines
                        for my $i ($line .. $max_end) {
                            if ($lines[$i] =~ /;/) {
                                $end = $i;
                                $statement_end = $i + 1;  # Include the line with ';'
                                last;
                            }
                        }
                    }

                    for my $i ($start .. $end) {
                        my $line_num = $i + 1;
                        my $content = $lines[$i];
                        chomp $content;

                        # Show ✘ marker with red color before line number for failing statement
                        if ($line_num >= $line && $line_num <= $statement_end) {
                            my $x_mark = "\x{2718}";  # ✘
                            my $red_x = $self->{+COLOR} ? $self->_colorize($x_mark, 'red') : $x_mark;
                            print $io sprintf("  %s %d | %s\n", $red_x, $line_num, $content);
                        } else {
                            print $io sprintf("    %d | %s\n", $line_num, $content);
                        }
                    }
                }
            }

            print $io "\n";
            $failure_num++;
        }
    }

    # Print summary
    print $io "\n";

    # Overall result: PASS or FAIL
    if ($self->{+_FAIL_COUNT} > 0) {
        # Has failures
        my $fail_label = " FAIL ";
        my $fail_message = "Tests failed.";
        if ($self->{+COLOR}) {
            $fail_label = $self->_colorize($fail_label, 'red_bg');
            $fail_message = $self->_colorize($fail_message, 'red');
        }
        print $io "$fail_label $fail_message\n";
    } else {
        # All tests passed
        my $pass_label = " PASS ";
        my $pass_message = "All tests successful.";
        if ($self->{+COLOR}) {
            $pass_label = $self->_colorize($pass_label, 'green_bg');
            $pass_message = $self->_colorize($pass_message, 'green');
        }
        print $io "$pass_label $pass_message\n";
    }

    # Files and Tests count
    my $summary = "Files=1, Tests=$self->{+_TOTAL_COUNT}";

    # Add Pass/Fail counts if there are failures
    if ($self->{+_FAIL_COUNT} > 0) {
        $summary .= ", Pass=$self->{+_PASS_COUNT}, Fail=$self->{+_FAIL_COUNT}";
    }

    # Add Duration
    if (defined $self->{+_START_TIME}) {
        my $duration_str = $self->_format_duration($self->{+_START_TIME}, $end_time, 0, 0);  # 0 = no brackets, 0 = no color
        $summary .= ", Duration=$duration_str";
    }

    # Add StartAt
    if ($self->{+_START_AT}) {
        $summary .= ", StartAt=$self->{+_START_AT}";
    }

    # Add Seed
    if ($self->{+_SEED}) {
        $summary .= ", Seed=$self->{+_SEED}";
    }

    print $io "$summary\n";

    return;
}

1;
