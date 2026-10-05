//
//  RepositorySearchViewModelTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@MainActor
@Suite("RepositorySearchViewModel")
struct RepositorySearchViewModelTests {

    private let service = ControllableRepositorySearchService()
    /// 端末の UserDefaults を使わないよう、ブックマークはインメモリの保存先に読み書きする
    private let bookmarkStorage = InMemoryBookmarkStorage()

    /// 画面が表示された状態の ViewModel
    private func makeViewModel() -> RepositorySearchViewModel {
        let viewModel = RepositorySearchViewModel(apiService: service, bookmarkStorage: bookmarkStorage)
        viewModel.loadBookmarks()
        return viewModel
    }

    /// 指定した検索結果を表示している状態にする
    private func search(_ viewModel: RepositorySearchViewModel, returning results: [Repository]) async {
        viewModel.query = "keyword"
        viewModel.search()
        await service.waitForRequest(keyword: "keyword")
        await service.respond(to: "keyword", with: .success(results))
        await viewModel.searchTask?.value
    }

    @Test("検索中は loading になり、成功すると結果を反映して loaded になる")
    func searchSuccess() async {
        let viewModel = makeViewModel()
        viewModel.query = "swift"

        viewModel.search()
        await service.waitForRequest(keyword: "swift")

        #expect(viewModel.phase == .loading)

        await service.respond(to: "swift", with: .success([.fixture(fullName: "apple/swift")]))
        await viewModel.searchTask?.value

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.repositories.map(\.fullName) == ["apple/swift"])
    }

    @Test("検索中は前回の結果を保持したまま loading になる")
    func searchKeepsPreviousResultsWhileLoading() async {
        let viewModel = makeViewModel()
        viewModel.query = "first"
        viewModel.search()
        await service.waitForRequest(keyword: "first")
        await service.respond(to: "first", with: .success([.fixture(fullName: "a/first")]))
        await viewModel.searchTask?.value

        viewModel.query = "second"
        viewModel.search()
        await service.waitForRequest(keyword: "second")

        #expect(viewModel.phase == .loading)
        #expect(viewModel.repositories.map(\.fullName) == ["a/first"])

        await service.respond(to: "second", with: .success([]))
        await viewModel.searchTask?.value
    }

    @Test("キーワードの前後の空白を取り除いて検索する")
    func searchTrimsKeyword() async {
        let viewModel = makeViewModel()
        viewModel.query = "  swift \n"

        viewModel.search()
        await service.waitForRequest(keyword: "swift")
        await service.respond(to: "swift", with: .success([]))
        await viewModel.searchTask?.value

        #expect(await service.requestedKeywords == ["swift"])
    }

    @Test("空白だけのキーワードでは検索しない", arguments: ["", "   ", "\n"])
    func searchIgnoresBlankQuery(query: String) async {
        let viewModel = makeViewModel()
        viewModel.query = query

        viewModel.search()

        #expect(viewModel.searchTask == nil)
        #expect(viewModel.phase == .idle)
        #expect(await service.requestedKeywords.isEmpty)
    }

    @Test("結果 0 件の場合は空の結果で loaded になり、未検索（idle）と区別できる")
    func searchWithNoResults() async {
        let viewModel = makeViewModel()
        viewModel.query = "no-hit"

        viewModel.search()
        await service.waitForRequest(keyword: "no-hit")
        await service.respond(to: "no-hit", with: .success([]))
        await viewModel.searchTask?.value

        #expect(viewModel.repositories.isEmpty)
        #expect(viewModel.phase == .loaded)
    }

    @Test("失敗した場合は failed になり、前回の結果は消す")
    func searchFailureClearsPreviousResults() async {
        let viewModel = makeViewModel()
        viewModel.query = "first"
        viewModel.search()
        await service.waitForRequest(keyword: "first")
        await service.respond(to: "first", with: .success([.fixture(fullName: "a/first")]))
        await viewModel.searchTask?.value

        viewModel.query = "second"
        viewModel.search()
        await service.waitForRequest(keyword: "second")
        await service.respond(to: "second", with: .failure(.network(.notConnectedToInternet)))
        await viewModel.searchTask?.value

        #expect(viewModel.phase == .failed(.network(.notConnectedToInternet)))
        #expect(viewModel.repositories.isEmpty)
    }

    @Test("失敗の後に次の検索を始めると loading になる")
    func newSearchClearsPreviousError() async {
        let viewModel = makeViewModel()
        viewModel.query = "first"
        viewModel.search()
        await service.waitForRequest(keyword: "first")
        await service.respond(to: "first", with: .failure(.httpStatus(500)))
        await viewModel.searchTask?.value

        viewModel.query = "second"
        viewModel.search()

        #expect(viewModel.phase == .loading)

        await service.waitForRequest(keyword: "second")
        await service.respond(to: "second", with: .success([]))
        await viewModel.searchTask?.value
    }

    @Test("古い検索のレスポンスが後から返っても、新しい検索結果を上書きしない")
    func outdatedResponseIsIgnored() async {
        let viewModel = makeViewModel()
        viewModel.query = "old"
        viewModel.search()
        let oldTask = viewModel.searchTask
        await service.waitForRequest(keyword: "old")

        viewModel.query = "new"
        viewModel.search()
        await service.waitForRequest(keyword: "new")

        await service.respond(to: "new", with: .success([.fixture(fullName: "new/result")]))
        await viewModel.searchTask?.value
        await service.respond(to: "old", with: .success([.fixture(fullName: "old/result")]))
        await oldTask?.value

        #expect(viewModel.repositories.map(\.fullName) == ["new/result"])
        #expect(viewModel.phase == .loaded)
    }

    @Test("古い検索の失敗が後から返っても、新しい検索のエラー状態にしない")
    func outdatedFailureIsIgnored() async {
        let viewModel = makeViewModel()
        viewModel.query = "old"
        viewModel.search()
        let oldTask = viewModel.searchTask
        await service.waitForRequest(keyword: "old")

        viewModel.query = "new"
        viewModel.search()
        await service.waitForRequest(keyword: "new")
        await service.respond(to: "new", with: .success([.fixture(fullName: "new/result")]))
        await viewModel.searchTask?.value
        await service.respond(to: "old", with: .failure(.network(.timedOut)))
        await oldTask?.value

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.repositories.map(\.fullName) == ["new/result"])
    }

    @Test("入力を空にすると結果と通信状態をクリアし、通信中の結果も反映しない")
    func clearingQueryClearsResults() async {
        let viewModel = makeViewModel()
        viewModel.query = "first"
        viewModel.search()
        await service.waitForRequest(keyword: "first")
        await service.respond(to: "first", with: .success([.fixture(fullName: "a/first")]))
        await viewModel.searchTask?.value

        viewModel.query = "second"
        viewModel.search()
        let inFlightTask = viewModel.searchTask
        await service.waitForRequest(keyword: "second")

        viewModel.query = ""

        #expect(viewModel.repositories.isEmpty)
        #expect(viewModel.phase == .idle)

        await service.respond(to: "second", with: .success([.fixture(fullName: "b/second")]))
        await inFlightTask?.value

        #expect(viewModel.repositories.isEmpty)
    }

    @Test(
        "失敗の原因に応じた文言を返す",
        arguments: [
            (APIError.network(.notConnectedToInternet), "インターネットに接続されていません。接続を確認してから再度お試しください。"),
            (APIError.network(.networkConnectionLost), "インターネットに接続されていません。接続を確認してから再度お試しください。"),
            (APIError.network(.timedOut), "通信がタイムアウトしました。通信環境の良い場所で再度お試しください。"),
            (APIError.network(.cannotFindHost), "検索に失敗しました。時間をおいて再度お試しください。"),
            (APIError.httpStatus(403), "検索できる回数の上限に達しました。しばらく時間をおいて再度お試しください。"),
            (APIError.httpStatus(429), "検索できる回数の上限に達しました。しばらく時間をおいて再度お試しください。"),
            (APIError.httpStatus(422), "検索できないキーワードです。キーワードを見直してください。"),
            (APIError.httpStatus(500), "GitHub で問題が発生しています。時間をおいて再度お試しください。"),
            (APIError.httpStatus(503), "GitHub で問題が発生しています。時間をおいて再度お試しください。"),
            (APIError.httpStatus(404), "検索に失敗しました。時間をおいて再度お試しください。"),
            (APIError.decoding(description: "broken"), "予期しない応答を受け取りました。時間をおいて再度お試しください。"),
            (APIError.invalidResponse, "予期しない応答を受け取りました。時間をおいて再度お試しください。"),
            (APIError.invalidRequest, "検索に失敗しました。時間をおいて再度お試しください。"),
            (APIError.unexpected(description: "unknown"), "検索に失敗しました。時間をおいて再度お試しください。"),
        ]
    )
    func failureMessageDependsOnError(error: APIError, expectedMessage: String) {
        #expect(RepositorySearchViewModel.failureMessage(for: error) == expectedMessage)
    }

    // MARK: - ブックマーク

    @Test("生成しただけでは保存先を読み込まない")
    func initDoesNotReadStorage() throws {
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "a/one")])

        let viewModel = RepositorySearchViewModel(apiService: service, bookmarkStorage: bookmarkStorage)

        #expect(!viewModel.isBookmarked(.fixture(fullName: "a/one")))
    }

    @Test("loadBookmarks で保存済みのブックマークを読み込み、登録済みかどうかを返す")
    func loadsBookmarkedState() throws {
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "a/one")])

        let viewModel = makeViewModel()

        #expect(viewModel.isBookmarked(.fixture(fullName: "a/one")))
        #expect(!viewModel.isBookmarked(.fixture(fullName: "b/two")))
    }

    @Test("追加すると、登録済みとして末尾に追加して保存する")
    func addBookmarkAppendsAndSaves() async throws {
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "a/one")])
        let viewModel = makeViewModel()
        let repository = Repository.fixture(fullName: "b/two")
        await search(viewModel, returning: [repository])

        viewModel.setBookmarked(repository, isBookmarked: true)

        #expect(bookmarkStorage.savedBookmarks == [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        #expect(viewModel.isBookmarked(repository))
    }

    @Test("削除すると、保存済みの一覧から削除して保存する")
    func removeBookmarkRemovesAndSaves() async throws {
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let viewModel = makeViewModel()
        let repository = Repository.fixture(fullName: "a/one")
        await search(viewModel, returning: [repository])

        viewModel.setBookmarked(repository, isBookmarked: false)

        #expect(bookmarkStorage.savedBookmarks == [.fixture(fullName: "b/two")])
        #expect(!viewModel.isBookmarked(repository))
    }

    @Test("登録状態が変わらない操作では保存しない")
    func noOpBookmarkOperationDoesNotSave() throws {
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "a/one")])
        let saveCountBefore = bookmarkStorage.saveCallCount
        let viewModel = makeViewModel()

        viewModel.setBookmarked(.fixture(fullName: "a/one"), isBookmarked: true)
        viewModel.setBookmarked(.fixture(fullName: "b/two"), isBookmarked: false)

        #expect(bookmarkStorage.saveCallCount == saveCountBefore)
    }

    @Test("スター数などが変わっていても fullName が同じなら同じリポジトリとして扱う")
    func identifiesBookmarkByFullName() throws {
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "apple/swift", stargazersCount: 1)])
        let viewModel = makeViewModel()
        let latestSearchResult = Repository.fixture(fullName: "apple/swift", stargazersCount: 999)

        #expect(viewModel.isBookmarked(latestSearchResult))

        viewModel.setBookmarked(latestSearchResult, isBookmarked: false)

        #expect(bookmarkStorage.savedBookmarks.isEmpty)
    }

    @Test("保存に失敗しても登録状態は変更後のまま残し、失敗を bookmarkStorageError として公開する")
    func keepsBookmarkedStateWhenSaveFails() {
        bookmarkStorage.saveError = .saveFailed(description: "disk full")
        let viewModel = makeViewModel()

        viewModel.setBookmarked(.fixture(fullName: "a/one"), isBookmarked: true)

        #expect(viewModel.isBookmarked(.fixture(fullName: "a/one")))
        #expect(bookmarkStorage.savedBookmarks.isEmpty)
        #expect(viewModel.bookmarkStorageError == .saveFailed(description: "disk full"))
    }

    @Test("保存済みのブックマークを読み込めない場合は未登録として扱い、失敗を公開する")
    func exposesBookmarkLoadFailure() {
        bookmarkStorage.loadError = .loadFailed(description: "broken")

        let viewModel = makeViewModel()

        #expect(!viewModel.isBookmarked(.fixture(fullName: "a/one")))
        #expect(viewModel.bookmarkStorageError == .loadFailed(description: "broken"))
    }
}
