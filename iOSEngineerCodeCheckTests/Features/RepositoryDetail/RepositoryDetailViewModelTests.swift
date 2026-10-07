//
//  RepositoryDetailViewModelTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@MainActor
@Suite("RepositoryDetailViewModel")
struct RepositoryDetailViewModelTests {

    /// 端末の UserDefaults を使わないよう、ブックマークはインメモリの保存先に読み書きする
    private let bookmarkStorage = InMemoryBookmarkStorage()

    @Test("取得する前は loading になっている")
    func initialStateIsLoading() {
        let viewModel = RepositoryDetailViewModel(
            source: .remote(fullName: "apple/swift"),
            apiService: makeAPIService(result: .success(.fixture())),
            bookmarkService: BookmarkService(storage: bookmarkStorage)
        )

        #expect(viewModel.phase == .loading)
    }

    @Test("リポジトリ名で問い合わせ、取得した詳細で loaded になる")
    func loadsRepositoryDetail() async {
        let apiClient = StubAPIClient(stubbing: RepositoryDetailRequest(fullName: "apple/swift"), with: .success(.fixture(subscribersCount: 2400)))
        let viewModel = RepositoryDetailViewModel(
            source: .remote(fullName: "apple/swift"),
            apiService: RepositoryDetailAPIService(apiClient: apiClient),
            bookmarkService: BookmarkService(storage: bookmarkStorage)
        )

        viewModel.loadIfNeeded()
        await viewModel.loadTask?.value

        #expect(viewModel.phase == .loaded(.fixture(subscribersCount: 2400)))
        #expect(await apiClient.requestedKeys == ["/repos/apple/swift"])
    }

    @Test("取得に失敗した場合は failed になる")
    func loadFailure() async {
        let viewModel = RepositoryDetailViewModel(
            source: .remote(fullName: "apple/swift"),
            apiService: makeAPIService(result: .failure(.httpStatus(500))),
            bookmarkService: BookmarkService(storage: bookmarkStorage)
        )

        viewModel.loadIfNeeded()
        await viewModel.loadTask?.value

        #expect(viewModel.phase == .failed(.httpStatus(500)))
    }

    @Test("取得中に画面が表示し直されても、重ねて取得しない")
    func loadIfNeededDoesNotFetchTwiceWhileLoading() async {
        let apiClient = StubAPIClient()
        let request = RepositoryDetailRequest(fullName: "apple/swift")
        let viewModel = RepositoryDetailViewModel(source: .remote(fullName: "apple/swift"), apiService: RepositoryDetailAPIService(apiClient: apiClient), bookmarkService: BookmarkService(storage: bookmarkStorage))
        viewModel.loadIfNeeded()
        await apiClient.waitForRequest(request)

        viewModel.loadIfNeeded()
        await apiClient.respond(to: request, with: .success(.fixture()))
        await viewModel.loadTask?.value

        #expect(viewModel.phase == .loaded(.fixture()))
        #expect(await apiClient.requestedKeys == ["/repos/apple/swift"])
    }

    @Test("表示できた後に画面が表示し直されても、取得し直さず表示中の詳細を残す")
    func loadIfNeededKeepsLoadedDetail() async {
        let apiClient = StubAPIClient(stubbing: RepositoryDetailRequest(fullName: "apple/swift"), with: .success(.fixture()))
        let viewModel = RepositoryDetailViewModel(source: .remote(fullName: "apple/swift"), apiService: RepositoryDetailAPIService(apiClient: apiClient), bookmarkService: BookmarkService(storage: bookmarkStorage))
        viewModel.loadIfNeeded()
        await viewModel.loadTask?.value

        viewModel.loadIfNeeded()

        #expect(viewModel.phase == .loaded(.fixture()))
        #expect(await apiClient.requestedKeys == ["/repos/apple/swift"])
    }

    @Test("失敗した後は自動では取得し直さず、再読み込みで取得し直せる")
    func reloadAfterFailure() async {
        let apiClient = StubAPIClient()
        let request = RepositoryDetailRequest(fullName: "apple/swift")
        let viewModel = RepositoryDetailViewModel(source: .remote(fullName: "apple/swift"), apiService: RepositoryDetailAPIService(apiClient: apiClient), bookmarkService: BookmarkService(storage: bookmarkStorage))
        viewModel.loadIfNeeded()
        await apiClient.waitForRequest(request)
        await apiClient.respond(to: request, with: .failure(.network(.notConnectedToInternet)))
        await viewModel.loadTask?.value

        viewModel.loadIfNeeded()
        #expect(viewModel.phase == .failed(.network(.notConnectedToInternet)))
        #expect(await apiClient.requestedKeys.count == 1)

        viewModel.reload()
        #expect(viewModel.phase == .loading)
        await apiClient.waitForRequest(request)
        await apiClient.respond(to: request, with: .success(.fixture()))
        await viewModel.loadTask?.value

        #expect(viewModel.phase == .loaded(.fixture()))
    }

    @Test("失敗していないときに再読み込みしても、取得しない")
    func reloadDoesNothingUnlessFailed() async {
        let apiClient = StubAPIClient(stubbing: RepositoryDetailRequest(fullName: "apple/swift"), with: .success(.fixture()))
        let viewModel = RepositoryDetailViewModel(source: .remote(fullName: "apple/swift"), apiService: RepositoryDetailAPIService(apiClient: apiClient), bookmarkService: BookmarkService(storage: bookmarkStorage))
        viewModel.loadIfNeeded()
        await viewModel.loadTask?.value

        viewModel.reload()

        #expect(viewModel.phase == .loaded(.fixture()))
        #expect(await apiClient.requestedKeys.count == 1)
    }

    // MARK: - ブックマークから開いた場合

    @Test("ブックマークに保存している詳細を使う場合は、最初から loaded になる")
    func savedSourceIsLoadedImmediately() {
        let saved = RepositoryDetail.fixture(fullName: "apple/swift", stargazersCount: 1)
        let viewModel = RepositoryDetailViewModel(
            source: .saved(saved),
            apiService: makeAPIService(result: .success(.fixture())),
            bookmarkService: BookmarkService(storage: bookmarkStorage)
        )

        #expect(viewModel.phase == .loaded(saved))
        #expect(viewModel.loadedDetail == saved)
        #expect(viewModel.fullName == "apple/swift")
    }

    @Test("ブックマークに保存している詳細を使う場合は、リポジトリ API と通信しない")
    func savedSourceDoesNotFetch() async {
        let saved = RepositoryDetail.fixture(fullName: "apple/swift", stargazersCount: 1)
        let apiClient = StubAPIClient(stubbing: RepositoryDetailRequest(fullName: "apple/swift"), with: .success(.fixture(stargazersCount: 999)))
        let viewModel = RepositoryDetailViewModel(source: .saved(saved), apiService: RepositoryDetailAPIService(apiClient: apiClient), bookmarkService: BookmarkService(storage: bookmarkStorage))

        viewModel.loadIfNeeded()
        await viewModel.loadTask?.value

        #expect(viewModel.phase == .loaded(saved))
        #expect(await apiClient.requestedKeys.isEmpty)
    }

    // MARK: - ブックマーク

    /// Search タブから開き、詳細を表示できている状態の ViewModel
    private func makeLoadedRemoteViewModel(fullName: String = "apple/swift") async -> RepositoryDetailViewModel {
        let apiClient = StubAPIClient(stubbing: RepositoryDetailRequest(fullName: fullName), with: .success(.fixture(fullName: fullName)))
        let viewModel = RepositoryDetailViewModel(
            source: .remote(fullName: fullName),
            apiService: RepositoryDetailAPIService(apiClient: apiClient),
            bookmarkService: BookmarkService(storage: bookmarkStorage)
        )
        viewModel.loadIfNeeded()
        viewModel.loadBookmarkState()
        await viewModel.loadTask?.value
        return viewModel
    }

    @Test("表示されたときに、保存先から登録状態を読み込む")
    func loadsBookmarkState() async throws {
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "apple/swift")])
        let bookmarked = await makeLoadedRemoteViewModel()
        let notBookmarked = await makeLoadedRemoteViewModel(fullName: "yumemi/sample")

        #expect(bookmarked.isBookmarked)
        #expect(!notBookmarked.isBookmarked)
    }

    @Test("表示し直すと、もう一方のタブでの変更を登録状態に反映する")
    func reloadingBookmarkStateReflectsOtherTabChanges() async throws {
        let viewModel = await makeLoadedRemoteViewModel()
        #expect(!viewModel.isBookmarked)

        // もう一方のタブでの追加を想定して、保存先を直接書き換える
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "apple/swift")])
        viewModel.loadBookmarkState()

        #expect(viewModel.isBookmarked)
    }

    @Test("追加すると、表示できている詳細を末尾に保存して登録済みになる")
    func addSavesLoadedDetail() async throws {
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "a/one")])
        let viewModel = await makeLoadedRemoteViewModel()

        viewModel.addBookmark()

        #expect(viewModel.isBookmarked)
        #expect(bookmarkStorage.savedBookmarks == [.fixture(fullName: "a/one"), .fixture(fullName: "apple/swift")])
    }

    @Test("詳細を表示できるまでは、追加しない")
    func addDoesNothingBeforeLoaded() {
        let viewModel = RepositoryDetailViewModel(
            source: .remote(fullName: "apple/swift"),
            apiService: makeAPIService(result: .success(.fixture())),
            bookmarkService: BookmarkService(storage: bookmarkStorage)
        )

        viewModel.addBookmark()

        #expect(!viewModel.isBookmarked)
        #expect(bookmarkStorage.saveCallCount == 0)
    }

    @Test("ブックマークから開いた詳細を削除しても画面に残り、追加し直すと末尾に再登録される")
    func removeAndReAddFromSavedSource() throws {
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "apple/swift"), .fixture(fullName: "b/two")])
        let viewModel = RepositoryDetailViewModel(
            source: .saved(.fixture(fullName: "apple/swift")),
            apiService: makeAPIService(result: .success(.fixture())),
            bookmarkService: BookmarkService(storage: bookmarkStorage)
        )
        viewModel.loadBookmarkState()

        viewModel.removeBookmark()
        #expect(!viewModel.isBookmarked)
        #expect(viewModel.loadedDetail == .fixture(fullName: "apple/swift"))
        #expect(bookmarkStorage.savedBookmarks == [.fixture(fullName: "b/two")])

        viewModel.addBookmark()
        #expect(viewModel.isBookmarked)
        #expect(bookmarkStorage.savedBookmarks == [.fixture(fullName: "b/two"), .fixture(fullName: "apple/swift")])
    }

    @Test("もう一方のタブで追加済みのリポジトリを追加しても、重複して保存せず登録済みになる")
    func addDoesNotDuplicateBookmarkAddedInOtherTab() async throws {
        let viewModel = await makeLoadedRemoteViewModel()
        try bookmarkStorage.saveBookmarks([.fixture(fullName: "apple/swift")])
        let saveCountBefore = bookmarkStorage.saveCallCount

        viewModel.addBookmark()

        #expect(viewModel.isBookmarked)
        #expect(bookmarkStorage.saveCallCount == saveCountBefore)
    }

    @Test("保存に失敗した場合は登録状態を変えず、失敗を bookmarkStorageError として公開する")
    func saveFailureKeepsState() async {
        let viewModel = await makeLoadedRemoteViewModel()
        bookmarkStorage.saveError = .saveFailed(description: "disk full")

        viewModel.addBookmark()

        #expect(!viewModel.isBookmarked)
        #expect(viewModel.bookmarkStorageError == .saveFailed(description: "disk full"))
        #expect(viewModel.isShowingBookmarkStorageError)
    }

    @Test("保存先を読み込めない場合は失敗を公開し、表示を閉じるとクリアされる")
    func loadFailureIsExposedAndCanBeDismissed() async {
        bookmarkStorage.loadError = .loadFailed(description: "broken")
        let viewModel = await makeLoadedRemoteViewModel()

        #expect(!viewModel.isBookmarked)
        #expect(viewModel.bookmarkStorageError == .loadFailed(description: "broken"))

        viewModel.isShowingBookmarkStorageError = false

        #expect(viewModel.bookmarkStorageError == nil)
    }

    @Test(
        "失敗の原因に応じた文言を返す",
        arguments: [
            (APIError.network(.notConnectedToInternet), "インターネットに接続されていません。接続を確認してから再度お試しください。"),
            (APIError.httpStatus(403), "情報を取得できる回数の上限に達しました。しばらく時間をおいて再度お試しください。"),
            (APIError.httpStatus(429), "情報を取得できる回数の上限に達しました。しばらく時間をおいて再度お試しください。"),
            (APIError.httpStatus(404), "リポジトリが見つかりませんでした。削除されたか、非公開になった可能性があります。"),
            (APIError.httpStatus(500), "リポジトリの情報を取得できませんでした。時間をおいて再度お試しください。"),
            (APIError.decoding(description: "broken"), "リポジトリの情報を取得できませんでした。時間をおいて再度お試しください。"),
        ]
    )
    func failureMessageDependsOnError(error: APIError, expectedMessage: String) {
        #expect(RepositoryDetailViewModel.failureMessage(for: error) == expectedMessage)
    }

    /// リポジトリ API（apple/swift）に、指定した結果を返すサービス
    private func makeAPIService(result: Result<RepositoryDetail, APIError>) -> RepositoryDetailAPIService {
        RepositoryDetailAPIService(apiClient: StubAPIClient(stubbing: RepositoryDetailRequest(fullName: "apple/swift"), with: result))
    }
}
