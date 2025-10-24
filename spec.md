# Test2::Formatter::Cute Specification

## Policy

- Make it easy to understand for beginners
  - Reference examples: vitest, bun test
- Keep the display output compact
  - Prepare for running only specific tests from editors like VS Code
- Ignore TAP format, but allow use with prove
  - prove tries to parse TAP format results to output Summary Report, but we'll hack this to make it ignorable
  - Development will proceed in the following order:
    1. First, run with perl like `T2_FORMATTER=Cute perl t/foo.t`
    2. Next, add prove support
    3. Finally, add yath support (Test2::Harness::Renderer::Cute)

## Specification

### Basic Format

Input:

```perl
# t/test.t
subtest 'foo' => sub {
  subtest 'nested foo1' => sub {
    ok 1, 'case1';
    ok 1, 'case2';
  }

  subtest 'nested foo2' => sub {
    ok 1, 'case1';
    ok 1, 'case2';
  }
}
```

Output:

```
✓ ./t/test.t [1.10ms]
  ✓ foo [1.05ms]
    ✓ nested foo1 [0.73ms]
      ✓ case1
      ✓ case2
    ✓ nested foo2 [0.30ms]
      ✓ case1
      ✓ case2

 PASS  All tests successful.
Files=1, Tests=7, Duration=1.10ms, StartAt=2025-09-08T17:26:43, Seed=20251023164910123
```

- Express test success/failure with ✓, ✘
  - ✓ is green text, ✘ is red text
- When all tests succeed: ` PASS  All tests successful.`
  - ` PASS ` has green background (including surrounding spaces, black text, bold)
  - `All tests successful.` is green text
  - Summary line does not show Pass/Fail counts
- When tests fail: ` FAIL  Tests failed.`
  - ` FAIL ` has red background (including surrounding spaces, black text, bold)
  - `Tests failed.` is red text
  - Add `Pass=N, Fail=M` to summary line
- When there are TODO tests: Add `Todo=N` to summary line
- Display execution time like [0.73ms]
  - Displayed for: test files, subtests
  - Gray text

### When Tests Fail

Input:

```perl
# t/failed-test.t
subtest 'foo' => sub {
  is 1+1, 2, 'case1';
  is 1-1, 1, 'case2';
  is 0-1, 1, 'case3';
}
```

Output:

```
✘ ./t/failed-test.t [1.10ms]
  ✘ foo [1.05ms]
    ✓ case1
    ✘ case2
    ✘ case3

 FAIL  t/failed-test.t > foo > case2

  Received eq Expected

  Expected: 1
  Received: 0

  ❯ t/failed-test.t:7
    5 | subtest 'foo' => sub {
    6 |   is 1+1, 2, 'case1';
  ✘ 7 |   is 1-1, 1, 'case2'; (spec note: red ✘ mark before the line)

 FAIL  t/failed-test.t > foo > case3

  Received eq Expected

  Expected: 1
  Received: -1

  ❯ t/failed-test.t:8
    5 | subtest 'foo' => sub {
    6 |   is 1+1, 2, 'case1';
    7 |   is 1-1, 1, 'case2';
  ✘ 8 |   is 0-1, 1, 'case3'; (spec note: red ✘ mark before the line)

 FAIL  Tests failed.
Files=1, Tests=3, Pass=1, Fail=2, Duration=1.10ms, StartAt=2025-09-08T17:26:43, Seed=20251023164910123
```

1. Display which file, which subtest, and which test case failed
  - Example: ` FAIL  t/failed-test.t > foo > case2`
  - ` FAIL ` is red background text (including surrounding spaces), followed by 2 spaces
  - Don't display `./` prefix for file path
  - `>` is gray text
2. ~~Use the table created by Test2's default for actual and expected values~~
  - For actual value, expected value, and the operator used, use a simple representation as shown in the Output above
    - Received is red text, Expected is green text, operator is bold
    - For `Expected: value` and `Received: value`, color only the labels
    - Values themselves are normal color
3. Display several lines of code around the relevant location
  - Display 4 lines before the relevant line
  - If the relevant line has `;`: end at that line (don't display following lines)
  - If the relevant line doesn't have `;`: display up to 5 lines ahead (but stop if `;` is found within those 5 lines)
  - Display a red `✘` mark before the relevant line
  - Normal lines are indented with 4 spaces, relevant line is indented with 2 spaces + `✘` + space

### Color Specification

- **Red text**: `\e[31m` (normal red)
  - Used for: ✘ mark, Received label, ✘ mark on relevant line, `Tests failed.`
- **Green text**: `\e[32m` (normal green)
  - Used for: ✓ mark, Expected label, `All tests successful.`
- **Red background**: `\e[41m\e[1m\e[38;5;16m` (red background + bold + dark black text)
  - Used for: ` FAIL ` in failure details, ` FAIL ` in summary
- **Green background**: `\e[42m\e[1m\e[38;5;16m` (green background + bold + dark black text)
  - Used for: ` PASS ` in summary
- **Gray text**: `\e[90m`
  - Used for: time display, `>` separator
- **Bold**: `\e[1m`
  - Used for: comparison operators (eq, ne, etc.)

## TODO Test Handling

TODO tests (tests within `todo` blocks) are treated as known failures that will be fixed in the future.

### Display Method
- TODO failed test: `✘ test name # TODO reason` (displayed in gray)
- TODO passed test: `✓ test name # TODO reason` (displayed in gray)

### Counting
- TODO tests are **excluded** from the total test count
- TODO test success/failure does **not affect** the result of parent subtests or files
- Even if TODO tests fail, subtests and files are displayed as successful (✓)

### Failure Details
- Failed TODO tests also display details like regular failures
  - FAIL path
  - GOT/OP/CHECK table
  - Source code context

### Output Example

```
✓ t/examples/todo.t [1.00ms]
  ✓ todo [0.80ms]
    ✓ pass case
    ✘ 1 + 1 should equal 3 (but it does not) # TODO fail todo
    ✓ 2 * 2 should equal 4 (and it does) # TODO pass todo

 FAIL  t/examples/todo.t > todo > 1 + 1 should equal 3 (but it does not)

  Received eq Expected

  Expected: 3
  Received: 2

  ❯ t/examples/todo.t:6
    2 |
    3 | subtest 'todo' => sub {
    4 |     ok 1, 'pass case';
    5 |     todo 'fail todo' => sub {
  ✘ 6 |         is(1 + 1, 3, '1 + 1 should equal 3 (but it does not)');


 PASS  All tests successful.
Files=1, Tests=1, Todo=2, Duration=1.10ms, StartAt=2025-09-08T17:26:43, Seed=20251023164910123
```

Note: Total test count is 1 (only `pass case`). The 2 TODO tests are excluded and displayed as `Todo=2`. TODO failure details are shown, but not included in FAIL count.
