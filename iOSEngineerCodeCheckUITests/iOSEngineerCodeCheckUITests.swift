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
        // 詳細はリポジトリ API の値で表示する。Watch 数は検索結果の watchers_count（Star 数と同じ値）ではなく subscribers_count
        XCTAssertTrue(app.staticTexts["2,400 watchers"].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.staticTexts["67,000 watchers"].exists)
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
        tapWhenEnabled(addButton)
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))
        removeButton.tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        tapWhenEnabled(addButton)
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))

        // Bookmark タブの詳細画面
        app.tabBars.buttons["Bookmark"].tap()
        let bookmarkRow = repositoryRow(app, fullName: "apple/swift")
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: timeout))
        bookmarkRow.tap()
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))
        removeButton.tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        tapWhenEnabled(addButton)
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))

        // Search タブの詳細画面で削除すると、Bookmark タブの一覧からも消える
        app.tabBars.buttons["Search"].tap()
        removeButton.tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        app.tabBars.buttons["Bookmark"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["検索ボタンをタップして"].waitForExistence(timeout: timeout))
    }

    /// Bookmark タブで削除するとすぐ一覧から消え、詳細画面には留まって再登録でき、再起動後もその状態が保たれる
    func testRemovingFromBookmarkTabDeletesImmediatelyAndPersists() throws {
        let app = try launchApp()
        let addButton = app.buttons["Add to Bookmark"]
        let removeButton = app.buttons["Remove from Bookmark"]
        let bookmarkRow = repositoryRow(app, fullName: "apple/swift")
        let emptyMessage = app.staticTexts["検索ボタンをタップして"]

        search(app, keyword: "swift")
        repositoryRow(app, fullName: "apple/swift").tap()
        tapWhenEnabled(addButton)
        app.tabBars.buttons["Bookmark"].tap()
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: timeout))

        // 削除しても詳細画面に留まり、追加し直せる。一覧に戻ると再登録されている
        bookmarkRow.tap()
        removeButton.tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["apple/swift"].exists)
        tapWhenEnabled(addButton)
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: timeout))

        // 再起動しても登録されたまま
        terminate(app)
        app.launch()
        app.tabBars.buttons["Bookmark"].tap()
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: timeout))

        // 削除して一覧に戻ると、すぐに消えている
        bookmarkRow.tap()
        removeButton.tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(emptyMessage.waitForExistence(timeout: timeout))
        XCTAssertFalse(bookmarkRow.exists)

        // 再起動しても削除されたまま
        terminate(app)
        app.launch()
        app.tabBars.buttons["Bookmark"].tap()
        XCTAssertTrue(emptyMessage.waitForExistence(timeout: timeout))
        XCTAssertFalse(bookmarkRow.exists)
    }

    func testSearchFieldShowsGuideAsPlaceholderAndKeepsOnlyTypedText() throws {
        let app = try launchApp()
        let field = app.textFields["repositorySearch.field"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))

        XCTAssertEqual(field.placeholderValue, "リポジトリを検索")

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

    func testDetailShowsErrorWhenRepositoryDetailCannotBeFetched() throws {
        let app = try launchApp(searchBehavior: .detailServerError)

        search(app, keyword: "swift")
        repositoryRow(app, fullName: "apple/swift").tap()

        XCTAssertTrue(app.staticTexts["リポジトリの情報を取得できませんでした。時間をおいて再度お試しください。"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["再読み込み"].exists)
        // 取得に失敗してもリポジトリ名は表示する。ブックマークには取得した詳細を保存するため、追加はできない
        XCTAssertTrue(app.staticTexts["apple/swift"].exists)
        XCTAssertTrue(app.buttons["Add to Bookmark"].exists)
        XCTAssertFalse(app.buttons["Add to Bookmark"].isEnabled)
        XCTAssertFalse(app.staticTexts["67,000 stars"].exists)
    }

    /// ブックマークから開いた詳細画面は、保存している値だけで表示し、リポジトリ API と通信しない
    func testBookmarkDetailShowsSavedValuesWithoutFetching() throws {
        let bookmarkStorageSuiteName = "UITests.\(UUID().uuidString)"
        let app = try launchApp(bookmarkStorageSuiteName: bookmarkStorageSuiteName)
        search(app, keyword: "swift")
        repositoryRow(app, fullName: "apple/swift").tap()
        tapWhenEnabled(app.buttons["Add to Bookmark"])
        XCTAssertTrue(app.buttons["Remove from Bookmark"].waitForExistence(timeout: timeout))
        terminate(app)

        // 同じ保存先のまま、リポジトリ API が失敗する状態で起動し直す。通信していればエラーが表示される
        let failingApp = try launchApp(searchBehavior: .detailServerError, bookmarkStorageSuiteName: bookmarkStorageSuiteName)
        failingApp.tabBars.buttons["Bookmark"].tap()
        repositoryRow(failingApp, fullName: "apple/swift").tap()

        XCTAssertTrue(failingApp.staticTexts["67,000 stars"].waitForExistence(timeout: timeout))
        XCTAssertTrue(failingApp.staticTexts["2,400 watchers"].exists)
        XCTAssertFalse(failingApp.staticTexts["リポジトリの情報を取得できませんでした。時間をおいて再度お試しください。"].exists)
        XCTAssertFalse(failingApp.buttons["再読み込み"].exists)

        // 削除してから、保存している値で追加し直せる
        failingApp.buttons["Remove from Bookmark"].tap()
        tapWhenEnabled(failingApp.buttons["Add to Bookmark"])
        XCTAssertTrue(failingApp.buttons["Remove from Bookmark"].waitForExistence(timeout: timeout))
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
    /// - Parameter bookmarkStorageSuiteName: ブックマークの保存先。起動し直しても同じ保存先を使いたい場合に指定する
    private func launchApp(
        searchBehavior: MockGitHubServer.Behavior = .success,
        bookmarkStorageSuiteName: String = "UITests.\(UUID().uuidString)"
    ) throws -> XCUIApplication {
        let server = try MockGitHubServer(behavior: searchBehavior)
        let baseURL = try server.start(testCase: self)
        addTeardownBlock {
            server.stop()
        }

        let app = XCUIApplication()
        // 既定ではテストごとに新しい領域を使い、端末に保存済みのブックマークや他のテストの結果に依存しない
        app.launchArguments = [LaunchOption.apiBaseURLKey, baseURL]
            + [LaunchOption.bookmarkStorageSuiteNameKey, bookmarkStorageSuiteName]
            + LaunchOption.fixedLocale
        app.launch()
        return app
    }

    /// アプリを終了し、終了しきったことを確かめる。
    /// 終了しきる前に起動し直すと、CI のような遅い環境で起動が時間切れになることがあるため。
    private func terminate(_ app: XCUIApplication) {
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: timeout), "アプリが終了しませんでした")
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

    /// 詳細画面の「Add to Bookmark」は、リポジトリの詳細を取得できるまで押せないため、有効になるのを待ってから押す
    private func tapWhenEnabled(_ element: XCUIElement) {
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: element)
        wait(for: [enabled], timeout: timeout)
        element.tap()
    }
}
