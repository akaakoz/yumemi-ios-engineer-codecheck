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
            apiService: StubRepositoryDetailAPIService(result: .success(.fixture()))
        )

        #expect(viewModel.phase == .loading)
    }

    @Test("リポジトリ名で問い合わせ、取得した詳細で loaded になる")
    func loadsRepositoryDetail() async {
        let service = StubRepositoryDetailAPIService(result: .success(.fixture(subscribersCount: 2400)))
        let viewModel = RepositoryDetailViewModel(source: .remote(fullName: "apple/swift"), apiService: service)

        await viewModel.loadRepositoryDetail()

        #expect(viewModel.phase == .loaded(.fixture(subscribersCount: 2400)))
        #expect(await service.requestedFullNames == ["apple/swift"])
    }

    @Test("取得に失敗した場合は failed になる")
    func loadFailure() async {
        let viewModel = RepositoryDetailViewModel(
            source: .remote(fullName: "apple/swift"),
            apiService: StubRepositoryDetailAPIService(result: .failure(.httpStatus(500)))
        )

        await viewModel.loadRepositoryDetail()

        #expect(viewModel.phase == .failed(.httpStatus(500)))
    }

    // MARK: - ブックマークから開いた場合

    @Test("ブックマークに保存している詳細を使う場合は、最初から loaded になる")
    func savedSourceIsLoadedImmediately() {
        let saved = RepositoryDetail.fixture(fullName: "apple/swift", stargazersCount: 1)
        let viewModel = RepositoryDetailViewModel(
            source: .saved(saved),
            apiService: StubRepositoryDetailAPIService(result: .success(.fixture()))
        )

        #expect(viewModel.phase == .loaded(saved))
        #expect(viewModel.loadedDetail == saved)
        #expect(viewModel.fullName == "apple/swift")
    }

    @Test("ブックマークに保存している詳細を使う場合は、リポジトリ API と通信しない")
    func savedSourceDoesNotFetch() async {
        let saved = RepositoryDetail.fixture(fullName: "apple/swift", stargazersCount: 1)
        let service = StubRepositoryDetailAPIService(result: .success(.fixture(stargazersCount: 999)))
        let viewModel = RepositoryDetailViewModel(source: .saved(saved), apiService: service)

        await viewModel.loadRepositoryDetail()

        #expect(viewModel.phase == .loaded(saved))
        #expect(await service.requestedFullNames.isEmpty)
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
}
