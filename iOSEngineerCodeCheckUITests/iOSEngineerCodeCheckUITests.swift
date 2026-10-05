//
//  iOSEngineerCodeCheckUITests.swift
//  iOSEngineerCodeCheckUITests
//

import XCTest

/// 検索 → 詳細 → ブックマークの主要フローを検証する。
///
/// アプリ側には UI テスト用のコードを置かず、テスト側から次の 2 つで外部依存を差し替える。
/// - 検索 API: テスト内で起動した `MockGitHubServer` に接続先を向ける
/// - 保存済みのブックマーク: テストごとに新しい UserDefaults の領域（suite）へ保存先を切り替える
/// そのため、実際のネットワークや端末に保存済みのブックマークには依存しない。
@MainActor
final class iOSEngineerCodeCheckUITests: XCTestCase {

    private enum LaunchOption {
        /// API の接続先を上書きする UserDefaults のキー（アプリ側の `APIClient.baseURLOverrideKey` と同じ値）
        static let apiBaseURLKey = "-APIBaseURL"
        /// ブックマークの保存先を切り替える UserDefaults のキー
        /// （アプリ側の `UserDefaultsBookmarkStorage.suiteNameOverrideKey` と同じ値）
        static let bookmarkStorageSuiteNameKey = "-BookmarkStorageSuiteName"
        /// 数値の書式などが端末の言語設定で変わらないよう、ロケールを固定する
        static let fixedLocale = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    private let timeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSearchShowsResultsAndDetail() throws {
        let app = try launchApp()

        search(app, keyword: "swift")

        let resultRow = repositoryRow(app, fullName: "apple/swift")
        XCTAssertTrue(resultRow.waitForExistence(timeout: timeout))
        XCTAssertTrue(repositoryRow(app, fullName: "yumemi/sample").exists)

        resultRow.tap()

        XCTAssertTrue(app.staticTexts["Written in C++"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["67,000 stars"].exists)
        XCTAssertTrue(app.staticTexts["2,400 watchers"].exists)
        XCTAssertTrue(app.staticTexts["10,000 forks"].exists)
        XCTAssertTrue(app.staticTexts["7,000 open issues"].exists)
    }

    /// 詳細画面のボタン表示が、押すたびに登録状態に合わせて切り替わる（Search タブ・Bookmark タブとも）
    func testDetailBookmarkButtonReflectsBookmarkState() throws {
        let app = try launchApp()
        let addButton = app.buttons["Add to Bookmark"]
        let removeButton = app.buttons["Remove from Bookmark"]

        // Search タブの詳細画面
        search(app, keyword: "swift")
        repositoryRow(app, fullName: "apple/swift").tap()
        addButton.tap()
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))
        removeButton.tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        addButton.tap()
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))

        // Bookmark タブの詳細画面
        app.tabBars.buttons["Bookmark"].tap()
        let bookmarkRow = repositoryRow(app, fullName: "apple/swift")
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: timeout))
        bookmarkRow.tap()
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))
        removeButton.tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        addButton.tap()
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))

        // Search タブの詳細画面で削除すると、Bookmark タブの一覧からも消える
        app.tabBars.buttons["Search"].tap()
        removeButton.tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        app.tabBars.buttons["Bookmark"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["検索ボタンをタップして"].waitForExistence(timeout: timeout))
    }

    func testSearchFieldShowsGuideAsPlaceholderAndKeepsOnlyTypedText() throws {
        let app = try launchApp()
        let field = app.textFields["repositorySearch.field"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))

        XCTAssertEqual(field.placeholderValue, "GitHubのリポジトリを検索できるよー")

        field.tap()
        field.typeText("swift")

        XCTAssertEqual(field.value as? String, "swift")
    }

    func testSearchWithNoResultsShowsNoResultsMessage() throws {
        let app = try launchApp(searchBehavior: .noResults)

        search(app, keyword: "zzzzqqqqxxxx")

        XCTAssertTrue(app.staticTexts["該当するリポジトリがありません"].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.staticTexts["GitHubのリポジトリを検索できるよー"].exists)
    }

    func testResultsCannotBeTappedWhileSearching() throws {
        let app = try launchApp(searchBehavior: .slowSuccess)
        search(app, keyword: "swift")
        let row = repositoryRow(app, fullName: "apple/swift")
        XCTAssertTrue(row.waitForExistence(timeout: timeout))

        search(app, keyword: "kotlin")

        XCTAssertTrue(app.activityIndicators.firstMatch.exists)
        XCTAssertFalse(row.isEnabled)

        // 結果が返ると、再び操作できる
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: row)
        wait(for: [enabled], timeout: timeout)
    }

    func testSearchFailureShowsErrorMessage() throws {
        let app = try launchApp(searchBehavior: .serverError)

        search(app, keyword: "swift")

        // モックサーバーは 500 を返すので、GitHub 側の障害として表示される
        XCTAssertTrue(app.staticTexts["GitHub で問題が発生しています。時間をおいて再度お試しください。"].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.staticTexts["GitHubのリポジトリを検索できるよー"].exists)
        XCTAssertFalse(app.activityIndicators.firstMatch.exists)
    }

    /// モックサーバーを起動し、そこへ接続するようにアプリを起動する。サーバーはテスト終了時に止める。
    private func launchApp(searchBehavior: MockGitHubServer.Behavior = .success) throws -> XCUIApplication {
        let server = try MockGitHubServer(behavior: searchBehavior)
        let baseURL = try server.start(testCase: self)
        addTeardownBlock {
            server.stop()
        }

        let app = XCUIApplication()
        // テストごとに新しい領域を使い、端末に保存済みのブックマークや他のテストの結果に依存しない
        let bookmarkStorageSuiteName = "UITests.\(UUID().uuidString)"
        app.launchArguments = [LaunchOption.apiBaseURLKey, baseURL]
            + [LaunchOption.bookmarkStorageSuiteNameKey, bookmarkStorageSuiteName]
            + LaunchOption.fixedLocale
        app.launch()
        return app
    }

    private func repositoryRow(_ app: XCUIApplication, fullName: String) -> XCUIElement {
        app.buttons["repositoryRow.\(fullName)"]
    }

    private func search(_ app: XCUIApplication, keyword: String) {
        let field = app.textFields["repositorySearch.field"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText(keyword + "\n")
    }
}
