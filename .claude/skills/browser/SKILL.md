---
name: browser
description: Headless Chrome (Ferrum) と永続Ruby DRbサーバの統合。状態を保持して漸進的にブラウザ操作・任意Rubyコード評価。
disable-model-invocation: true
argument-hint: "[start|stop|eval CODE|status]"
allowed-tools: Bash(ruby *), Bash(pkill -TERM -f "browser/scripts/server.rb*")
---

操作: $ARGUMENTS

引数なしは使い方表示。

## 構造

- skill配布物: `scripts/server.rb` / `scripts/client.rb` (skillに同梱)
- ベースdir: `~/.claude/cache-browser-user-data-dirs/` (動作中のみ存在、全instance消滅でrm)
- インスタンスdir: `instance-rb<RUBY_PID>-cl<CLAUDE_PID>/` 配下に `sock` (DRb UNIX socket) と `chrome/` (Ferrum user-data-dir)
- dir名にsession_idは含めない(UNIX sock pathの108byte制限回避)。識別はclaude_pid(cl<pid>)で十分
- 通信: DRb (`drbunix:<sock>`)、stdlib完結
- 状態保持: サーバの`TOPLEVEL_BINDING`に`browser`変数とユーザー定義値が残る (`page`は`browser.page`)
- supervisor: claude_pidを60秒polling、消えれば自殺
- chrome trap: `Process.wait2(chrome_pid)`スレッドで死亡検知→cleanup→自殺
- 終了系: `trap('TERM')` + `at_exit` でChrome quit + 自分のinstance dir rm
- 起動時掃除: 過去instanceのうちclaude_pidが死亡してるものをrm

## start

```
ruby .claude/skills/browser/scripts/server.rb --session=$CLAUDE_CODE_SESSION_ID
```

を **run_in_background:true** で起動。stdoutに `ready: sock=<path> pid=<rb> chrome_pid=<chrome>` が出ることを確認。

同 claude_pid のinstance dirが既存なら使い回し、新規起動不要。

## stop

```
pkill -TERM -f "browser/scripts/server.rb --session=$CLAUDE_CODE_SESSION_ID"
```

## eval CODE

```
ruby .claude/skills/browser/scripts/client.rb "<CODE>"
```

`<CODE>`は任意Ruby。前回定義の変数・メソッドや `browser` がそのまま使える。

例:
- `ruby .claude/skills/browser/scripts/client.rb 'browser.go_to("https://example.com"); browser.page.title'`
- `ruby .claude/skills/browser/scripts/client.rb 'x = 42'`
- `ruby .claude/skills/browser/scripts/client.rb 'puts x * 2'`

## status

`ruby .claude/skills/browser/scripts/client.rb 'puts "alive pid=#{Process.pid} chrome=#{browser.process.pid}"'`

## 注意

- eval内で`exit`/`exit!`を呼ぶとサーバが落ちて状態消失。
- 無限ループはサーバ側で回り続ける。`Timeout.timeout`等でガード、または`stop`→`start`。
- 巨大出力(`puts`に大量データ)はDRbシリアライズに時間がかかる。出力は適度に切り詰める。
- claude本体終了で60秒以内にサーバ自殺・cleanup。SIGKILL系で漏れたら次回`start`時の起動時掃除で回収。
- スクリーンショット等の画像ファイルを保存した場合、**ユーザーから明示的にReadせよと指示がない限り、Claudeは画像をReadしない**(トークン節約のため)。
