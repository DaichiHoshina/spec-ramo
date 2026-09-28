---
description: 機能ごとに Phase の進み具合 (未着手 / 実装中 / レビュー済み / PR 作成済み) を表示する。レビュー済みの Phase は GitHub の PR の有無を確かめて状態を更新する。「specramo の進み具合」「status 見せて」で使う。
disable-model-invocation: true
---

# /specramo:status - Phase の進み具合を表示する

> **Goal**: 利用者が、機能ごとにどの Phase まで進んだかと、この後に実行するコマンドを 1 画面で把握できる状態にする。

## Step 0: 前提確認

次の command を実行する。終了コードが 2 なら、表示をそのまま利用者に示して止まる。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/require-config.sh"
```

## Step 1: 集計

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
```

- 表示をそのまま利用者に示す。表の行を並べ替えたり、状態を書き換えたりしない
- 状態が「レビュー済み」の Phase は、script が作業計画書の `branch:` の PR を GitHub で確かめ、PR があれば「PR 作成済み」に更新してから表示する
- 「GitHub に問い合わせられず」の行があれば、`gh auth status` で GitHub CLI の認証を確かめるよう 1 行添える
- 「GitHub の remote が無いため」の行があれば、`git remote add origin <GitHub の URL>` で remote を登録するよう 1 行添える

## Step 2: この後のコマンドの案内

機能ごとに、表示された状態から実行するコマンドを 1 行ずつ案内する。

| 状態 | 案内するコマンド |
|---|---|
| 作業計画書がない | `/specramo:plan <機能名>` |
| 未着手の Phase がある (最初の 1 つ) | `/specramo:phase-design <機能名> --phase <n>` |
| 実装中の Phase がある | `/specramo:implement <機能名> --phase <n>` か `/specramo:review <機能名> --phase <n>` |
| レビュー済みの Phase がある | `/specramo:explain <機能名> --phase <n>` の後、利用者が PR を作る |
| 全 Phase が PR 作成済み | なし (機能の Phase はすべて PR になった) |

## 編集しないもの

作業計画書の編集は script の状態の更新だけにし、skill の側では file を作ったり書き換えたりしない。
