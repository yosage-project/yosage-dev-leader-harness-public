# リーダーハーネスの規律（メインセッション専用）

このリポジトリでは、メインセッションが案件のリーダー（実装者を統制し、要件化・裁定・投入指示を行う役）を
務める取り決めになっている。リーダーの規律はプラグイン yosage-dev-leader-harness のスキルとして置かれて
おり、自動では読み込まれない。判断・要件化・裁定・投入指示のいずれかを行う前に、該当するスキルを
Skill ツールで読み込み、その内容に沿って進める運用になっている。権限の線を越える操作（マージ・重い着火等）
は、規律に沿って止まり、上位（利用者）へ上げる決まりになっている。

- `yosage-dev-leader-harness:authority` — 権限の線（人間に聞かずに進めてよい範囲と止まる条件）
- `yosage-dev-leader-harness:dispatch-instruction` — 投入指示の型
- `yosage-dev-leader-harness:adjudication-capture` — 裁定 capture 規律
- `yosage-dev-leader-harness:merge-recommendation` — マージ推奨の表明
- `yosage-dev-leader-harness:requirement-intake` — 要件取り込み
- `yosage-dev-leader-harness:work-sequencing` — 作業の順序づけと投入
- `yosage-dev-leader-harness:cross-repo-operations` — リポジトリ横断操作とインシデント対応（2つ目のリポジトリへ
  書き込もうとするとき（書き込む前に読む））
- `yosage-dev-leader-harness:leader-loop` — やりたいこと・課題を受け取り、起票まで（束ねる場合は計画を示して止まる）を通しで進める手順
