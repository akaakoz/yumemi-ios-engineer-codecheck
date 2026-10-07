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

    private let apiClient = StubAPIClient()

    private func makeViewModel() -> RepositorySearchViewModel {
        RepositorySearchViewModel(apiService: RepositorySearchAPIService(apiClient: apiClient))
    }

    /// 指定した検索結果を表示している状態にする
    private func search(_ viewModel: RepositorySearchViewModel, returning results: [Repository]) async {
        viewModel.query = "keyword"
        viewModel.search()
        await apiClient.waitForRequest(keyword: "keyword")
        await apiClient.respond(to: "keyword", with: .success(results))
        await viewModel.searchTask?.value
    }

    @Test("検索中は loading になり、成功すると結果を反映して loaded になる")
    func searchSuccess() async {
        let viewModel = makeViewModel()
        viewModel.query = "swift"

        viewModel.search()
        await apiClient.waitForRequest(keyword: "swift")

        #expect(viewModel.phase == .loading)

        await apiClient.respond(to: "swift", with: .success([.fixture(fullName: "apple/swift")]))
        await viewModel.searchTask?.value

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.repositories.map(\.fullName) == ["apple/swift"])
    }

    @Test("検索中は前回の結果を保持したまま loading になる")
    func searchKeepsPreviousResultsWhileLoading() async {
        let viewModel = makeViewModel()
        viewModel.query = "first"
        viewModel.search()
        await apiClient.waitForRequest(keyword: "first")
        await apiClient.respond(to: "first", with: .success([.fixture(fullName: "a/first")]))
        await viewModel.searchTask?.value

        viewModel.query = "second"
        viewModel.search()
        await apiClient.waitForRequest(keyword: "second")

        #expect(viewModel.phase == .loading)
        #expect(viewModel.repositories.map(\.fullName) == ["a/first"])

        await apiClient.respond(to: "second", with: .success([]))
        await viewModel.searchTask?.value
    }

    @Test("キーワードの前後の空白を取り除いて検索する")
    func searchTrimsKeyword() async {
        let viewModel = makeViewModel()
        viewModel.query = "  swift \n"

        viewModel.search()
        await apiClient.waitForRequest(keyword: "swift")
        await apiClient.respond(to: "swift", with: .success([]))
        await viewModel.searchTask?.value

        #expect(await apiClient.requestedKeywords == ["swift"])
    }

    @Test("空白だけのキーワードでは検索しない", arguments: ["", "   ", "\n"])
    func searchIgnoresBlankQuery(query: String) async {
        let viewModel = makeViewModel()
        viewModel.query = query

        viewModel.search()

        #expect(viewModel.searchTask == nil)
        #expect(viewModel.phase == .idle)
        #expect(await apiClient.requestedKeywords.isEmpty)
    }

    @Test("結果 0 件の場合は空の結果で loaded になり、未検索（idle）と区別できる")
    func searchWithNoResults() async {
        let viewModel = makeViewModel()
        viewModel.query = "no-hit"

        viewModel.search()
        await apiClient.waitForRequest(keyword: "no-hit")
        await apiClient.respond(to: "no-hit", with: .success([]))
        await viewModel.searchTask?.value

        #expect(viewModel.repositories.isEmpty)
        #expect(viewModel.phase == .loaded)
    }

    @Test("失敗した場合は failed になり、前回の結果は消す")
    func searchFailureClearsPreviousResults() async {
        let viewModel = makeViewModel()
        viewModel.query = "first"
        viewModel.search()
        await apiClient.waitForRequest(keyword: "first")
        await apiClient.respond(to: "first", with: .success([.fixture(fullName: "a/first")]))
        await viewModel.searchTask?.value

        viewModel.query = "second"
        viewModel.search()
        await apiClient.waitForRequest(keyword: "second")
        await apiClient.respond(to: "second", with: .failure(.network(.notConnectedToInternet)))
        await viewModel.searchTask?.value

        #expect(viewModel.phase == .failed(.network(.notConnectedToInternet)))
        #expect(viewModel.repositories.isEmpty)
    }

    @Test("失敗の後に次の検索を始めると loading になる")
    func newSearchClearsPreviousError() async {
        let viewModel = makeViewModel()
        viewModel.query = "first"
        viewModel.search()
        await apiClient.waitForRequest(keyword: "first")
        await apiClient.respond(to: "first", with: .failure(.httpStatus(500)))
        await viewModel.searchTask?.value

        viewModel.query = "second"
        viewModel.search()

        #expect(viewModel.phase == .loading)

        await apiClient.waitForRequest(keyword: "second")
        await apiClient.respond(to: "second", with: .success([]))
        await viewModel.searchTask?.value
    }

    @Test("古い検索のレスポンスが後から返っても、新しい検索結果を上書きしない")
    func outdatedResponseIsIgnored() async {
        let viewModel = makeViewModel()
        viewModel.query = "old"
        viewModel.search()
        let oldTask = viewModel.searchTask
        await apiClient.waitForRequest(keyword: "old")

        viewModel.query = "new"
        viewModel.search()
        await apiClient.waitForRequest(keyword: "new")

        await apiClient.respond(to: "new", with: .success([.fixture(fullName: "new/result")]))
        await viewModel.searchTask?.value
        await apiClient.respond(to: "old", with: .success([.fixture(fullName: "old/result")]))
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
        await apiClient.waitForRequest(keyword: "old")

        viewModel.query = "new"
        viewModel.search()
        await apiClient.waitForRequest(keyword: "new")
        await apiClient.respond(to: "new", with: .success([.fixture(fullName: "new/result")]))
        await viewModel.searchTask?.value
        await apiClient.respond(to: "old", with: .failure(.network(.timedOut)))
        await oldTask?.value

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.repositories.map(\.fullName) == ["new/result"])
    }

    @Test("入力を空にすると結果と通信状態をクリアし、通信中の結果も反映しない")
    func clearingQueryClearsResults() async {
        let viewModel = makeViewModel()
        viewModel.query = "first"
        viewModel.search()
        await apiClient.waitForRequest(keyword: "first")
        await apiClient.respond(to: "first", with: .success([.fixture(fullName: "a/first")]))
        await viewModel.searchTask?.value

        viewModel.query = "second"
        viewModel.search()
        let inFlightTask = viewModel.searchTask
        await apiClient.waitForRequest(keyword: "second")

        viewModel.query = ""

        #expect(viewModel.repositories.isEmpty)
        #expect(viewModel.phase == .idle)

        await apiClient.respond(to: "second", with: .success([.fixture(fullName: "b/second")]))
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

    // MARK: - 追加読み込み

    /// 1 ページ目に `firstPage`（全 `totalCount` 件）を表示している状態の ViewModel
    private func makeViewModelShowingFirstPage(
        keyword: String = "swift",
        _ firstPage: [Repository],
        totalCount: Int = 100
    ) async -> RepositorySearchViewModel {
        let viewModel = makeViewModel()
        viewModel.query = keyword
        viewModel.search()
        await apiClient.waitForRequest(keyword: keyword)
        await apiClient.respond(to: keyword, totalCount: totalCount, with: .success(firstPage))
        await viewModel.searchTask?.value
        return viewModel
    }

    @Test("最後まで表示されたら次のページを同じキーワードで読み込み、通信中は loading、成功すると末尾に足す")
    func loadMoreAppendsNextPage() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")])
        #expect(viewModel.canLoadMore)

        viewModel.loadMoreIfNeeded()
        await apiClient.waitForRequest(keyword: "swift", page: 2)

        #expect(viewModel.loadMorePhase == .loading)
        #expect(!viewModel.canLoadMore)
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.repositories.map(\.fullName) == ["a/one"])

        await apiClient.respond(to: "swift", page: 2, totalCount: 100, with: .success([.fixture(fullName: "b/two")]))
        await viewModel.loadMoreTask?.value

        #expect(viewModel.loadMorePhase == .idle)
        #expect(viewModel.repositories.map(\.fullName) == ["a/one", "b/two"])
    }

    @Test("次のページが無い場合は読み込まない")
    func loadMoreDoesNothingWithoutNextPage() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")], totalCount: 1)
        #expect(!viewModel.canLoadMore)

        viewModel.loadMoreIfNeeded()

        #expect(viewModel.loadMorePhase == .idle)
        #expect(viewModel.loadMoreTask == nil)
    }

    @Test("最後のページまで読み込んだら、それ以上は読み込まない")
    func loadMoreStopsAfterLastPage() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")], totalCount: 31)
        viewModel.loadMoreIfNeeded()
        await apiClient.waitForRequest(keyword: "swift", page: 2)
        await apiClient.respond(to: "swift", page: 2, totalCount: 31, with: .success([.fixture(fullName: "b/two")]))
        await viewModel.loadMoreTask?.value
        let requestCount = await apiClient.requestedKeys.count
        #expect(!viewModel.canLoadMore)

        viewModel.loadMoreIfNeeded()

        #expect(await apiClient.requestedKeys.count == requestCount)
        #expect(viewModel.loadMorePhase == .idle)
    }

    @Test("追加読み込みの通信中に呼ばれても、同じページを重ねて要求しない")
    func loadMoreDoesNotRequestTwiceWhileLoading() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")])
        viewModel.loadMoreIfNeeded()
        await apiClient.waitForRequest(keyword: "swift", page: 2)

        viewModel.loadMoreIfNeeded()
        await apiClient.respond(to: "swift", page: 2, totalCount: 100, with: .success([.fixture(fullName: "b/two")]))
        await viewModel.loadMoreTask?.value

        #expect(await apiClient.requestedKeywords == ["swift", "swift"])
        #expect(viewModel.repositories.map(\.fullName) == ["a/one", "b/two"])
    }

    @Test("前のページで表示したリポジトリが次のページに含まれていても、重複して表示しない")
    func loadMoreRemovesDuplicates() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])

        viewModel.loadMoreIfNeeded()
        await apiClient.waitForRequest(keyword: "swift", page: 2)
        await apiClient.respond(
            to: "swift",
            page: 2,
            totalCount: 100,
            with: .success([.fixture(fullName: "b/two", stargazersCount: 999), .fixture(fullName: "c/three"), .fixture(fullName: "c/three")])
        )
        await viewModel.loadMoreTask?.value

        #expect(viewModel.repositories.map(\.fullName) == ["a/one", "b/two", "c/three"])
        // 先に表示していた内容を残す
        #expect(viewModel.repositories[1].stargazersCount == 100)
    }

    @Test("次のページがすべて表示済みのリポジトリだった場合も、続きのページがある状態に戻り、次のページを読み込める")
    func loadMoreAfterPageWithNoNewRepositories() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")])
        viewModel.loadMoreIfNeeded()
        await apiClient.waitForRequest(keyword: "swift", page: 2)
        await apiClient.respond(to: "swift", page: 2, totalCount: 100, with: .success([.fixture(fullName: "a/one")]))
        await viewModel.loadMoreTask?.value

        #expect(viewModel.repositories.map(\.fullName) == ["a/one"])
        #expect(viewModel.loadMorePhase == .idle)
        #expect(viewModel.canLoadMore)

        viewModel.loadMoreIfNeeded()
        await apiClient.waitForRequest(keyword: "swift", page: 3)
        await apiClient.respond(to: "swift", page: 3, totalCount: 100, with: .success([.fixture(fullName: "c/three")]))
        await viewModel.loadMoreTask?.value

        #expect(viewModel.repositories.map(\.fullName) == ["a/one", "c/three"])
    }

    @Test("追加読み込みに失敗してもそれまでの結果は残し、自動では読み込み直さず、再試行で同じページを読み込める")
    func loadMoreFailureKeepsResultsAndCanRetry() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")])
        viewModel.loadMoreIfNeeded()
        await apiClient.waitForRequest(keyword: "swift", page: 2)
        await apiClient.respond(to: "swift", page: 2, with: .failure(.network(.notConnectedToInternet)))
        await viewModel.loadMoreTask?.value

        #expect(viewModel.loadMorePhase == .failed(.network(.notConnectedToInternet)))
        #expect(!viewModel.canLoadMore)
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.repositories.map(\.fullName) == ["a/one"])

        // 失敗中は、最後まで表示されても自動では読み込み直さない
        viewModel.loadMoreIfNeeded()
        #expect(await apiClient.requestedKeywords.count == 2)

        viewModel.retryLoadMore()
        await apiClient.waitForRequest(keyword: "swift", page: 2)
        #expect(viewModel.loadMorePhase == .loading)
        await apiClient.respond(to: "swift", page: 2, totalCount: 100, with: .success([.fixture(fullName: "b/two")]))
        await viewModel.loadMoreTask?.value

        #expect(viewModel.loadMorePhase == .idle)
        #expect(viewModel.repositories.map(\.fullName) == ["a/one", "b/two"])
    }

    @Test("失敗していないときに再試行しても、何もしない")
    func retryDoesNothingUnlessFailed() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")])

        viewModel.retryLoadMore()

        #expect(viewModel.loadMoreTask == nil)
        #expect(viewModel.loadMorePhase == .idle)
    }

    @Test("新しい検索の通信中は、前の検索の続きを読み込まない")
    func loadMoreDoesNothingWhileNewSearchIsLoading() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")])
        viewModel.query = "kotlin"
        viewModel.search()
        #expect(!viewModel.canLoadMore)

        viewModel.loadMoreIfNeeded()

        #expect(viewModel.loadMoreTask == nil)
        #expect(viewModel.loadMorePhase == .idle)
    }

    @Test("追加読み込みの通信中に新しい検索を始めると、前の検索の続きが後から返っても新しい結果に混ぜない")
    func newSearchDiscardsInFlightLoadMore() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")])
        viewModel.loadMoreIfNeeded()
        let oldLoadMoreTask = viewModel.loadMoreTask
        await apiClient.waitForRequest(keyword: "swift", page: 2)

        viewModel.query = "kotlin"
        viewModel.search()
        #expect(viewModel.loadMorePhase == .idle)
        await apiClient.waitForRequest(keyword: "kotlin")
        await apiClient.respond(to: "kotlin", totalCount: 100, with: .success([.fixture(fullName: "k/one")]))
        await viewModel.searchTask?.value
        await apiClient.respond(to: "swift", page: 2, totalCount: 100, with: .success([.fixture(fullName: "b/two")]))
        await oldLoadMoreTask?.value

        #expect(viewModel.repositories.map(\.fullName) == ["k/one"])
        #expect(viewModel.loadMorePhase == .idle)

        // 新しい検索の続きは、新しいキーワードで 2 ページ目から読み込む
        viewModel.loadMoreIfNeeded()
        await apiClient.waitForRequest(keyword: "kotlin", page: 2)
        await apiClient.respond(to: "kotlin", page: 2, totalCount: 100, with: .success([.fixture(fullName: "k/two")]))
        await viewModel.loadMoreTask?.value
        #expect(viewModel.repositories.map(\.fullName) == ["k/one", "k/two"])
    }

    @Test("追加読み込みの失敗の後に新しい検索を始めると、失敗の状態を残さない")
    func newSearchClearsLoadMoreFailure() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")])
        viewModel.loadMoreIfNeeded()
        await apiClient.waitForRequest(keyword: "swift", page: 2)
        await apiClient.respond(to: "swift", page: 2, with: .failure(.httpStatus(500)))
        await viewModel.loadMoreTask?.value

        viewModel.query = "kotlin"
        viewModel.search()

        #expect(viewModel.loadMorePhase == .idle)
        #expect(viewModel.phase == .loading)
    }

    @Test("追加読み込みの通信中に入力を空にすると、結果をクリアし、後から返った続きも反映しない")
    func clearingQueryDiscardsInFlightLoadMore() async {
        let viewModel = await makeViewModelShowingFirstPage([.fixture(fullName: "a/one")])
        viewModel.loadMoreIfNeeded()
        let inFlightTask = viewModel.loadMoreTask
        await apiClient.waitForRequest(keyword: "swift", page: 2)

        viewModel.query = ""
        await apiClient.respond(to: "swift", page: 2, totalCount: 100, with: .success([.fixture(fullName: "b/two")]))
        await inFlightTask?.value

        #expect(viewModel.repositories.isEmpty)
        #expect(viewModel.phase == .idle)
        #expect(viewModel.loadMorePhase == .idle)
    }
}

/// 検索のリクエストを、キーワードで待機・応答できるようにする
private extension StubAPIClient {
    func waitForRequest(keyword: String, page: Int = 1) async {
        await waitForRequest(RepositorySearchRequest(keyword: keyword, sort: .bestMatch, page: page))
    }

    /// - Parameter totalCount: 全件数。省略した場合は、このページの件数（次のページなし）
    func respond(to keyword: String, page: Int = 1, totalCount: Int? = nil, with result: Result<[Repository], APIError>) {
        respond(
            to: RepositorySearchRequest(keyword: keyword, sort: .bestMatch, page: page),
            with: result.map { RepositorySearchResponse(totalCount: totalCount ?? $0.count, items: $0) }
        )
    }

    /// 検索リクエストのキーワードを、受け取った順に並べたもの
    var requestedKeywords: [String] {
        let prefix = StubAPIClient.key(for: RepositorySearchRequest(keyword: "", sort: .bestMatch, page: 1)).prefix { $0 != "=" } + "="
        return requestedKeys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count).prefix { $0 != "&" }) }
    }
}
