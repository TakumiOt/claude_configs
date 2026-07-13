# git-policy-revision

git 書き込み権限を「メイン会話 = コミットまで / ユーザー = プッシュ以降 / サブエージェント = 禁止」に三分割し、文書・権限設定・フックの三層で強制する feature。

## 目次

1. [`1-llm-commit-policy.md`](1-llm-commit-policy.md) — `CLAUDE.md` の git 方針全面改訂、ユーザー確認ポイントの PR 集約時への一本化、4 エージェント定義の追随、`settings.json` の allow / deny 再構成と帰属表示無効化、迂回遮断フック `git-guard.sh` の新設。
