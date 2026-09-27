# Specramo

Specramo (スペクラモ) は、仕様を PR 単位の Phase に分け、実装者が理解してから一段ずつ進める spec 駆動開発の Claude Code plugin です。

- 名前の由来: spec (仕様) + ramo (スペイン語・イタリア語で「枝」)。仕様から Phase ごとの PR へ枝分かれしていきます
- 状態: v0.1 の開発中です。コマンドはまだ含まれていません

## 導入

```text
/plugin marketplace add DaichiHoshina/specramo
/plugin install specramo@specramo
```

この repo は private です。導入するには、手元の git がこの repo を読める必要があります (SSH の鍵、または `gh auth login` と `gh auth setup-git`)。

## 設計文書

- [PRD](docs/design/2026-09-27_specramo-prd.md)
- [Design Doc](docs/design/2026-09-27_specramo-design.md)
- [作業計画書](docs/design/2026-09-27_specramo-plan.md)

## License

[MIT](LICENSE)
