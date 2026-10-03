//
//  RepositorySearchAPIServiceTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@Suite("RepositorySearchAPIService")
struct RepositorySearchAPIServiceTests {

    @Test("検索リクエストはキーワードを q パラメータとして送る")
    func requestContainsKeyword() throws {
        let urlRequest = try APIClient(baseURL: APIClient.gitHubBaseURL).makeURLRequest(for: RepositorySearchRequest(keyword: "swift ui"))

        #expect(urlRequest.url?.absoluteString == "https://api.github.com/search/repositories?q=swift%20ui")
    }

    @Test("GitHub API 形式のレスポンスを Repository の配列に変換する")
    func searchDecodesGitHubResponse() async throws {
        let service = makeService(json: """
            {
              "total_count": 2,
              "items": [
                {
                  "full_name": "apple/swift",
                  "language": "C++",
                  "stargazers_count": 67000,
                  "watchers_count": 67001,
                  "forks_count": 10000,
                  "open_issues_count": 7000,
                  "owner": { "avatar_url": "https://avatars.githubusercontent.com/u/10639145" }
                },
                {
                  "full_name": "example/no-language",
                  "language": null,
                  "stargazers_count": 0,
                  "watchers_count": 0,
                  "forks_count": 0,
                  "open_issues_count": 0,
                  "owner": { "avatar_url": "https://avatars.githubusercontent.com/u/1" }
                }
              ]
            }
            """)

        let repositories = try await service.searchRepositories(keyword: "swift")

        #expect(repositories.map(\.fullName) == ["apple/swift", "example/no-language"])
        #expect(repositories[0].stargazersCount == 67000)
        #expect(repositories[0].owner.avatarUrl == "https://avatars.githubusercontent.com/u/10639145")
        #expect(repositories[1].language == nil)
    }

    @Test("結果 0 件の場合は空配列を返す")
    func searchReturnsEmptyArray() async throws {
        let service = makeService(json: #"{"total_count": 0, "items": []}"#)

        let repositories = try await service.searchRepositories(keyword: "no-hit")

        #expect(repositories.isEmpty)
    }

    @Test("必須項目が欠けたレスポンスは decoding エラーになる")
    func searchThrowsForMissingField() async {
        let service = makeService(json: #"{"items": [{"full_name": "apple/swift"}]}"#)

        let error = await #expect(throws: APIError.self) {
            try await service.searchRepositories(keyword: "swift")
        }
        guard case .decoding = error else {
            Issue.record("decoding エラーを期待したが \(String(describing: error)) だった")
            return
        }
    }

    private func makeService(json: String) -> RepositorySearchAPIService {
        RepositorySearchAPIService(apiClient: APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession.json(json)))
    }
}
