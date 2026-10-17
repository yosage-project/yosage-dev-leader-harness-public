#!/usr/bin/env bash
# test/run.sh — yosage-dev-leader-harness 自己テスト(プラグインの骨格・.gitignore・規律の静的検査)。
#   使い方: bash test/run.sh (任意の cwd から)。失敗があれば exit 1。
#   外部依存: bash, git, jq(または python3), find, cmp/shasum などの POSIX 系ツール。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
_failures=()

# 後始末漏れ検知: 開始時の git status --porcelain スナップショットを記録し、末尾で
# (終了時 - 開始時)が空であることを確認する。fixture は必ず $ROOT/test 配下(このワークツリーの
# gitignore されない場所)へパステンプレート付き mktemp -d で作る(cwd 非依存・no-litter ブロックを
# 踏まない・片付け忘れがこの検知に拾われる)。
_initial_status="$(cd "$ROOT" && git status --porcelain 2>/dev/null)"

ok() { pass=$((pass+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng() { fail=$((fail+1)); printf '  \033[31m✗\033[0m %s\n' "$1"; _failures+=("$1"); }
file_is()   { if [ -e "$2" ]; then ok "$1"; else ng "$1 (missing path: $2)"; fi; }
file_isnt() { if [ ! -e "$2" ]; then ok "$1"; else ng "$1 (unexpected path exists: $2)"; fi; }
out_has()   { case "$3" in *"$2"*) ok "$1";; *) ng "$1 (missing: $2)";; esac; }
out_hasnt() { case "$3" in *"$2"*) ng "$1 (unexpected: $2)";; *) ok "$1";; esac; }
str_eq()    { if [ "$2" = "$3" ]; then ok "$1"; else ng "$1 (expected [$3], got [$2])"; fi; }
str_ne()    { if [ "$2" != "$3" ]; then ok "$1"; else ng "$1 (unexpected equal: [$2] = [$3])"; fi; }

_scratch_target() { mktemp -d "$ROOT/test/scratch.target.XXXXXXXX"; }

echo "== .gitignore: 隔離用の作業ツリー(.claude/worktrees/配下)が一括ステージでコミットされないこと =="
# 仕込み確認: 対象の記法(.claude/ 配下を無視するパターンと、knowledge/ を復活させる例外)が
# このリポジトリの .gitignore に実在すること。
_gi_pattern_count="$(grep -cxF '/.claude/*' "$ROOT/.gitignore")"
str_eq "(仕込み確認) .gitignore に /.claude/* を無視する行が1つだけ実在する" "$_gi_pattern_count" "1"
_gi_exception_count="$(grep -cxF '!/.claude/knowledge/' "$ROOT/.gitignore")"
str_eq "(仕込み確認) .gitignore に !/.claude/knowledge/ の例外行が1つだけ実在する" "$_gi_exception_count" "1"
T_GI="$(_scratch_target)"
(cd "$T_GI" && git init -q)
cp "$ROOT/.gitignore" "$T_GI/.gitignore"
mkdir -p "$T_GI/leader-harness"
printf 'x\n' > "$T_GI/leader-harness/adjudication-capture.md"
# 実際の隔離手段(git worktree add で作る linked worktree)の目印である「.git がディレクトリではなく
# ファイル」という形を再現する(通常の git clone とは違い、embedded git repository として git に
# 検知されうる特殊な形なので、素朴なディレクトリではなくこの形で無視の効き方を確かめる)。
mkdir -p "$T_GI/.claude/worktrees/agent-example/leader-harness"
printf 'gitdir: /somewhere/.git/worktrees/agent-example\n' > "$T_GI/.claude/worktrees/agent-example/.git"
printf 'isolated copy of repo content\n' > "$T_GI/.claude/worktrees/agent-example/leader-harness/adjudication-capture.md"
# 実際の knowledge capture(dispatch された実装者がこのリポジトリ自身の .claude/knowledge/ へ
# 書いたと想定)を再現する(一次レビュー対応: .claude/ を丸ごと無視すると knowledge が
# 黙って失われる)。
mkdir -p "$T_GI/.claude/knowledge/leader-harness"
printf '# 学び\n' > "$T_GI/.claude/knowledge/leader-harness/example.md"
_status_gi="$(cd "$T_GI" && git status --porcelain --untracked-files=all 2>&1)"
out_hasnt "受け入れ条件1: 隔離用の作業ツリー(.claude/worktrees/配下)が git status に現れない" ".claude/worktrees" "$_status_gi"
# positive control: git status の出力自体は生きている(所有物のファイルは untracked として出る)。
out_has "(positive control) 無関係なファイルは untracked として出る(git status の出力自体は生きている)" "leader-harness/adjudication-capture.md" "$_status_gi"
_check_ignore_gi="$(cd "$T_GI" && git check-ignore -v .claude/worktrees/agent-example 2>&1)"
out_has "無視の出どころがこのリポジトリの .gitignore 自身である(判定の出どころを確認できる)" ".gitignore:" "$_check_ignore_gi"
out_has "(一次レビュー対応) .claude/knowledge/ 配下は無視されず git status に現れる(capture した知見を黙って失わない)" \
  ".claude/knowledge/leader-harness/example.md" "$_status_gi"

echo "== .gitignore 陽性対照: 無視の設定を外すと現れること(無視が実際に効いていたことの確認) =="
rm "$T_GI/.gitignore"
_status_gi_noignore="$(cd "$T_GI" && git status --porcelain --untracked-files=all 2>&1)"
out_has "(陽性対照) .gitignore を外すと .claude/worktrees 配下が untracked として現れる" ".claude/worktrees/agent-example" "$_status_gi_noignore"

echo "== .gitignore(一次レビュー対応) 陽性対照: knowledge/ の例外だけを外すと knowledge も無視されること =="
# .gitignore 全体ではなく、例外行(!/.claude/knowledge/)だけを外した版を用意する。worktree の隔離は
# 引き続き効いたまま、knowledge だけが無視されるようになることを確認する(例外行が実際に効いていた
# ことの確認。曖昧に「.gitignore を外したら両方消えた」だけでは、この例外行そのものが効いているのか
# を区別できない)。
cp "$ROOT/.gitignore" "$T_GI/.gitignore"
grep -vxF '!/.claude/knowledge/' "$T_GI/.gitignore" > "$T_GI/.gitignore.noexc"
mv "$T_GI/.gitignore.noexc" "$T_GI/.gitignore"
_status_gi_noexc="$(cd "$T_GI" && git status --porcelain --untracked-files=all 2>&1)"
out_hasnt "(陽性対照) 例外行を外すと .claude/knowledge/ 配下が untracked として現れなくなる(無視されるようになる)" \
  ".claude/knowledge/leader-harness/example.md" "$_status_gi_noexc"
out_hasnt "(陽性対照と対になる確認) 例外行だけを外しても worktree の隔離は引き続き効いている(巻き添えでない)" \
  ".claude/worktrees" "$_status_gi_noexc"
rm -rf "$T_GI"


echo "== 規律・スキルがハーネス本体のファイルをパスで読んでいないこと =="
# 対象: プラグイン本体 leader-harness/ 配下の *.md（規律と leader-loop スキル）
_lh_targets=()   # mapfile は macOS の bash 3.2 に無いので while read で受ける
while IFS= read -r _f; do _lh_targets+=("$_f"); done < <(cd "$ROOT" && git ls-files -- 'leader-harness/*.md')
# 下限: 規律8本 + leader-loop（スキルを leader-harness/ 配下へ移した後も同じ9件のうち8を下限にする）。件数の増減で更新が要らないよう下限にとどめる
_lh_min=8
_lh_n_ok="no"; [ "${#_lh_targets[@]}" -ge "$_lh_min" ] && _lh_n_ok="yes"
str_eq "検査の対象が${_lh_min}件以上ある(移動の取りこぼしで対象が減れば赤になる)" "$_lh_n_ok" "yes"
_re_path='\.claude/(rules/harness|skills|agents|hooks|lib)/'
# バッククォートの有無を問わず拾う。直前が英数字・':'・'_'・'-' のものは除く(名前空間つき yosage-dev-harness:architect を拾わない)
_re_agent='(^|[^A-Za-z0-9:_-])(architect|explorer|researcher|implementer|librarian|code-reviewer|consistency-reviewer|best-practice-reviewer|doc-writer|test-writer)([^A-Za-z0-9_-]|$)'
# 対象が0件のときは以降を飛ばす(空配列の展開は bash 3.2 + set -u で unbound、grep はファイル引数なしで stdin を読む)
if [ "${#_lh_targets[@]}" -gt 0 ]; then
  _path_refs="$(cd "$ROOT" && grep -nE "$_re_path" -- "${_lh_targets[@]}" || true)"
  str_eq "ハーネス本体のファイルへのパス参照が0件" "$_path_refs" ""
  _agent_refs="$(cd "$ROOT" && grep -nE "$_re_agent" -- "${_lh_targets[@]}" || true)"
  str_eq "名前空間の無いエージェント名が0件" "$_agent_refs" ""
fi
# 陽性対照: 同じ正規表現が検出できることを、fixture で確かめる
_pc_dir="$(mktemp -d "$ROOT/test/scratch.XXXXXXXX")"
printf '`.claude/rules/harness/pr-loop.md` を読む\n`architect` を起動する\nresearcher に調べさせる\nyosage-dev-harness:librarian は対象外\n' > "$_pc_dir/x.md"
out_has "陽性対照: パス参照を検出できる" "pr-loop.md" "$(grep -nE "$_re_path" "$_pc_dir/x.md" || true)"
_pc_agent="$(grep -nE "$_re_agent" "$_pc_dir/x.md" || true)"
out_has "陽性対照: バッククォートで囲んだ名前空間の無いエージェント名を検出できる" "architect" "$_pc_agent"
out_has "陽性対照: 囲まない名前空間の無いエージェント名を検出できる" "researcher" "$_pc_agent"
out_hasnt "陽性対照: 名前空間つきの名前は検出しない" "librarian" "$_pc_agent"
rm -rf "$_pc_dir"

# ---------------------------------------------------------------------------
# プラグインの骨格(marketplace.json・plugin.json・leader-loop スキル)を、claude を起動せずに静的に検査する。
# 判定ロジックは関数にし、壊した一時コピーで赤になること(陽性対照)を同じ実行の中で取る。
_check_skeleton() {  # <リポジトリルート相当のディレクトリ>
  python3 - "$1" <<'PY'
import json, os, re, sys
root = sys.argv[1]
def emit(ok, key, detail=""):
    print(("OK:" if ok else "FAIL:") + key + ":" + str(detail))
try:
    m = json.load(open(os.path.join(root, ".claude-plugin/marketplace.json")))
    p = json.load(open(os.path.join(root, "leader-harness/.claude-plugin/plugin.json")))
except Exception as e:
    print("FAIL:parse:" + str(e)); sys.exit(0)
emit(m.get("name") in ("yosage-dev-leader-harness-dev", "yosage-dev-leader-harness"), "mkt_name", m.get("name"))
desc = m.get("description") or ""
emit("開発用" not in desc and not re.search(r"-dev([^0-9A-Za-z-]|$)", desc), "mkt_desc_neutral", desc)
owner = (m.get("owner") or {}).get("name")
emit(owner == "yosage-project", "owner_name", owner)
pl = m.get("plugins")
emit(isinstance(pl, list) and len(pl) == 1, "plugins_count", len(pl) if isinstance(pl, list) else pl)
p0 = pl[0] if isinstance(pl, list) and pl else {}
emit(p0.get("name") == "yosage-dev-leader-harness", "plugins0_name", p0.get("name"))
emit(p0.get("source") == "./leader-harness", "plugins0_source", p0.get("source"))
emit("version" not in p0, "plugins0_no_version", "")
emit(os.path.isfile(os.path.join(root, "leader-harness/.claude-plugin/plugin.json")), "source_has_plugin_json", "")
emit(p.get("name") == "yosage-dev-leader-harness" and p.get("name") == p0.get("name"), "plugin_name", p.get("name"))
emit(bool(re.match(r"^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$", str(p.get("version")))), "plugin_version_semver", p.get("version"))
author = (p.get("author") or {}).get("name")
emit(author == owner and bool(author), "author_name", author)
sk = os.path.join(root, "leader-harness/skills/leader-loop/SKILL.md")
nm = None
if os.path.isfile(sk):
    txt = open(sk).read().split("\n")
    if txt and txt[0] == "---":
        for line in txt[1:]:
            if line == "---": break
            mm = re.match(r"^name:\s*(\S+)\s*$", line)
            if mm: nm = mm.group(1)
emit(nm == "leader-loop", "skill_name", nm)
PY
}
# 壊した一時コピーを作る(m=marketplace.json, p=plugin.json を python の文で書き換える)
_skeleton_variant() {  # <python statements>
  local d; d="$(mktemp -d "$ROOT/test/scratch.XXXXXXXX")"
  mkdir -p "$d/.claude-plugin" "$d/leader-harness/.claude-plugin" "$d/leader-harness/skills/leader-loop"
  cp "$ROOT/leader-harness/skills/leader-loop/SKILL.md" "$d/leader-harness/skills/leader-loop/SKILL.md"
  python3 - "$ROOT" "$d" "$1" <<'PY'
import json, sys
root, d, code = sys.argv[1:4]
m = json.load(open(root + "/.claude-plugin/marketplace.json"))
p = json.load(open(root + "/leader-harness/.claude-plugin/plugin.json"))
exec(code)
json.dump(m, open(d + "/.claude-plugin/marketplace.json", "w"), ensure_ascii=False)
json.dump(p, open(d + "/leader-harness/.claude-plugin/plugin.json", "w"), ensure_ascii=False)
PY
  printf '%s' "$d"
}
_skel_neg() {  # <説明> <期待する出力> <python statements>
  local v; v="$(_skeleton_variant "$3")"
  out_has "$1" "$2" "$(_check_skeleton "$v")"
  rm -rf "$v"
}

echo "== プラグイン骨格: marketplace.json / plugin.json / leader-loop の形 =="
_sk="$(_check_skeleton "$ROOT")"
out_hasnt "marketplace.json/plugin.json は JSON として読め、全項目が正しい(FAIL 行が無い)" "FAIL:" "$_sk"
out_has "marketplace.json: name は開発用かリリース用のどちらか" "OK:mkt_name:" "$_sk"
out_has "marketplace.json: description は中立(語『開発用』・開発用マーケットプレイス名を含まない)" "OK:mkt_desc_neutral:" "$_sk"
out_has "marketplace.json: owner.name は yosage-project" "OK:owner_name:yosage-project" "$_sk"
out_has "marketplace.json: plugins はちょうど1項目" "OK:plugins_count:1" "$_sk"
out_has "marketplace.json: plugins[0].name は yosage-dev-leader-harness" "OK:plugins0_name:yosage-dev-leader-harness" "$_sk"
out_has "marketplace.json: plugins[0].source は ./leader-harness" "OK:plugins0_source:./leader-harness" "$_sk"
out_has "marketplace.json: plugins[0] に version を書かない(版の正本は plugin.json)" "OK:plugins0_no_version:" "$_sk"
out_has "source の先に .claude-plugin/plugin.json がある" "OK:source_has_plugin_json:" "$_sk"
out_has "plugin.json: name が marketplace.json の plugins[0].name と一致する" "OK:plugin_name:yosage-dev-leader-harness" "$_sk"
out_has "plugin.json: version は semver の形" "OK:plugin_version_semver:" "$_sk"
out_has "plugin.json: author.name が marketplace.json の owner.name と一致する" "OK:author_name:" "$_sk"
out_has "leader-loop/SKILL.md が実在し frontmatter の name が leader-loop" "OK:skill_name:leader-loop" "$_sk"
file_isnt "VERSION ファイルを持たない(版の正本は plugin.json)" "$ROOT/VERSION"
file_isnt "manifest.json を持たない" "$ROOT/manifest.json"
file_isnt "bin/ を持たない" "$ROOT/bin"
file_isnt "skills/ を直下に持たない(プラグイン本体 leader-harness/skills/ へ移した)" "$ROOT/skills"

echo "== プラグイン骨格 陽性対照: 壊した一時コピーで赤になり、リリース用の名前では緑のままであること =="
_skel_neg "リリース用の名前(yosage-dev-leader-harness)でも name の判定は通る" "OK:mkt_name:yosage-dev-leader-harness" 'm["name"]="yosage-dev-leader-harness"'
_skel_neg "陽性対照: name を3つ目の値にすると赤" "FAIL:mkt_name:yosage-dev-leader-harness-other" 'm["name"]="yosage-dev-leader-harness-other"'
_skel_neg "陽性対照: description に『開発用』と開発用名を入れると赤" "FAIL:mkt_desc_neutral:" 'm["description"]="開発用マーケットプレイス(yosage-dev-leader-harness-dev)"'
_skel_neg "陽性対照: 『開発用』の語が無くても開発用名が現れれば赤" "FAIL:mkt_desc_neutral:" 'm["description"]="配布用 yosage-dev-leader-harness-dev マーケットプレイス"'
_skel_neg "陽性対照: 製品名 yosage-dev-leader-harness だけの description は緑" "OK:mkt_desc_neutral:" 'm["description"]="yosage-dev-leader-harness を配る"'
_skel_neg "陽性対照: plugins[0] に version を足すと赤" "FAIL:plugins0_no_version:" 'm["plugins"][0]["version"]="0.1.0"'
_skel_neg "陽性対照: plugins を2項目にすると赤" "FAIL:plugins_count:2" 'm["plugins"].append(dict(m["plugins"][0]))'
_skel_neg "陽性対照: version が semver でないと赤" "FAIL:plugin_version_semver:1.0" 'p["version"]="1.0"'
_skel_neg "陽性対照: author.name を owner.name と食い違わせると赤" "FAIL:author_name:someone-else" 'p["author"]={"name":"someone-else"}'
_skel_neg "陽性対照: owner.name が違うと赤" "FAIL:owner_name:other" 'm["owner"]={"name":"other"}'
_skel_neg "陽性対照: source が違うと赤" "FAIL:plugins0_source:./harness" 'm["plugins"][0]["source"]="./harness"'
_v="$(_skeleton_variant 'pass')"
sed -i.bak 's/^name: leader-loop/name: other/' "$_v/leader-harness/skills/leader-loop/SKILL.md"
out_has "陽性対照: SKILL.md の name が違うと赤" "FAIL:skill_name:other" "$(_check_skeleton "$_v")"
rm -rf "$_v"

# ---------------------------------------------------------------------------
echo ""
echo "== フック: hooks.json の形（SessionStart だけ・matcher なし・args の実体が実在） =="
_check_hooks_json() {  # <プラグインのルート相当ディレクトリ>
  python3 - "$1" <<'PY'
import json, os, sys
root = sys.argv[1]
def emit(ok, key, detail=""):
    print(("OK:" if ok else "FAIL:") + key + ":" + str(detail))
try:
    h = json.load(open(os.path.join(root, "hooks/hooks.json")))["hooks"]
except Exception as e:
    print("FAIL:parse:" + str(e)); sys.exit(0)
emit(list(h.keys()) == ["SessionStart"], "only_session_start", list(h.keys()))
groups = h.get("SessionStart", [])
emit(all("matcher" not in g for g in groups) and len(groups) > 0, "no_matcher", "")
missing = []
for g in groups:
    for c in g.get("hooks", []):
        for a in c.get("args", []):
            p = a.replace("${CLAUDE_PLUGIN_ROOT}", root)
            if not os.path.isfile(p): missing.append(a)
emit(not missing, "args_exist", missing)
PY
}
_hk="$(_check_hooks_json "$ROOT/leader-harness")"
out_has "hooks.json は SessionStart だけを持つ" "OK:only_session_start" "$_hk"
out_has "hooks.json は matcher を持たない" "OK:no_matcher" "$_hk"
out_has "hooks.json の args の実体が実在する" "OK:args_exist" "$_hk"
out_hasnt "hooks.json の検査に FAIL が無い" "FAIL:" "$_hk"
_hkd="$(mktemp -d "$ROOT/test/scratch.XXXXXXXX")"
mkdir -p "$_hkd/hooks"
printf '%s' '{"hooks":{"SessionStart":[{"matcher":"startup","hooks":[{"type":"command","command":"bash","args":["${CLAUDE_PLUGIN_ROOT}/hooks/none.sh"]}]}],"SubagentStart":[]}}' > "$_hkd/hooks/hooks.json"
_hkn="$(_check_hooks_json "$_hkd")"
out_has "陽性対照: SessionStart 以外のイベントがあると赤" "FAIL:only_session_start" "$_hkn"
out_has "陽性対照: matcher があると赤" "FAIL:no_matcher" "$_hkn"
out_has "陽性対照: args の実体が無いと赤" "FAIL:args_exist" "$_hkn"
rm -rf "$_hkd"

echo "== フック: 注入の出力（前置き・スキル名の双方向照合・命令形の混入・長さ） =="
_inj_out="$(bash "$ROOT/leader-harness/hooks/inject-entry.sh" </dev/null 2>/dev/null)"; _inj_rc=$?
str_eq "inject-entry.sh は exit 0" "$_inj_rc" "0"
str_eq "1行目が前置き（yosage-dev-leader-harness の取り決めです を含む）" \
  "$(printf '%s\n' "$_inj_out" | head -n1 | grep -c 'yosage-dev-leader-harness の取り決めです')" "1"
_skill_names="$(cd "$ROOT/leader-harness/skills" && ls)"
str_eq "(仕込み確認) スキルが8本ある" "$(printf '%s\n' "$_skill_names" | wc -l | tr -d ' ')" "8"
for _sn in $_skill_names; do
  out_has "入口がスキル yosage-dev-leader-harness:$_sn を挙げている" "yosage-dev-leader-harness:$_sn" "$_inj_out"
done
_mentioned="$(printf '%s\n' "$_inj_out" | grep -o 'yosage-dev-leader-harness:[a-z-]*' | sort -u | sed 's/^yosage-dev-leader-harness://')"
_dangling=""
for _m in $_mentioned; do [ -f "$ROOT/leader-harness/skills/$_m/SKILL.md" ] || _dangling="$_dangling $_m"; done
str_eq "入口が挙げる yosage-dev-leader-harness:<名前> がすべて実在するスキルを指す" "$_dangling" ""
_imp_words=("してください" "せよ")
for _w in "${_imp_words[@]}"; do out_hasnt "注入文に命令形（$_w）が無い" "$_w" "$_inj_out"; done
_inj_len="$(printf '%s' "$_inj_out" | python3 -c 'import sys; print(len(sys.stdin.read()))')"
_inj_short="no"; [ "$_inj_len" -lt 9000 ] && _inj_short="yes"
str_eq "注入文が9,000字未満（実測 ${_inj_len}字）" "$_inj_short" "yes"
# 陽性対照: 検査の判定が効くこと（スキルの書き忘れ・存在しない名前・命令形の混入を検出できる）
_pc_out="$_inj_out"$'\n'"確認してください yosage-dev-leader-harness:ghost"
out_has "陽性対照: 命令形の語を検出できる" "してください" "$_pc_out"
_pc_m="$(printf '%s\n' "$_pc_out" | grep -o 'yosage-dev-leader-harness:[a-z-]*' | sort -u | sed 's/^yosage-dev-leader-harness://')"
out_has "陽性対照: 存在しない名前を挙げていれば拾える" "ghost" "$_pc_m"
_pc_d=""
for _m in $_pc_m; do [ -f "$ROOT/leader-harness/skills/$_m/SKILL.md" ] || _pc_d="$_pc_d $_m"; done
out_has "陽性対照: 実在しない名前が dangling として出る" "ghost" "$_pc_d"
_pc_w="$(printf '%s\n' "$_inj_out" | grep -v 'yosage-dev-leader-harness:work-sequencing')"
out_hasnt "陽性対照: 入口から1行消すとスキル名が消える（書き忘れの検知が働く）" "yosage-dev-leader-harness:work-sequencing" "$_pc_w"

echo "== フック: 失敗の見え方（原本が無い・空 → 標準出力なし・標準エラー1行目・exit 1） =="
_hd="$(mktemp -d "$ROOT/test/scratch.XXXXXXXX")"
cp "$ROOT/leader-harness/hooks/inject-entry.sh" "$_hd/inject-entry.sh"
_f_stdout="$(bash "$_hd/inject-entry.sh" </dev/null 2>"$_hd/err")"; _f_rc=$?
str_eq "原本が無い: exit 1" "$_f_rc" "1"
str_eq "原本が無い: 標準出力が空" "$_f_stdout" ""
case "$(head -n1 "$_hd/err")" in "yosage-dev-leader-harness:"*) ok "原本が無い: 標準エラー1行目が yosage-dev-leader-harness: で始まる";; *) ng "原本が無い: 標準エラー1行目の形";; esac
: > "$_hd/entry.md"
_f_stdout="$(bash "$_hd/inject-entry.sh" </dev/null 2>"$_hd/err")"; _f_rc=$?
str_eq "原本が空: exit 1" "$_f_rc" "1"
str_eq "原本が空: 標準出力が空" "$_f_stdout" ""
case "$(head -n1 "$_hd/err")" in "yosage-dev-leader-harness:"*) ok "原本が空: 標準エラー1行目が yosage-dev-leader-harness: で始まる";; *) ng "原本が空: 標準エラー1行目の形";; esac
printf '# x\n' > "$_hd/entry.md"
_f_stdout="$(bash "$_hd/inject-entry.sh" </dev/null 2>/dev/null)"; _f_rc=$?
str_eq "陽性対照: 原本があれば exit 0" "$_f_rc" "0"
out_has "陽性対照: 原本があれば本文が出る" "# x" "$_f_stdout"
rm -rf "$_hd"

echo "== スキル: frontmatter・長さ・移動の取りこぼし =="
_check_skills() {  # <プラグインのルート相当ディレクトリ>
  python3 - "$1" <<'PY'
import os, re, sys
root = sys.argv[1]
def emit(ok, key, detail=""):
    print(("OK:" if ok else "FAIL:") + key + ":" + str(detail))
sd = os.path.join(root, "skills")
names = sorted(os.listdir(sd))
total = 0
for n in names:
    p = os.path.join(sd, n, "SKILL.md")
    txt = open(p, encoding="utf-8").read()
    lines = txt.split("\n")
    fm = {}
    if lines[0] == "---":
        for l in lines[1:]:
            if l == "---": break
            m = re.match(r"^([A-Za-z-]+):\s*(.*)$", l)
            if m: fm[m.group(1)] = m.group(2)
    emit(fm.get("name") == n, "name:" + n, fm.get("name"))
    d = fm.get("description", "")
    total += len(d)
    emit(0 < len(d) <= 200, "desc_len:" + n, len(d))
    emit("リーダー" in d, "desc_leader:" + n, "")
    if n == "leader-loop":
        emit("user-invocable" not in fm, "user_invocable:" + n, fm.get("user-invocable"))
    else:
        emit(fm.get("user-invocable") == "false", "user_invocable:" + n, fm.get("user-invocable"))
    emit(len(lines) < 500, "lines:" + n, len(lines))
    emit(not re.search(r"\]\([a-z-]+\.md\)", txt), "no_relative_link:" + n, "")
    emit(not re.search(r"(?<![A-Za-z0-9-])(" + "|".join(map(re.escape, names + ["entry-point"])) + r")\.md", txt), "no_name_dot_md:" + n, "")
    emit(not re.search(r"\.claude/leader-harness/|\.claude/skills/leader-loop|(?<![A-Za-z0-9-])skills/leader-loop/SKILL\.md", txt), "no_old_path:" + n, "")
emit(total <= 1600, "desc_total", total)
stray = [f for f in os.listdir(root) if f.endswith(".md")]
emit(not stray, "no_stray_md", stray)
PY
}
_sk="$(_check_skills "$ROOT/leader-harness")"
out_hasnt "スキルの検査に FAIL が無い" "FAIL:" "$_sk"
out_has "(仕込み確認) 検査が8本ぶん走っている" "OK:desc_len:leader-loop" "$_sk"
out_has "規律7本は user-invocable: false、leader-loop は持たない" "OK:user_invocable:leader-loop" "$_sk"
out_has "leader-harness/ 直下に *.md が無い" "OK:no_stray_md" "$_sk"
out_has "8本の description 合計が1,600字以下" "OK:desc_total" "$_sk"
_skd="$(mktemp -d "$ROOT/test/scratch.XXXXXXXX")"
mkdir -p "$_skd/skills"
cp -R "$ROOT/leader-harness/skills/." "$_skd/skills/"
sed -i.bak 's/^name: authority$/name: other/' "$_skd/skills/authority/SKILL.md"
sed -i.bak 's/^user-invocable: false$/user-invocable: true/' "$_skd/skills/work-sequencing/SKILL.md"
sed -i.bak 's/^description: リーダー/description: 統制役/' "$_skd/skills/dispatch-instruction/SKILL.md"
printf '[権限](authority.md)\n' >> "$_skd/skills/merge-recommendation/SKILL.md"
printf '範囲は `authority.md` の対象範囲\n' >> "$_skd/skills/cross-repo-operations/SKILL.md"
printf '作法は cross-repo-operations.md が持つ\n' >> "$_skd/skills/dispatch-instruction/SKILL.md"
printf '入口は `entry-point.md` を辿る\n' >> "$_skd/skills/work-sequencing/SKILL.md"
printf '旧い置き場は `.claude/leader-harness/` にあった\n' >> "$_skd/skills/requirement-intake/SKILL.md"
printf '旧い置き場は .claude/skills/leader-loop にあった\n' >> "$_skd/skills/authority/SKILL.md"
printf 'x\n' > "$_skd/stray.md"
_skn="$(_check_skills "$_skd")"
out_has "陽性対照: name がディレクトリ名と違うと赤" "FAIL:name:authority" "$_skn"
out_has "陽性対照: 規律が user-invocable: false でないと赤" "FAIL:user_invocable:work-sequencing" "$_skn"
out_has "陽性対照: description に『リーダー』が無いと赤" "FAIL:desc_leader:dispatch-instruction" "$_skn"
out_has "陽性対照: 相対リンクが残ると赤" "FAIL:no_relative_link:merge-recommendation" "$_skn"
out_has "陽性対照: バッククォート内の <規律名>.md が残ると赤" "FAIL:no_name_dot_md:cross-repo-operations" "$_skn"
out_has "陽性対照: 地の文の <規律名>.md が残ると赤" "FAIL:no_name_dot_md:dispatch-instruction" "$_skn"
out_has "陽性対照: バッククォート内の entry-point.md が残ると赤" "FAIL:no_name_dot_md:work-sequencing" "$_skn"
out_has "陽性対照: 旧パス .claude/leader-harness/ が残ると赤" "FAIL:no_old_path:requirement-intake" "$_skn"
out_has "陽性対照: 旧パス .claude/skills/leader-loop が残ると赤" "FAIL:no_old_path:authority" "$_skn"
out_hasnt "対照: 旧パスを書いていないスキルは緑のまま" "FAIL:no_old_path:merge-recommendation" "$_skn"
out_has "陽性対照: 直下に *.md が残ると赤" "FAIL:no_stray_md" "$_skn"
python3 - "$_skd/skills/requirement-intake/SKILL.md" <<'PY'
import re, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
t = re.sub(r"^description: .*$", "description: リーダー" + "あ" * 250, t, flags=re.M)
open(p, "w", encoding="utf-8").write(t + "\n" * 500)
PY
_skn2="$(_check_skills "$_skd")"
out_has "陽性対照: description が200字を超えると赤" "FAIL:desc_len:requirement-intake" "$_skn2"
out_has "陽性対照: 本文が500行以上だと赤" "FAIL:lines:requirement-intake" "$_skn2"
rm -rf "$_skd"

echo "== 走査範囲: ハーネス本体をパスで読まない検査の対象に SKILL.md 8本と entry.md が入っている =="
_scan_list="$(cd "$ROOT" && git ls-files -- 'leader-harness/*.md')"
for _sn in $_skill_names; do
  out_has "走査対象に skills/$_sn/SKILL.md が含まれる" "leader-harness/skills/$_sn/SKILL.md" "$_scan_list"
done
out_has "走査対象に hooks/entry.md が含まれる" "leader-harness/hooks/entry.md" "$_scan_list"

echo "== 公開面: 追跡ファイルに issue/PR 番号の参照・非公開のリポジトリ名が無いこと =="
# ハーネス本体の公開面の決まり(番号参照の2つの形・非公開のリポジトリ名)と同じパターンを、全追跡ファイルの
# 全行に掛ける(コードスパンも除外しない・行のフィルタも持たない)。このテスト自身がパターンに
# 当たらないよう、値は分けて実行時に連結する(ソース上で # と数字を隣接させない)。
_H='#'
_re_nref1='(^|[^0-9A-Za-z_])'"$_H"'[0-9]+([^0-9A-Za-z_]|$)'
_re_nref2='[A-Za-z0-9_.-]+'"$_H"'[0-9]+'
_old_name='yosage-leader-'"harness"
_new_name='yosage-dev-leader-'"harness"
_id_scan() {  # <ルート> ; ファイル一覧(NUL 区切り)は標準入力。出力: 番号参照1・番号参照2・旧名の各ヒット
  local root="$1" list; list="$(mktemp "$ROOT/test/scratch.list.XXXXXXXX")"
  cat > "$list"
  (cd "$root" && { xargs -0 grep -nE "$_re_nref1" < "$list" 2>/dev/null || true; xargs -0 grep -nE "$_re_nref2" < "$list" 2>/dev/null || true; xargs -0 grep -niF "$_old_name" < "$list" 2>/dev/null || true; })
  rm -f "$list"
}
_id_files="$(cd "$ROOT" && git ls-files | wc -l | tr -d ' ')"
_id_nonzero="no"; [ "$_id_files" -ge 1 ] && _id_nonzero="yes"
str_eq "検査の対象の追跡ファイルが1件以上ある(空振りしない。実測 ${_id_files}件)" "$_id_nonzero" "yes"
_id_real="$(cd "$ROOT" && git ls-files -z | _id_scan "$ROOT")"
str_eq "追跡ファイルに番号だけの参照・word+番号の形・旧リポジトリ名が0件" "$_id_real" ""
# 陽性対照: 一時コピーに実行時に組み立てた値を足すと検出され、番号の無い例示は検出されない
_NUM="12"'3'
_idd="$(mktemp -d "$ROOT/test/scratch.XXXXXXXX")"
mkdir -p "$_idd/skills"
cp -R "$ROOT/leader-harness/skills/." "$_idd/skills/"
_idscan_dir() { (cd "$_idd" && find . -type f -print0) | _id_scan "$_idd"; }
str_eq "(対照の前提) 足す前の一時コピーは緑" "$(_idscan_dir)" ""
printf '経緯は %s%s を参照\n' "$_H" "$_NUM" >> "$_idd/skills/authority/SKILL.md"
out_has "陽性対照: 地の文に番号だけの参照を足すと検出される" "authority/SKILL.md" "$(_idscan_dir)"
cp "$ROOT/leader-harness/skills/authority/SKILL.md" "$_idd/skills/authority/SKILL.md"
printf '経緯は `%s%s` を参照\n' "$_H" "$_NUM" >> "$_idd/skills/authority/SKILL.md"
out_has "陽性対照: *.md のバッククォートの中に書いても検出される" "authority/SKILL.md" "$(_idscan_dir)"
cp "$ROOT/leader-harness/skills/authority/SKILL.md" "$_idd/skills/authority/SKILL.md"
printf '参照 owner/repo%s%s\n' "$_H" "$_NUM" >> "$_idd/skills/authority/SKILL.md"
out_has "陽性対照: word+番号の形(owner/repo と番号)も検出される" "authority/SKILL.md" "$(_idscan_dir)"
cp "$ROOT/leader-harness/skills/authority/SKILL.md" "$_idd/skills/authority/SKILL.md"
printf '新旧 %s と %s を同じ行に書く\n' "$_new_name" "$_old_name" >> "$_idd/skills/authority/SKILL.md"
out_has "陽性対照: 旧リポジトリ名は新しい名前と同じ行にあっても検出される" "authority/SKILL.md" "$(_idscan_dir)"
cp "$ROOT/leader-harness/skills/authority/SKILL.md" "$_idd/skills/authority/SKILL.md"
printf '新しい名前 %s だけの行\n' "$_new_name" >> "$_idd/skills/authority/SKILL.md"
str_eq "対照: 新しい名前だけの行は検出されない" "$(_idscan_dir)" ""
cp "$ROOT/leader-harness/skills/authority/SKILL.md" "$_idd/skills/authority/SKILL.md"
printf '例示は %s<番号> の形\n' "$_H" >> "$_idd/skills/authority/SKILL.md"
str_eq "対照: 番号の無い例示(#と<番号>)は検出されない" "$(_idscan_dir)" ""
rm -rf "$_idd"

# ---------------------------------------------------------------------------
echo ""
echo "結果: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  echo "== failures ($fail) =="
  for f in "${_failures[@]}"; do printf '  \033[31m✗\033[0m %s\n' "$f"; done
fi

_final_status="$(cd "$ROOT" && git status --porcelain 2>/dev/null)"
if [ "$_final_status" != "$_initial_status" ]; then
  fail=$((fail+1))
  echo "  ✗ 後始末漏れ: スイート実行前後で git status に差分がある(fixture の rm -rf 漏れの疑い)"
  diff <(printf '%s\n' "$_initial_status") <(printf '%s\n' "$_final_status") || true
fi

[ "$fail" -eq 0 ]
