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
✓ ./t/test.t [1.10ms]
  ✓ foo [1.05ms]
    ✓ nested foo1 [0.73ms]
      ✓ case1
      ✓ case2
    ✓ nested foo2 [0.30ms]
      ✓ case1
      ✓ case2

8 PASS
0 FAIL
Files=1, Tests=8 [1.10ms]
```

- ✓, ✘ で、テストの成否を表現する
  - ✓は緑文字、✘は赤文字
- 8 PASS のように成功したテストの数を結果表示する
  - 緑背景表示
- 5 FAIL のように失敗したテストの数を結果表示する
  - 1件以上あれば、赤背景表示。0件であれば、灰色文字
- [0.73ms] のようにテストの実行時間を表示する
  - 表示対象は、テストファイル、subtest、結果
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

⎯⎯⎯⎯⎯⎯⎯⎯  FAILED TEST 1 ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
FAIL ./t/failed-test.t > foo > case2

 +-----+----+-------+
 | GOT | OP | CHECK |
 +-----+----+-------+
 | 0   | eq | 1     |
 +-----+----+-------+

 ❯ t/failed-test.t:7
5 | subtest 'foo' => sub {
6 |   is 1+1, 2, 'case1';
7 |   is 1-1, 1, 'case2'; (仕様注釈: 該当行を太字にする)

⎯⎯⎯⎯⎯⎯⎯⎯  FAILED TEST 2 ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
FAIL ./t/failed-test.t > foo > case3

 +-----+----+-------+
 | GOT | OP | CHECK |
 +-----+----+-------+
 | -1  | eq | 1     |
 +-----+----+-------+

 ❯ t/failed-test.t:8
5 | subtest 'foo' => sub {
6 |   is 1+1, 2, 'case1';
7 |   is 1-1, 1, 'case2';
8 |   is 0-1, 1, 'case3'; (仕様注釈: 該当行を太字にする)

⎯⎯⎯⎯⎯⎯⎯⎯ ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ ⎯⎯⎯⎯⎯

1 PASS
2 FAIL
Files=1, Tests=3 [1.10ms]
```

1. どのファイルのどのsubtestのどのテストケースで失敗したのか表示する
  - 例: FAIL ./t/failed-test.t > foo > case2
  - FAILは赤背景文字
  - > は灰色文字
2. 実際に得た値と期待値は、Test2でデフォルトで作成している表を利用する
3. 該当箇所のコードを数行遡って表示する
  - 該当行は、太字にする
4. 失敗したテストごとに、区切り線で区切る
  - 区切り線は、赤色
  - FAILED TEST 2 のように見出しをつける。数字はいくつめの失敗かを示す

