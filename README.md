# yosage-dev-leader-harness — リーダーの運用規律（Claude Code プラグイン）

## 何か

リーダー（実装者を統制し、クライアント/PO とつながるメインセッション）の運用規律と、意図の受け取りから
起票まで（束ねる場合は計画を示して止まる）を通しで進める `leader-loop` スキルを、Claude Code のプラグインとして配る。単位は案件（単一
リポジトリ、またはワークスペース）。

- 入口（規律の存在と読み込み方の案内）は SessionStart フックで**メインセッションにだけ**入る。
  サブエージェントには入らない。
- 規律は規律ごとのスキルで、リーダーが判断の前に入口の案内に従って読み込む。

## このリポジトリについて

- **読み取り専用のミラー**です。開発は別の場所で行い、リリースごとにここへ反映しています。
  **issue と PR は受け付けていません**。
- **フィードバック・要望・動作についての報告・導入の相談**は、次のフォームへ。
  https://docs.google.com/forms/d/e/1FAIpQLSdNgSa2CdrNid2AjCtODmLN133zvqXOvbMMUbmJRuzRLCUszA/viewform
  - 報告に書いてほしいこと: 使っているバージョン（Claude Code で `/plugin` を開き、
    `yosage-dev-leader-harness` の詳細に出るバージョン）、何をしようとしたか（どう頼んだか）、何が起きたか。
  - 返信の目安（3営業日以内）は導入相談にだけ示します。報告や要望には、個別の返信や調査・修正を約束しません。
  - ログやエラーを貼るときは、秘密情報（トークン・パスワード等）や個人情報を伏せてください。
- **ライセンス**: MIT（[LICENSE](LICENSE)）。
- **運営・窓口**: Yosage Project株式会社。
- **お願い**: 権利侵害や他人に迷惑をかける使い方はしないでください（これはお願いであり、法的な拘束力はありません）。

## 前提

ハーネス本体のプラグイン `yosage-dev-harness` が同じ案件で有効であること。規律がハーネス本体のスキル・
エージェント・ルールを名前で参照する（この配布物はそれらを提供しない）。

リリース用リポジトリは非公開なので、利用者の手元に GitHub の git の資格情報が保存されている必要がある
（`gh auth login` の後に `gh auth setup-git` 等）。Claude Code はマーケットプレイスの取得・更新確認で
入力を求めず、保存済みの資格情報だけを使う。

## 導入

リリース版は、リリース用リポジトリ `yosage-project/yosage-dev-leader-harness-public` の
マーケットプレイス `yosage-dev-leader-harness` から入れる。

```bash
claude plugin marketplace add yosage-project/yosage-dev-leader-harness-public --scope project
claude plugin install yosage-dev-leader-harness@yosage-dev-leader-harness --scope project
```

ワークスペースならそのルートで、単一リポジトリならそのリポジトリで実行する。導入先に書かれるのは、
Claude Code 本体がプロジェクト単位の導入で `.claude/settings.json` に書く `enabledPlugins` と
`extraKnownMarketplaces` だけ。

更新は、プラグインの `version` を上げたときだけ届く。自動更新は既定で無効なので、利用者が `/plugin` の
Marketplaces で有効にするか、`/plugin marketplace update` を実行する。

**同じ名前のプラグインを、2つのマーケットプレイス（開発用 `yosage-dev-leader-harness-dev` と
リリース用 `yosage-dev-leader-harness`）から同時に有効にしない。** 入口が二重に入る。

## 使い方

リーダーに何を渡すと、何がどう進み、人はどこで判断するか、という使い方の流れは [`docs/`](docs/README.md) に
あります。ハーネス本体の使い方（本体の `docs/`）を読んでいることを前提に、拡張を足したときの差分として
書いています。

- [はじめての1件](docs/getting-started.md)
- [権限の線](docs/authority.md)
- [裁定と前例](docs/adjudication.md)
- [複数のリポジトリにまたがる案件](docs/cross-repo.md)
- [よくある詰まり](docs/troubleshooting.md)

## 旧版（CLI で入れた導入先）からの移行

旧版は CLI で規律のコピーを導入先の `.claude/` に書いていた。プラグイン版では導入先に何も写さないので、
旧いファイルを消してからプラグインを有効にする。順序は次のとおり（旧いフックと新しい注入が同時に動くと
入口が二重に入るので、順序を入れ替えない）。

1. ハーネス本体を新しいプラグイン（`yosage-dev-harness`）へ移す。
2. 旧ハーネス本体の、リーダーの入口を注入するフックが無くなったことを確かめる。
3. 旧コピー（`.claude/leader-harness/`）に書き込んだ案件側の現場適応があれば、案件のリポジトリの
   ルール（`.claude/rules/` 等）へ移す。見分け方は、旧版のリリースの中身と旧コピーの差分を取る。
4. 旧いリーダーハーネスのファイルを消す:
   `.claude/leader-harness/`・`.claude/skills/leader-loop/`、および旧 CLI が `.claude/` 直下に作った、
   `-baseline` で終わる隠しディレクトリ（中の隔離場所 `retired/` に中身があれば、先に確かめる）。
5. リーダーのプラグインを有効にする（上の「導入」）。
6. 新しいセッションで、入口が1回だけ入ることを確かめる。

## 収録

規律スキル（呼び名は `yosage-dev-leader-harness:<名前>`）:

| スキル | 目的 |
|---|---|
| `adjudication-capture` | 人間裁定の前例プール化＝AI 裁定範囲を漸進拡大する移行装置 |
| `requirement-intake` | 発話を受け入れ条件つき要件へ変換＝評価フラクタル・マージ委譲の前提づくり |
| `work-sequencing` | 複数 issue をウェーブに分けて投入する計画・順序づけ・統合 |
| `dispatch-instruction` | 作業部隊へ渡す投入指示に毎回含める項目と、検証が空振りしていないかの確かめ方 |
| `merge-recommendation` | 受け入れ可否の表明（実行はしない） |
| `cross-repo-operations` | リーダーが複数リポジトリを1セッションで操作するときの事故防止作法とインシデント対応 |
| `authority` | 人間に聞かずにやってよい範囲（行為 × 対象範囲）の宣言と、止まる条件 |

通しの手順のスキル:

| スキル | 目的 |
|---|---|
| `leader-loop` | 意図を受け取ってから起票まで（束ねる場合は計画を示して止まる）を通しで駆動する手順（規律は名前参照のみ） |

規律スキルは `/` のメニューに出さない。入口の案内に従って、リーダーが判断の前に読み込む。

## 案件ごとの適応

導入先に規律のコピーは無いので、案件固有の適応は、案件のリポジトリのルール（`.claude/rules/` 等）に書く。
一般化する価値のある変更は、利用者に報告を提案する（利用者が明示して指示したときだけ配布元へ起票する。導入先の利用者は、配布元が用意する報告の窓口へ）。

## 開発

- **ドッグフード**: 開発用リポジトリの develop 専用の作業ツリーを、ディレクトリ型のマーケットプレイス
  `yosage-dev-leader-harness-dev` として登録する（ローカル単位の設定 `settings.local.json` に登録する。
  絶対パスを追跡物に書かない）。ローカルのディレクトリから追加したマーケットプレイスは元のディレクトリを
  直接読むので、版を据え置いても、次のセッション開始時か `/reload-plugins` で変更が反映される。
- **テスト**: `bash test/run.sh`。
- **版**: `leader-harness/.claude-plugin/plugin.json` の `version`。develop に入る個々の変更では触らない。
  変更がたまったら、版を上げる専用の PR を出す。その PR のマージで、開発版を導入先へ配る。
- **リリース**: 版は上げない。開発版を導入先へ配るときに上げた `version` を、そのまま公開版の版にする。
  前提として、前回のリリースから版が上がっていること（同じ版ではタグ `v<版>` を作れない）。上がっていなければ、
  先に版を上げる専用の PR を出す。
  1. develop から main への PR を出し、人がマージする（マージコミット。squash しない）。
  2. main のマージコミットに、注釈つきタグ `v<版>`（`<版>` は `plugin.json` の `version`）を付けて push する。
  3. 公開スクリプトで公開用リポジトリ `yosage-project/yosage-dev-leader-harness-public` へ反映する。
     公開用リポジトリには 1 リリース 1 コミットで積み、マーケットプレイス名を `yosage-dev-leader-harness` に
     書き換える。公開スクリプトはこのリポジトリには含まれない。
- **公開面の決まり**: 追跡ファイルに issue/PR の番号・非公開のリポジトリ名を書かない。経緯はコミット
  メッセージ・PR 本文に残す（テストと公開スクリプトの検査が止める）。

## 知識は置かない

知識（knowledge）はこのリポジトリに置かない。一般に成立するリーダー運用の知見はグローバル知識ストアへ、
案件固有の経験は案件側に残す。
