---
description: Spec Ramo を導入先の repo で使い始めるために、設定 file (.specramo/config.yml) と成果物の置き場所 (.specramo/specs/) を作る。「specramo を初期化して」「specramo init」で使う。
disable-model-invocation: true
---

# /specramo:init

導入先の repo に、Spec Ramo の設定 file と成果物の置き場所を作る。すでにある file は変更しない。

## 手順

1. 次の command を実行する。

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/init.sh"
   ```

2. 表示された行をそのまま利用者に示す。「作った」と「作らなかった (すでにある)」の行がある。
3. 設定 file を作ったときは、`.specramo/config.yml` の各項目の意味を 1 行ずつ説明する。値は変更しない (利用者が決める)。
4. 次のコマンドとして `/specramo:prd` を案内する。

## 注意

- 既存の file を上書きしない。script がすでにある file を作らない判定をするので、skill の側で file を作ったり書き換えたりしない。
- `.specramo/` を commit するかどうかは利用者が決める。指摘データの場所のような個人の path は、設定 file に記載しない (環境変数 `SPECRAMO_REVIEW_DATA_DIR` で指定する)。
