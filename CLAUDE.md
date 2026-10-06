# CLAUDE.md

コーディングエージェント向けの要点です。環境・制約・失敗の調べ方の詳細は [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) を参照してください。

## 変更後のフィードバック

- コードを変更したら `scripts/harness.sh check`（lint → build → unit）を実行する。
- 画面の動きに関わる変更では `scripts/harness.sh all`（UI テストを含む）を実行する。
- 合否は終了コードで判断する（0 = 成功、1 = 失敗）。最後の行の `[harness] 結果: 成功（…）` / `[harness] 結果: 失敗（<ステップ>）` でも分かる。
- 失敗したら、harness の出力（失敗したテスト・`<ファイル>:<行>`・エラーの行）を読んでから直す。全文は `build/harness/<ステップ>.log` にある。
- 手元に `iPhone 17` のシミュレータが無い場合は、出力された一覧から `DESTINATION` を指定する。

## 守ること

- lint の指摘は、`// harness:allow <理由>` で黙らせる前に、書き方を直す。
- 警告もエラーとして扱われる。警告を残さない。
- テストを実際のネットワークや端末の状態に依存させない（`iOSEngineerCodeCheckTests/TestDoubles/` と `MockGitHubServer` を使う）。
- 見た目（ダークモード・文字サイズ・幅）は自動テストの対象外。画面を変えたら、確認が必要なことを報告する。
