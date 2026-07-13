# PR ドキュメント

## 目的・責務

- 開発の集約 (aggregation) ごとに作成する PR 文書を feature 単位で収録する。
- 各 PR 文書はレビュー担当者向けに、変更の背景・スコープ・受け入れ基準・検証方法を一つのファイルにまとめる。

## 収録方針

- feature ごとにサブディレクトリを作り、その中に PR 文書を置く。
- ファイル名は `N-<aggregation>.md` (`N` は feature 内の PR 連番、`<aggregation>` はその PR が届けるものの kebab-case 記述子)。
- PR 文書は集約時に `pr-writer` が作成する。
- 各 feature ディレクトリは `README.md` を持ち、収録 PR を連番順に列挙する。
- この README はナビゲーションであり、PR 本文のセクション内容をここに書かない。

## 目次

- [`git-policy-revision/`](git-policy-revision/README.md) — git 運用方針の刷新 (メイン会話へのコミット許可とフックによる強制)。
