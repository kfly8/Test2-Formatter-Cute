[![Actions Status](https://github.com/kfly8/Test2-Formatter-Cute/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/kfly8/Test2-Formatter-Cute/actions?workflow=test) [![MetaCPAN Release](https://badge.fury.io/pl/Test2-Formatter-Cute.svg)](https://metacpan.org/release/Test2-Formatter-Cute)
# NAME

Test2::Formatter::Cute - Test2 formatter with cute output

# SYNOPSIS

```
❯ T2_FORMATTER=Cute perl -Ilib t/examples/basic.pl
✓ t/examples/basic.pl [0.46ms]
  ✓ foo [0.30ms]
    ✓ nested foo1 [0.06ms]
      ✓ case1
      ✓ case2
    ✓ nested foo2 [0.03ms]
      ✓ case1
      ✓ case2

PASS  All tests successful.
Files=1, Tests=7, Duration=0.46ms, Seed=20251025
```

# DESCRIPTION

Test2::Formatter::Cute is a Test2 formatter that makes test output visually clearer and easier to read.

## Features

- Emoji-based test results (✓ for pass, ✘ for fail)
- Hierarchical subtest display with proper indentation
- Detailed failure information with source code context
- Execution time tracking for tests and subtests

## Output Format

The formatter produces output like:

```perl
✓ t/basic.t [12.34ms]
  ✓ basic test
  ✓ subtest [5.67ms]
    ✓ nested test 1
    ✓ nested test 2

 PASS  All tests successful.
Files=1, Tests=3, Duration=12.34ms, Seed=20251024
```

For failed tests, detailed information is displayed:

```perl
✘ t/failed.t [10.50ms]
  ✓ passing test
  ✘ failing test

 FAIL  t/failed.t > failing test

  Received eq Expected

  Expected: foo
  Received: bar

  ❯ t/failed.t:7
    5 | use Test2::V0;
    6 |
  ✘ 7 | is $got, $expected;

 FAIL  Tests failed.
Files=1, Tests=2, Pass=1, Fail=1, Duration=10.50ms, Seed=20251024
```

# INTEGRATION

## With prove

Use [App::Prove::Plugin::Cute](https://metacpan.org/pod/App%3A%3AProve%3A%3APlugin%3A%3ACute) for the best experience:

```
prove -PCute -lv t/
```

# METHODS

## new

```perl
my $formatter = Test2::Formatter::Cute->new(%options);
```

Creates a new formatter instance.

Options:

- `color` - Enable/disable color output (default: auto-detect from terminal)
- `encoding` - Set output encoding (default: UTF-8)
- `handles` - Array reference of output handles \[STDOUT, STDERR\]

## write

```
$formatter->write($event, $num);
```

Processes a Test2 event and buffers output.

## finalize

```
$formatter->finalize();
```

Outputs buffered content with file header, failure details, and summary.

## encoding

```perl
$formatter->encoding($encoding);
my $enc = $formatter->encoding();
```

Get or set the output encoding.

## hide\_buffered

```perl
my $bool = $formatter->hide_buffered();
```

Returns true to indicate this formatter buffers output.

# SEE ALSO

- [App::Prove::Plugin::Cute](https://metacpan.org/pod/App%3A%3AProve%3A%3APlugin%3A%3ACute) - Prove plugin for easy usage

# AUTHOR

kfly8

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
