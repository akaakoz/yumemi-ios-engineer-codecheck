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

    @Test("取得する前は loading になっている")
    func initialStateIsLoading() {
        let viewModel = RepositoryDetailViewModel(
            source: .remote(fullName: "apple/swift"),
            apiService: makeAPIService(result: .success(.fixture()))
        )

        #expect(viewModel.phase == .loading)
    }

    @Test("リポジトリ名で問い合わせ、取得した詳細で loaded になる")
    func loadsRepositoryDetail() async {
        let apiClient = StubAPIClient(stubbing: RepositoryDetailRequest(fullName: "apple/swift"), with: .success(.fixture(subscribersCount: 2400)))
        let viewModel = RepositoryDetailViewModel(
            source: .remote(fullName: "apple/swift"),
            apiService: RepositoryDetailAPIService(apiClient: apiClient)
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
            apiService: makeAPIService(result: .failure(.httpStatus(500)))
        )

        viewModel.loadIfNeeded()
        await viewModel.loadTask?.value

        #expect(viewModel.phase == .failed(.httpStatus(500)))
    }

    @Test("取得中に画面が表示し直されても、重ねて取得しない")
    func loadIfNeededDoesNotFetchTwiceWhileLoading() async {
        let apiClient = StubAPIClient()
        let request = RepositoryDetailRequest(fullName: "apple/swift")
        let viewModel = RepositoryDetailViewModel(source: .remote(fullName: "apple/swift"), apiService: RepositoryDetailAPIService(apiClient: apiClient))
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
        let viewModel = RepositoryDetailViewModel(source: .remote(fullName: "apple/swift"), apiService: RepositoryDetailAPIService(apiClient: apiClient))
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
        let viewModel = RepositoryDetailViewModel(source: .remote(fullName: "apple/swift"), apiService: RepositoryDetailAPIService(apiClient: apiClient))
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
        let viewModel = RepositoryDetailViewModel(source: .remote(fullName: "apple/swift"), apiService: RepositoryDetailAPIService(apiClient: apiClient))
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
            apiService: makeAPIService(result: .success(.fixture()))
        )

        #expect(viewModel.phase == .loaded(saved))
        #expect(viewModel.loadedDetail == saved)
        #expect(viewModel.fullName == "apple/swift")
    }

    @Test("ブックマークに保存している詳細を使う場合は、リポジトリ API と通信しない")
    func savedSourceDoesNotFetch() async {
        let saved = RepositoryDetail.fixture(fullName: "apple/swift", stargazersCount: 1)
        let apiClient = StubAPIClient(stubbing: RepositoryDetailRequest(fullName: "apple/swift"), with: .success(.fixture(stargazersCount: 999)))
        let viewModel = RepositoryDetailViewModel(source: .saved(saved), apiService: RepositoryDetailAPIService(apiClient: apiClient))

        viewModel.loadIfNeeded()
        await viewModel.loadTask?.value

        #expect(viewModel.phase == .loaded(saved))
        #expect(await apiClient.requestedKeys.isEmpty)
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
