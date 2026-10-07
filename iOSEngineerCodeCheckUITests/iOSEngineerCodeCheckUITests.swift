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
        /// 検索結果の並び順を保存する UserDefaults のキー（アプリ側の `UserDefaultsRepositorySearchSortStorage.storageKey`）。
        /// 起動引数で指定した値は、保存している値より優先して読まれる
        static let searchSortKey = "-RepositorySearchSort"
        /// 数値の書式などが端末の言語設定で変わらないよう、ロケールを固定する
        static let fixedLocale = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    /// 要素が現れる・状態が変わるのを待つ上限。条件を満たした時点で待ちは終わるため、
    /// 手元より遅い CI のランナーでも失敗しないよう、余裕を持たせている
    private let timeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSearchShowsResultsAndDetail() throws {
        let app = try launchApp()

        search(app, keyword: "swift")

        let resultRow = repositoryRow(app, fullName: "apple/swift")
        XCTAssertTrue(resultRow.waitForExistence(timeout: timeout))
        XCTAssertTrue(repositoryRow(app, fullName: "yumemi/sample").exists)
        // 開かずに判断できるよう、行に説明文・Star 数・言語を表示する
        XCTAssertTrue(resultRow.label.contains("The Swift Programming Language"), resultRow.label)
        XCTAssertTrue(resultRow.label.contains("67,000"), resultRow.label)
        XCTAssertTrue(resultRow.label.contains("C++"), resultRow.label)

        resultRow.tap()

        XCTAssertTrue(detailItem(app, "language").waitForExistence(timeout: timeout))
        XCTAssertEqual(detailItem(app, "language").label, "C++")
        XCTAssertTrue(app.staticTexts["The Swift Programming Language"].exists)
        XCTAssertTrue(detailItem(app, "stars").label.contains("67,000"))
        // 詳細はリポジトリ API の値で表示する。Watch 数は検索結果の watchers_count（Star 数と同じ値）ではなく subscribers_count
        XCTAssertTrue(detailItem(app, "watchers").waitForExistence(timeout: timeout))
        XCTAssertTrue(detailItem(app, "watchers").label.contains("2,400"))
        XCTAssertFalse(detailItem(app, "watchers").label.contains("67,000"))
        XCTAssertTrue(detailItem(app, "forks").label.contains("10,000"))
        XCTAssertTrue(detailItem(app, "issues").label.contains("7,000"))
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
        tapWhenEnabled(removeButton)
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        tapWhenEnabled(addButton)
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))

        // Bookmark タブの詳細画面
        app.tabBars.buttons["Bookmark"].tap()
        let bookmarkRow = repositoryRow(app, fullName: "apple/swift")
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: timeout))
        bookmarkRow.tap()
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))
        tapWhenEnabled(removeButton)
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        tapWhenEnabled(addButton)
        XCTAssertTrue(removeButton.waitForExistence(timeout: timeout))

        // Search タブの詳細画面で削除すると、Bookmark タブの一覧からも消える
        app.tabBars.buttons["Search"].tap()
        tapWhenEnabled(removeButton)
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        app.tabBars.buttons["Bookmark"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["ブックマークはまだありません"].waitForExistence(timeout: timeout))
    }

    /// Bookmark タブで削除するとすぐ一覧から消え、詳細画面には留まって再登録でき、再起動後もその状態が保たれる
    func testRemovingFromBookmarkTabDeletesImmediatelyAndPersists() throws {
        let app = try launchApp()
        let addButton = app.buttons["Add to Bookmark"]
        let removeButton = app.buttons["Remove from Bookmark"]
        let bookmarkRow = repositoryRow(app, fullName: "apple/swift")
        let emptyMessage = app.staticTexts["ブックマークはまだありません"]

        search(app, keyword: "swift")
        repositoryRow(app, fullName: "apple/swift").tap()
        tapWhenEnabled(addButton)
        app.tabBars.buttons["Bookmark"].tap()
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: timeout))

        // 削除しても詳細画面に留まり、追加し直せる。一覧に戻ると再登録されている
        bookmarkRow.tap()
        tapWhenEnabled(removeButton)
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
        tapWhenEnabled(removeButton)
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

    /// 入力中は検索欄のクリアボタンで入力をまとめて消せ、検索結果も消えて最初の案内に戻る
    func testClearButtonClearsQueryAndResults() throws {
        let app = try launchApp()
        let field = app.textFields["repositorySearch.field"]
        let clearButton = app.buttons["repositorySearch.clearButton"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        // 入力が無いときは、クリアボタンを出さない
        XCTAssertFalse(clearButton.exists)

        search(app, keyword: "swift")
        XCTAssertTrue(repositoryRow(app, fullName: "apple/swift").waitForExistence(timeout: timeout))

        clearButton.tap()

        XCTAssertEqual(field.value as? String, "リポジトリを検索")
        XCTAssertTrue(waitForNonExistence(of: repositoryRow(app, fullName: "apple/swift")))
        XCTAssertTrue(app.staticTexts["GitHubのリポジトリを検索できるよー"].exists)
        XCTAssertFalse(clearButton.exists)
    }

    /// ブックマークが無いときは追加の方法を案内し、「リポジトリを探す」で Search タブに移れる
    func testEmptyBookmarkGuideLeadsToSearch() throws {
        let app = try launchApp()
        app.tabBars.buttons["Bookmark"].tap()
        XCTAssertTrue(app.staticTexts["ブックマークはまだありません"].waitForExistence(timeout: timeout))

        app.buttons["リポジトリを探す"].tap()

        XCTAssertTrue(app.textFields["repositorySearch.field"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.tabBars.buttons["Search"].isSelected)
    }

    /// 詳細画面の「GitHub で詳細を見る」で、リポジトリのページをアプリ内の Web ページの画面で開ける
    /// （ページの内容は実際の GitHub から読み込むため、画面が開くことだけを確かめる）
    func testDetailOpensRepositoryWebPage() throws {
        let app = try launchApp()
        search(app, keyword: "swift")
        repositoryRow(app, fullName: "apple/swift").tap()
        let openButton = app.buttons["GitHub で詳細を見る"]
        XCTAssertTrue(openButton.waitForExistence(timeout: timeout))

        openButton.tap()

        XCTAssertTrue(app.navigationBars["apple/swift"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: timeout))
        // 開いた直後は履歴が無いため、前後のページへの移動はできない
        XCTAssertFalse(app.buttons["前のページ"].isEnabled)
        XCTAssertFalse(app.buttons["次のページ"].isEnabled)
    }

    /// 並び順を変えると検索し直して結果の順が変わり、アプリを起動し直しても選んだ並び順を覚えている
    func testChangingSortReordersResultsAndIsRemembered() throws {
        let app = try launchApp()
        search(app, keyword: "swift")
        XCTAssertTrue(repositoryRow(app, fullName: "apple/swift").waitForExistence(timeout: timeout))
        XCTAssertTrue(isRow(repositoryRow(app, fullName: "apple/swift"), above: repositoryRow(app, fullName: "yumemi/sample")))

        // モックサーバーは、最近更新された順では結果の順を逆にして返す
        selectSort(app, "最近更新された順")
        waitUntilRow(repositoryRow(app, fullName: "yumemi/sample"), isAbove: repositoryRow(app, fullName: "apple/swift"))
        XCTAssertEqual(app.buttons["repositorySearch.sortMenu"].value as? String, "最近更新された順")

        // 並び順を指定せずに起動し直すと、保存している並び順で検索する
        terminate(app)
        let relaunchedApp = try launchApp(searchSort: nil)
        XCTAssertEqual(relaunchedApp.buttons["repositorySearch.sortMenu"].value as? String, "最近更新された順")
        search(relaunchedApp, keyword: "swift")
        XCTAssertTrue(repositoryRow(relaunchedApp, fullName: "yumemi/sample").waitForExistence(timeout: timeout))
        XCTAssertTrue(isRow(repositoryRow(relaunchedApp, fullName: "yumemi/sample"), above: repositoryRow(relaunchedApp, fullName: "apple/swift")))

        // 端末に保存した並び順を、既定のおすすめ順に戻しておく
        selectSort(relaunchedApp, "おすすめ順")
        waitUntilRow(repositoryRow(relaunchedApp, fullName: "apple/swift"), isAbove: repositoryRow(relaunchedApp, fullName: "yumemi/sample"))
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
        // 取得に失敗してもリポジトリ名は表示する。ブックマークには取得した詳細を保存するため、追加のボタンは出さない
        XCTAssertTrue(app.staticTexts["apple/swift"].exists)
        XCTAssertFalse(app.buttons["Add to Bookmark"].exists)
        XCTAssertFalse(detailItem(app, "stars").exists)
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

        XCTAssertTrue(detailItem(failingApp, "stars").waitForExistence(timeout: timeout))
        XCTAssertTrue(detailItem(failingApp, "stars").label.contains("67,000"))
        XCTAssertTrue(detailItem(failingApp, "watchers").label.contains("2,400"))
        XCTAssertFalse(failingApp.staticTexts["リポジトリの情報を取得できませんでした。時間をおいて再度お試しください。"].exists)
        XCTAssertFalse(failingApp.buttons["再読み込み"].exists)

        // 削除してから、保存している値で追加し直せる
        tapWhenEnabled(failingApp.buttons["Remove from Bookmark"])
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

    // MARK: - 追加読み込み

    /// 一番下までスクロールすると下部にローディングが出て次のページを読み込み、最後のページまで読み込むと消える
    func testScrollingToBottomLoadsNextPage() throws {
        let (app, server) = try launchAppWithServer(searchBehavior: .paginated)
        let loadMoreIndicator = loadMoreIndicator(app)
        let lastRow = repositoryRow(app, fullName: "paged/repo31")
        search(app, keyword: "swift")
        XCTAssertTrue(repositoryRow(app, fullName: "paged/repo1").waitForExistence(timeout: timeout))
        // 1 ページ目の途中では、下部のローディングは出ない
        XCTAssertFalse(loadMoreIndicator.exists)

        // モックサーバーが 2 ページ目を返すまで、下部のローディングが出たままになる
        scrollUntilExists(loadMoreIndicator, in: app)
        XCTAssertFalse(lastRow.exists)

        server.releaseNextPageResponse()

        XCTAssertTrue(lastRow.waitForExistence(timeout: timeout))
        XCTAssertTrue(waitForNonExistence(of: loadMoreIndicator))
    }

    /// 追加読み込みに失敗しても、それまでの結果を残したまま、下部の「再試行」で読み込み直せる
    func testLoadMoreFailureKeepsResultsAndCanRetry() throws {
        let app = try launchApp(searchBehavior: .paginatedNextPageFailsOnce)
        let retryButton = app.buttons["再試行"]
        search(app, keyword: "swift")
        XCTAssertTrue(repositoryRow(app, fullName: "paged/repo1").waitForExistence(timeout: timeout))

        scrollUntilExists(retryButton, in: app)

        XCTAssertTrue(app.staticTexts["GitHub で問題が発生しています。時間をおいて再度お試しください。"].exists)
        XCTAssertTrue(repositoryRow(app, fullName: "paged/repo30").exists)

        tapWhenEnabled(retryButton)

        XCTAssertTrue(repositoryRow(app, fullName: "paged/repo31").waitForExistence(timeout: timeout))
        XCTAssertFalse(retryButton.exists)
    }

    /// 一番下を表示したまま検索し直すと、新しい結果を一番上から 1 ページ目だけ表示し、一番下までスクロールすると続きを読み込める
    func testSearchingAgainWhileScrolledToBottomStillLoadsNextPage() throws {
        let (app, server) = try launchAppWithServer(searchBehavior: .paginated)
        let field = app.textFields["repositorySearch.field"]
        let lastRow = repositoryRow(app, fullName: "paged/repo31")
        search(app, keyword: "swift")
        XCTAssertTrue(repositoryRow(app, fullName: "paged/repo1").waitForExistence(timeout: timeout))
        scrollUntilExists(loadMoreIndicator(app), in: app)
        server.releaseNextPageResponse()
        XCTAssertTrue(lastRow.waitForExistence(timeout: timeout))

        // 入力はそのままで、もう一度検索する。一番上に戻り、1 ページ目だけの結果になる
        field.tap()
        field.typeText("\n")
        XCTAssertTrue(waitForNonExistence(of: lastRow))
        XCTAssertTrue(repositoryRow(app, fullName: "paged/repo1").isHittable)
        XCTAssertFalse(loadMoreIndicator(app).exists)

        // 一番下まで行っても、2 ページ目が返るまでは新しい 1 ページ目の 30 件だけが並ぶ
        scrollUntilExists(loadMoreIndicator(app), in: app)
        XCTAssertTrue(repositoryRow(app, fullName: "paged/repo30").exists)
        XCTAssertFalse(lastRow.exists)

        // 新しい結果の続き（2 ページ目）を読み込む
        server.releaseNextPageResponse()
        XCTAssertTrue(lastRow.waitForExistence(timeout: timeout))
    }

    /// モックサーバーを起動し、そこへ接続するようにアプリを起動する。サーバーはテスト終了時に止める。
    /// - Parameters:
    ///   - bookmarkStorageSuiteName: ブックマークの保存先。起動し直しても同じ保存先を使いたい場合に指定する
    ///   - searchSort: 検索結果の並び順。既定ではおすすめ順で始め、前のテストで選んだ並び順に依存しない。
    ///     `nil` の場合は指定せず、端末に保存している並び順を使う
    private func launchApp(
        searchBehavior: MockGitHubServer.Behavior = .success,
        bookmarkStorageSuiteName: String = "UITests.\(UUID().uuidString)",
        searchSort: String? = "bestMatch"
    ) throws -> XCUIApplication {
        try launchAppWithServer(searchBehavior: searchBehavior, bookmarkStorageSuiteName: bookmarkStorageSuiteName, searchSort: searchSort).app
    }

    /// `launchApp` と同じ。テストからモックサーバーの応答の時機を決める場合に使う
    private func launchAppWithServer(
        searchBehavior: MockGitHubServer.Behavior = .success,
        bookmarkStorageSuiteName: String = "UITests.\(UUID().uuidString)",
        searchSort: String? = "bestMatch"
    ) throws -> (app: XCUIApplication, server: MockGitHubServer) {
        let server = try MockGitHubServer(behavior: searchBehavior)
        let baseURL = try server.start(testCase: self)
        addTeardownBlock {
            server.stop()
        }

        let app = XCUIApplication()
        // 既定ではテストごとに新しい領域を使い、端末に保存済みのブックマークや他のテストの結果に依存しない
        app.launchArguments = [LaunchOption.apiBaseURLKey, baseURL]
            + [LaunchOption.bookmarkStorageSuiteNameKey, bookmarkStorageSuiteName]
            + (searchSort.map { [LaunchOption.searchSortKey, $0] } ?? [])
            + LaunchOption.fixedLocale
        app.launch()
        return (app, server)
    }

    /// アプリを終了し、終了しきったことを確かめる。
    /// 終了しきる前に起動し直すと、CI のような遅い環境で起動が時間切れになることがあるため。
    private func terminate(_ app: XCUIApplication) {
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: timeout), "アプリが終了しませんでした")
    }

    /// 要素が現れるまで、一覧を上にスワイプする。一覧の行は画面に入る直前に作られるため、スクロールしないと現れない
    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 15) {
        var swipes = 0
        while !element.exists && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.exists, "\(maxSwipes) 回スワイプしても \(element) が現れませんでした")
    }

    private func selectSort(_ app: XCUIApplication, _ title: String) {
        app.buttons["repositorySearch.sortMenu"].tap()
        let option = app.buttons[title]
        XCTAssertTrue(option.waitForExistence(timeout: timeout))
        option.tap()
    }

    /// 2 つの行がどちらも表示されていて、`row` が `other` より上にあるか
    private func isRow(_ row: XCUIElement, above other: XCUIElement) -> Bool {
        Self.isRow(row, above: other)
    }

    private static func isRow(_ row: XCUIElement, above other: XCUIElement) -> Bool {
        row.exists && other.exists && row.frame.minY < other.frame.minY
    }

    /// `row` が `other` より上に表示されるまで待つ。並び順を変えた後に、検索し直した結果が出るのを待つために使う
    private func waitUntilRow(_ row: XCUIElement, isAbove other: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let reordered = expectation(for: NSPredicate { _, _ in Self.isRow(row, above: other) }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reordered], timeout: timeout), .completed, "\(row) が \(other) より上に表示されませんでした", file: file, line: line)
    }

    /// 要素が消えるのを待つ。消えたら true
    private func waitForNonExistence(of element: XCUIElement) -> Bool {
        let disappeared = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter.wait(for: [disappeared], timeout: timeout) == .completed
    }

    /// 検索結果の一覧の下部に、続きのページがある間・読み込み中に表示するローディング
    private func loadMoreIndicator(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["repositorySearch.loadMoreIndicator"]
    }

    /// 詳細画面の項目（`repositoryDetail.<name>`。stars・watchers・forks・issues・language）
    private func detailItem(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.descendants(matching: .any)["repositoryDetail.\(name)"]
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

    /// 要素が現れて押せる状態になるのを待ってから押す。
    /// 詳細画面の「Add to Bookmark」は詳細を取得できるまで押せず、画面遷移の直後のボタンは遅い環境では表示が遅れるため
    private func tapWhenEnabled(_ element: XCUIElement) {
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: element)
        wait(for: [enabled], timeout: timeout)
        element.tap()
    }
}
