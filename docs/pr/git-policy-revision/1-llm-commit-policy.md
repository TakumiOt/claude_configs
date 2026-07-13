# git 運用方針の刷新 — メイン会話へのコミット許可とフックによる強制

## 背景・目的

- 従来は git の書き込み操作をすべてユーザー所有としており、タスクごとにコミット待ちの停止が発生してワークフローの摩擦になっていた。
- 本 PR で git 書き込み権限を「メイン会話 = コミットまで / ユーザー = プッシュ以降 / サブエージェント = 禁止」に三分割し、ユーザー確認ポイントを PR 集約時に一本化する。
- 新方針は運用文書 (`CLAUDE.md`・エージェント定義)、権限設定 (`settings.json`)、PreToolUse フック (`scripts/git-guard.sh`) の三層で強制する。

## スコープ

- メイン会話が `feature/*` ブランチ上で「ブランチ作成 → パス明示ステージング → コミット」を自ら実行でき、方針に反する git コマンドはフックが遮断する運用を、実際のセッションで実行できるようにした (本 PR のコミット `e6d2d45` 自体がこのフローの実行結果)。
- git 書き込み権限の三分割を規定する運用文書を全面改訂した (`CLAUDE.md` 「Git Operations」)。
- ユーザー確認ポイントを PR 集約時の引き継ぎ (`Aggregation hand-off`) に一本化した (Phase 2 / Phase 3 / Path B / Definition of Done)。
- 4 エージェント定義の git 記述を新方針に追随させた。
- 権限リストを allow / deny の二層に再構成し、AI 帰属表示を無効化した (`settings.json`)。
- プレフィックスマッチで表現できない迂回経路を遮断する PreToolUse フックを新設した (`scripts/git-guard.sh`)。

## 受け入れ基準

### CLAUDE.md の「Git Operations」を全面改訂し、git 書き込み権限を三分割した

- メイン会話のみが `feature/*` ブランチ上でコミットできる (1 完了タスク = 1 コミット、fix loop 完了後のみ)。
- 関心が異なる変更は同時に完成しても別コミットに分割する (1 コミット = 1 関心事)。
- プッシュ・PR 作成・マージ・履歴書き換えはユーザー所有。
- サブエージェントは状態変更系 git コマンドを一切実行しない。
- git flow を前提に `main` / `develop` を保護ブランチと明記。
- ステージングはパス明示指定のみ (`git add -A` / `.` / `commit -a` 禁止)。
- コミットメッセージは日本語 1 行要約で、AI 帰属表示 (`Co-Authored-By` 等) を付けない。

### ワークフローのユーザー確認ポイントを PR 集約時に一本化した

- Phase 2 のタスクごとの確認待ちを廃止し「commit & report」(コミット + 報告のみで次タスクへ進む) に変更。
- Phase 3 step 5 を「Aggregation hand-off」(ブランチ名・コミット一覧・diffstat を報告して停止し、プッシュ以降はユーザー) として新設。
- Path B step 4 と Definition of Done 項目 9 も同じ構造に更新。

### 4 つのエージェント定義の git 記述を新方針に更新した

- `agents/developer.md` / `pr-writer.md` / `pr-reviewer.md` / `code-reviewer.md` で、サブエージェントの git 禁止を維持したまま、理由の記述を「コミットはメイン会話、プッシュ以降はユーザー」に更新。

### settings.json の権限を allow / deny の二層に再構成し、帰属表示設定を無効化した

- `git add` / `git commit` / `git switch` / `git branch` (および `-C` 変種) を allow に移動。
- `git push` は deny (ユーザー自身が実行)。
- 履歴書き換え系・`checkout` / `restore` / `config` 等は deny のまま。
- `attribution` 設定 (`{"commit": "", "pr": ""}`) でコミット・PR への AI 帰属表示を無効化。
- PreToolUse フックに `git-guard.sh` を登録。

### `scripts/git-guard.sh` を新設し、プレフィックスマッチで表現できない迂回経路をフックで遮断した

- `--no-verify` (`commit -n` 含む) を `exit 2` で遮断する。
- `git -c` / `core.hooksPath` / `GIT_DIR` 系の設定上書きを遮断する。
- `--amend` / `--force` 系の履歴書き換えフラグを遮断する。
- 一括ステージングを遮断する。
- 保護ブランチ (`main` / `master` / `develop`) 上での commit / push と、保護ブランチへの refspec 指定プッシュを遮断する。
- リモート ref 削除と `branch -D` / `switch -f` 等の破壊的フラグを遮断する。

## 依存PR

- なし。

## 関連ドキュメント

- [`CLAUDE.md`](../../../CLAUDE.md) — git 運用方針の本文 (「Git Operations」とワークフロー各所)。
- [`settings.json`](../../../settings.json) — 権限リスト・帰属表示設定・フック登録。
- [`scripts/git-guard.sh`](../../../scripts/git-guard.sh) — 迂回経路を遮断する PreToolUse フック。
- git 記述を更新した 4 エージェント定義。
  - [`agents/developer.md`](../../../agents/developer.md)
  - [`agents/pr-writer.md`](../../../agents/pr-writer.md)
  - [`agents/pr-reviewer.md`](../../../agents/pr-reviewer.md)
  - [`agents/code-reviewer.md`](../../../agents/code-reviewer.md)

## 変更内容

git 書き込み権限を三分割し、新方針を文書・権限設定・フックの三層で強制するようにした。

### git 書き込み権限の三分割 (`CLAUDE.md` 「Git Operations」)

- 従来の「git 操作は全面ユーザー所有」を改め、書き込み権限を三者に分割した。
  - メイン会話: `feature/*` ブランチの作成・パス明示ステージング・コミット (1 完了タスク = 1 コミット)。
  - ユーザー: プッシュ・PR 作成・マージ・履歴書き換え。
  - サブエージェント: 状態変更系 git コマンドは従来どおり一切禁止。
- コミット粒度の規律として、関心が異なる変更は同時に完成しても別コミットに分割する方針を明記した (「1 タスク = 1 コミット」は上限であり、複数関心の同乗を許す免罪符ではない)。
- git flow を前提に `main` / `develop` を保護ブランチと明記し、直接のコミット・プッシュを禁止した。
- コミットメッセージは日本語 1 行要約とし、AI 帰属表示 (`Co-Authored-By` 等) を付けない方針を明文化した。

### ユーザー確認ポイントの一本化

- タスクごとの確認待ちを廃止し、コミットと報告のみで次タスクへ進む「commit & report」に変更した (Phase 2 step 4)。
- PR 集約の完了時に停止してユーザーへ引き継ぐ「Aggregation hand-off」を新設した (Phase 3 step 5、ブランチ名・コミット一覧・diffstat を報告)。
- 単一タスク向けの流れと完了条件も同じ構造に揃えた (Path B step 4、Definition of Done 項目 9)。

### エージェント定義の追随

- サブエージェントの git 禁止を維持したまま、禁止理由の記述を「コミットはメイン会話、プッシュ以降はユーザー」に更新した。
  - 対象: `agents/developer.md` / `agents/pr-writer.md` / `agents/pr-reviewer.md` / `agents/code-reviewer.md`。

### 権限設定と帰属表示の無効化 (`settings.json`)

- git 権限を allow / deny の二層に再構成した。
  - allow へ移動: `git add` / `git commit` / `git switch` / `git branch` とその `-C` 変種。
  - deny へ移動・維持: `git push` (ユーザー自身が実行)、履歴書き換え系、`checkout` / `restore` 等。
- `attribution` 設定でコミット・PR への AI 帰属表示を無効化した (非推奨の `includeCoAuthoredBy` は不使用)。
- PreToolUse フックに `git-guard.sh` を登録した。

### 迂回経路の遮断フック新設 (`scripts/git-guard.sh`)

- プレフィックスマッチで表現できない迂回経路を `exit 2` で遮断するフックを新設した。
  - フック迂回: `--no-verify` (`commit -n` 含む)、`git -c` / `core.hooksPath` / `GIT_DIR` 系の設定上書き。
  - 履歴書き換え: `--amend`、`--force` 系フラグ。
  - ステージング規律: `git add -A` / `--all` / `.` / `commit -a` の一括ステージング。
  - 保護ブランチ: `main` / `master` / `develop` 上での commit / push、保護ブランチへの refspec 指定プッシュ、リモート ref 削除。
  - 破壊的フラグ: `branch -D` / `switch -f` 等。

## 仕様からの変更点

このリポジトリに仕様書 (`docs/spec/`) はないため、受け入れ基準に挙げた変更一覧を基準に作成した (変更一覧からの乖離なし)。

## テスト

このリポジトリに自動テスト基盤はないため、検証はすべて手動またはスクリプト実行で行った。

| 種別 | テーマ | 主なケース |
|---|---|---|
| スクリプトバッテリ (手動実行) | `git-guard.sh` の遮断判定 | 遮断すべき 30 ケース / 許可すべき 17 ケースの計 47 ケースを実行し、全件期待どおりの判定を確認 |
| 静的検証 | `settings.json` の妥当性 | `jq empty` で JSON としてパースできることを確認 |
| 実運用試験 (手動 E2E) | 新フローでのコミット | `feature/git-policy-revision` ブランチ作成 → パス明示ステージング → コミット `e6d2d45` を実行 / `git log -1 --format=%B` で AI 帰属表示が付かないことを確認 |

- 遮断判定のテストスクリプトはセッションのスクラッチパッドに置いたもので、リポジトリには含まれない。

## 影響範囲・注意点

### 有効化タイミング

- `settings.json` の権限変更と `git-guard.sh` フックは次セッションから有効になる (フックは起動時に読み込まれる)。

### 本 PR 自体の逸脱事項

- このリポジトリは git flow 未採用 (`develop` なし) のため、今回のブランチは `main` 起点で作成した (規定からの逸脱として記録済み)。
- コミット `e6d2d45` には、セッション開始前から未コミットだった変更が同乗している (`CLAUDE.md` と 4 エージェント定義の一部)。
