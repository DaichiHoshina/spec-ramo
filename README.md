# Specramo（スペクラモ）

AI と一緒に大型開発を進めるための、spec 駆動開発のツールキット。

> ステータス：準備中（v0.1 を開発中。まだ `specramo init` は動かない）

## 名前の由来

**spec（仕様）＋ ramo（スペイン語・イタリア語で「枝」）**。仕様から Phase ごとの PR へ枝分かれしながら、一段ずつ形にしていく。

## 特徴

- **作業の単位を PR にそろえる**：1 Phase = 1 PR、目安 400 行以下（テスト除く）。目的はレビューのしやすさ
- **実装者の理解を確かめる**：実装の前後に `/specramo-explain` で AI の説明を読み、自分の理解が合っているかを確かめる
- **一気に最後まで進めない**：自己理解 → PR レビュー依頼 → 次の Phase

## 進め方

1. `/specramo-prd` … PRD（何を実現したいか）
2. `/specramo-design` … Design Doc（何を作れば正解か）
3. `/specramo-plan` … 作業計画書（Phase = PR の一覧）
4. Phase ごとに繰り返す
   - `/specramo-phase-design` … Phase 詳細設計（選択肢がある Phase のみ）
   - `/specramo-explain` … 設計を説明できるか確かめる
   - `/specramo-implement` … 実装
   - `/specramo-review` … 観点ごとの AI レビュー（修正は `--fix` 指定時のみ）
   - `/specramo-explain` … コードを説明できるか確かめる
   - PR → 人のレビュー → マージ

詳しくは [docs/method.md](docs/method.md)。

## クイックスタート（予定）

```bash
uv tool install specramo --from git+https://github.com/DaichiHoshina/specramo.git
cd your-repo
specramo init --agent claude
```

## 参考

- [GitHub Spec Kit](https://github.com/github/spec-kit)
- AWS Kiro

## ライセンス

MIT
