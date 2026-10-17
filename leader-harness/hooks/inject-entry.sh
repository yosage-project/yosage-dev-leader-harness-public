#!/usr/bin/env bash
# inject-entry.sh — SessionStart でリーダーの入口をメインセッションへ注入する。
# サブエージェントの起動時に SessionStart は発火しないので、サブエージェントには入らない。
# 注入する文は命令形ではなく取り決めを述べる書き方にし、出どころの前置きを付ける
# (出典: Claude Code の hooks リファレンス「Add context for Claude」)。
# 失敗は標準エラー出力の1行目＋exit 1 で利用者に見える形にする(hook error の表示は先頭行だけ)。
set -uo pipefail
cat >/dev/null   # フックの入力 JSON は使わないが、読み切ってから終了する

entry="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/entry.md"
if [ ! -r "$entry" ] || [ ! -s "$entry" ]; then
  printf 'yosage-dev-leader-harness: リーダーの入口（%s）が読めないため、注入できませんでした\n' "$entry" >&2
  exit 1
fi

PREFACE="以下は、このリポジトリで利用者が有効にしたプラグイン yosage-dev-leader-harness の取り決めです（リーダーの入口）。"
printf '%s\n\n' "$PREFACE"
cat "$entry"
exit 0
