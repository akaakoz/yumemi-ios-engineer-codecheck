# 開発ガイド

変更に対するフィードバック（静的解析・ビルド・テスト）を、手元でも CI でも同じ手順で得るための説明です。

## 必要な環境

| 項目 | バージョン | 確認方法 |
|---|---|---|
| Xcode | 26 系（26.0 以降） | `xcodebuild -version` |
| iOS シミュレータ | iOS 26 系のランタイム | `xcrun simctl list runtimes` |
| SwiftLint | `Package.resolved` で固定（SwiftLintPlugins） | 自動で取得されるため、インストール不要 |

- 使う Xcode は、`xcode-select` で選んでいるもの（端末全体）か、環境変数 `DEVELOPER_DIR`（そのコマンドだけ）で決まります。アプリの名前や置き場所は問いません。
  ```sh
  sudo xcode-select --switch /Applications/Xcode.app
  DEVELOPER_DIR=/Applications/Xcode-26.6.app/Contents/Developer scripts/harness.sh check
  ```
- シミュレータのランタイムが無い場合は、Xcode の Settings > Components から iOS 26 をインストールします。
- 署名は不要です（シミュレータ向けのビルドでは署名しません）。秘密情報も使いません。

## セットアップ

```sh
git clone <このリポジトリ>
cd <クローンしたディレクトリ>
scripts/harness.sh check
```

追加でインストールするものはありません。

- 初回のビルドでは、SwiftLint（SPM のパッケージ SwiftLintPlugins）を GitHub から取得します。インターネットへの接続が必要です。
- Xcode で初めてビルドするときは、SwiftLint のプラグインを信頼するかを聞かれるので、**Trust & Enable** を選びます（端末ごとに初回のみ。SwiftLintPlugins を更新したときは再度聞かれる）。`scripts/harness.sh` と CI では聞かれません。

## 主要コマンド

すべて `scripts/harness.sh` から実行します。成功なら終了コード 0、失敗なら 1 です。

| コマンド | 実行するもの | 目安の時間 | 使いどころ |
|---|---|---|---|
| `scripts/harness.sh check` | build → unit | 1〜2 分 | 変更のたびに実行する |
| `scripts/harness.sh all` | build → unit → ui | 5〜7 分 | 画面の動きに関わる変更の後、PR を出す前。CI はこれを実行する |
| `scripts/harness.sh build` | アプリとテストのビルド（SwiftLint の検査を含む。警告もエラーとして扱う） | | |
| `scripts/harness.sh unit` / `ui` | ユニットテスト / UI テスト（build の後に実行する） | | 特定の種類だけ実行し直したいとき |

### それぞれで分かること

| ステップ | 検出できること |
|---|---|
| build | コンパイルエラー、Swift 6 の並行処理（Sendable など）の問題を含むすべての警告、SwiftLint によるプロジェクトのルールの違反（下記「コーディングルール」） |
| unit（Swift Testing） | API の扱い（URL の組み立て、エラーの対応、デコード）、各 ViewModel の状態遷移、検索の並行処理、ブックマークの保存・読み込み・旧形式からの移行・壊れたデータの退避、タブ間での同期 |
| ui（XCUITest） | 検索 → 結果 → 詳細 → ブックマークの一連の操作、0 件・失敗・検索中の表示、ブックマークの永続化 |

### シミュレータの指定

既定では `platform=iOS Simulator,name=iPhone 17,OS=latest` で実行します。手元にないシミュレータの場合は、環境変数 `DESTINATION` で指定します。

```sh
DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=26.0.1' scripts/harness.sh check
```

指定したシミュレータが見つからない場合は、使えるシミュレータの一覧が表示されます。

## プロジェクト固有の制約

### テスト

- **テストは実際のネットワークや端末の状態に依存させない。**
  - ユニットテスト: `StubAPIClient` / `StubNetworkSession` / `InMemoryBookmarkStorage` / `Fixtures`（`iOSEngineerCodeCheckTests/TestDoubles/`）を使う
  - UI テスト: テストのプロセス内で動く `MockGitHubServer` に、アプリを起動引数で接続させる
    - `-APIBaseURL http://localhost:<port>`: 接続先（Debug ビルドのみ有効）
    - `-BookmarkStorageSuiteName <名前>`: ブックマークの保存先の UserDefaults（Debug ビルドのみ有効）
- ユニットテストは Swift Testing、UI テストは XCUITest で書く。
- 時間で待ち合わせない（`Task.sleep` を使わない）。完了を待てる仕組み（`StubAPIClient` の `waitForRequest` / `respond` など）を使う。

### コーディングルール

- 設計: MVVM。依存は Protocol で注入する。非同期処理は async/await で書き、画面からは `.task` で開始する。処理中はボタンなどを押せないようにする。
- エラーを握りつぶさない。理由のないフォールバック（説明のない `?? ""` など）を書かない。
- 次の書き方は SwiftLint が検出し、ビルドを失敗させる。検査するルールと理由は `.swiftlint.yml` にまとめている（ルールを変えるときはこのファイルだけを直す）。
  - SwiftLint の標準ルール: 強制アンラップ `!` / 暗黙的アンラップ型 `T!` / `try!` / `as!`
  - 独自ルール（`custom_rules`）: `try?` / 空の `catch` / `@unchecked Sendable` / `nonisolated(unsafe)` / `Task.sleep`
- やむを得ず使う場合は、直前の行に `// swiftlint:disable:next <ルール名>` と理由を書く。
- 理由のない `?? ""` は SwiftLint では検出できないため、レビューで確認する。
- コミットは Conventional Commits（type は英語、説明は日本語）で、小さな単位に分ける。

### 見た目（自動テストの対象外）

レイアウトや色はスナップショットテストをしていないため、画面に関わる変更では次を手動で確認する。

- ライトモード / ダークモード
- 文字サイズ（設定 > アクセシビリティ > 画面表示とテキストサイズ > さらに大きな文字）
- 幅の狭い端末（iPhone SE など）と長い文字列（長いリポジトリ名・言語名）

## 失敗したときの調べ方

### 1. harness の出力を見る

失敗したステップで、次の情報が表示されます。

- 失敗したテストの名前・関数名・失敗メッセージと、実行したシミュレータ
- 失敗した箇所（`<ファイル>:<行>`）
- ログ中のエラー・警告の行（コンパイルエラー、警告、XCTest の失敗）
- SwiftLint の違反は `<ファイル>:<行>:<列>: error: <内容> (<ルール名>)` の形で、エラーの行として表示される

### 2. ログと結果ファイルを見る

| ファイル | 内容 |
|---|---|
| `build/harness/<ステップ>.log` | xcodebuild の出力の全文 |
| `build/harness/<ステップ>.xcresult` | テスト結果。`open build/harness/ui.xcresult` で Xcode で開くと、UI テストの失敗時の画面や操作の記録も確認できる |

`build/` は gitignore の対象です。実行し直すと上書きされます。

### 3. アプリのログを見る

アプリは `os.Logger`（subsystem `jp.yumemi.iOSEngineerCodeCheck`）で、通信やブックマークの保存の失敗を記録しています。

```sh
xcrun simctl spawn booted log stream --level debug \
  --predicate 'subsystem == "jp.yumemi.iOSEngineerCodeCheck"'
```

実機の場合は Console.app で、同じ subsystem で絞り込みます。

### よくある失敗

| 症状 | 対処 |
|---|---|
| `指定されたシミュレータが見つかりません` | 表示された一覧から `DESTINATION` を指定する |
| UI テストが、画面の要素を取得できずにタイムアウトして失敗する（コードの変更と関係なく） | シミュレータの状態が原因のことが多い。`xcrun simctl shutdown all` の後に再実行するか、Simulator の Device > Erase All Content and Settings を行う |
| build だけ失敗し、Xcode では警告しか出ていない | harness は警告をエラーとして扱う。表示された警告を直す |
| build の最初に SwiftLintPlugins の取得で失敗する | GitHub に接続できるかを確認する。初回のビルドだけ接続が必要 |
| ユニットテストの後、シミュレータ上のアプリが落ちたように見える | テストのホストとして起動したアプリが、テスト終了時に終了するため。異常ではない |

### GitHub API の仕様を確かめる

テストは GitHub に接続しません。API の応答の形や値（例: Watch 数は検索 API の `watchers_count` ではなく、リポジトリ API の `subscribers_count`）を確かめたいときは、手動で curl を使います。未認証では 1 時間に 60 回の制限があります。

```sh
curl -s 'https://api.github.com/search/repositories?q=swift&per_page=1' | head -40
curl -sL 'https://api.github.com/repos/swiftlang/swift' | grep -E '"(stargazers|watchers|subscribers)_count"'
```

## CI

`.github/workflows/ci.yml` が、`main` への push と pull request のたびに、`macos-26` ランナーで `scripts/harness.sh all` を実行します。

- 結果は PR の Checks、または Actions タブで確認します。失敗したステップのログには、手元と同じ harness の出力が表示されます。
- 失敗した場合は、`build/harness/` が成果物 `harness-results` として 7 日間保存されます。実行結果のページの Artifacts からダウンロードし、`.xcresult` を Xcode で開きます。
- secrets は使いません。

### SwiftLint のバージョンを上げるとき

1. Xcode で File > Packages > Update to Latest Package Versions を実行する。
2. `scripts/harness.sh check` を実行し、新しいバージョンで増えた指摘を直す。
3. `Package.resolved` の差分をコミットする。

### Xcode のバージョンを上げるとき

1. 手元で新しい Xcode を選び、`scripts/harness.sh all` を実行する。新しく出た警告は harness が失敗として報告するので、直す。
2. CI では、workflow の `runs-on` と `XCODE_MAJOR_VERSION` を新しいバージョンに変える。移行の間は matrix で旧バージョンと並べ、新バージョンだけ `continue-on-error: true` にしておくと、開発を止めずに確かめられる。
3. 新しいバージョンに `iPhone 17` のシミュレータが無い場合は、`DESTINATION` も合わせて変える。
4. このファイルの「必要な環境」を更新する。
