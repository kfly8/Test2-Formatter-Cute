# Test2::Formatter::Cute の仕様

## 方針

- 初学者にもわかりやすくする
  - 参考例は、vitest, bun test
- 表示内容をコンパクトにする
  - VS Codeなどエディタから指定されたテストだけを実行することに備える
- TAP形式は無視するが、proveを利用できるようにする
  - proveはSummary Reportを出すために、TAP形式の結果をparseしようとするが、ココをハックして、無視できるようにする
  - 開発の進め方は次の順で進める
    1. まず、T2_FORMATTER=Cute perl t/foo.t のようにperlを利用して動かす
    2. 次に、prove対応を行う
    3. 最後に、yath対応( Test2::Harness::Renderer::Cute ) を行う

## 仕様

### 基本フォーマット

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
# T2_RAND_SEED=20251023164910123
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

- ✓, ✘ で、テストの成否を表現する
  - ✓は緑文字、✘は赤文字
- 全てのテストが成功した場合：` PASS  All tests successful.`
  - ` PASS ` は緑背景（前後スペース含む、文字色は黒、太字）
  - `All tests successful.` は緑文字
  - サマリー行には Pass/Fail 数を表示しない
- 失敗したテストがある場合：` FAIL  Tests failed.`
  - ` FAIL ` は赤背景（前後スペース含む、文字色は黒、太字）
  - `Tests failed.` は赤文字
  - サマリー行に `Pass=N, Fail=M` を追加
- [0.73ms] のようにテストの実行時間を表示する
  - 表示対象は、テストファイル、subtest
  - 灰色文字表示

### 失敗するテストがある場合

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
  ✘ 7 |   is 1-1, 1, 'case2'; (仕様注釈: 該当行の前に赤い✘マーク)

 FAIL  t/failed-test.t > foo > case3

  Received eq Expected

  Expected: 1
  Received: -1

  ❯ t/failed-test.t:8
    5 | subtest 'foo' => sub {
    6 |   is 1+1, 2, 'case1';
    7 |   is 1-1, 1, 'case2';
  ✘ 8 |   is 0-1, 1, 'case3'; (仕様注釈: 該当行の前に赤い✘マーク)

 FAIL  Tests failed.
Files=1, Tests=3, Pass=1, Fail=2, Duration=1.10ms, StartAt=2025-09-08T17:26:43, Seed=20251023164910123
```

1. どのファイルのどのsubtestのどのテストケースで失敗したのか表示する
  - 例: ` FAIL  t/failed-test.t > foo > case2`
  - ` FAIL `は赤背景文字（前後スペース含む）、後ろに2スペース
  - ファイルパスの `./` プレフィックスは表示しない
  - `>` は灰色文字
2. ~~実際に得た値と期待値は、Test2でデフォルトで作成している表を利用する~~
  - 実際に得た値と期待値とそれに用いたオペレーターは、上記のOutputの通り、簡易表現にする
    - Received は赤文字、Expected は緑文字、オペレーターは太字にする
    - `Expected: 値`, `Received: 値` に関しては、ラベルだけ色付けしてください。
    - 値自体は通常色
3. 該当箇所のコードを数行遡って表示する
  - 該当行の前4行を表示
  - 該当行に`;`がある場合：その行で終わり（後ろの行は表示しない）
  - 該当行に`;`がない場合：5行先まで表示（ただし、5行以内に`;`があれば、そこで打ち止め）
  - 該当行の前に赤い`✘`マークを表示する
  - 通常行は4スペースでインデント、該当行は2スペース + `✘` + スペースでインデント

### 色の仕様

- **赤文字**: `\e[31m` (通常の赤)
  - 使用箇所: ✘マーク、Receivedラベル、該当行の✘マーク、`Tests failed.`
- **緑文字**: `\e[32m` (通常の緑)
  - 使用箇所: ✓マーク、Expectedラベル、`All tests successful.`
- **赤背景**: `\e[41m\e[1m\e[38;5;16m` (赤背景 + 太字 + 濃い黒文字)
  - 使用箇所: 失敗詳細の` FAIL `、サマリーの` FAIL `
- **緑背景**: `\e[42m\e[1m\e[38;5;16m` (緑背景 + 太字 + 濃い黒文字)
  - 使用箇所: サマリーの` PASS `
- **灰色文字**: `\e[90m`
  - 使用箇所: 時間表示、`>`セパレーター
- **太字**: `\e[1m`
  - 使用箇所: 比較演算子 (eq, ne, etc.)

## TODOテストの扱い

TODOテスト（`todo` ブロック内のテスト）は、将来的に修正予定の既知の失敗として扱われます。

### 表示方法
- TODO失敗テスト: `✘ test name # TODO reason` (灰色で表示)
- TODO成功テスト: `✓ test name # TODO reason` (灰色で表示)

### カウント
- TODOテストは、テスト総数のカウントから**除外**する
- TODOテストの成功/失敗は、親のsubtestやファイルの結果に**影響を与えない**
- TODOで失敗したテストがあっても、subtestとファイルは成功（✓）と表示

### 失敗詳細
- TODOで失敗したテストも、通常の失敗と同様に詳細を表示する
  - FAIL パス
  - GOT/OP/CHECK テーブル
  - ソースコードコンテキスト

### 出力例

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
Files=1, Tests=1, Duration=1.10ms, StartAt=2025-09-08T17:26:43, Seed=20251023164910123
```

注: テスト総数は1（`pass case`のみ）。TODOテスト2つは除外される。TODOの失敗詳細は表示されるが、FAIL カウントには含まれない。

