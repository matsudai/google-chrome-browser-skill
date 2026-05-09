# Browser skill for Claude Code

## Getting started

```sh
ruby -v # => ruby 4.0.3
gem install ferrum # => 0.17.2

git clone https://github.com/matsudai/google-chrome-browser-skill.git
mv google-chrome-browser-skill/.claude/skills/browser .claude/skills/
rm -r google-chrome-browser-skill

claude # => Usage
```

## Usage

```txt
/browser https://example.com のスクショをx.pngに保存
    # ● https://example.com のスクリーンショットを x.png (17KB) に保存しました。

ボタン・リンクの一覧
    # ● https://example.com のボタン・リンク一覧:
    #
    #   リンク (1件)
    #   - "Learn more" → https://iana.org/domains/example
    #
    #   ボタン
    #   - なし

/browser stop # Or ctrl+c Claude Code
```

## Uninstall

```sh
rm -r .claude/skills/browser/
rm -r ~/.claude/cache-browser-user-data-dirs/
```
