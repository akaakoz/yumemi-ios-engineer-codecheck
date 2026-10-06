//
//  RepositorySearchAPIServiceTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@Suite("RepositorySearchAPIService")
struct RepositorySearchAPIServiceTests {

    @Test("検索リクエストはキーワード・1 ページあたりの件数・ページ番号を送る")
    func requestContainsKeywordAndPage() throws {
        let urlRequest = try APIClient(baseURL: APIClient.gitHubBaseURL).makeURLRequest(for: RepositorySearchRequest(keyword: "swift ui", page: 2))

        #expect(urlRequest.url?.absoluteString == "https://api.github.com/search/repositories?q=swift%20ui&per_page=30&page=2")
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

        let repositories = try await service.searchRepositories(keyword: "swift", page: 1).repositories

        #expect(repositories.map(\.fullName) == ["apple/swift", "example/no-language"])
        #expect(repositories[0].stargazersCount == 67000)
        #expect(repositories[0].owner.avatarURLString == "https://avatars.githubusercontent.com/u/10639145")
        #expect(repositories[1].language == nil)
    }

    @Test("結果 0 件の場合は空配列を返す")
    func searchReturnsEmptyArray() async throws {
        let service = makeService(json: #"{"total_count": 0, "items": []}"#)

        let page = try await service.searchRepositories(keyword: "no-hit", page: 1)

        #expect(page.repositories.isEmpty)
        #expect(!page.hasNextPage)
    }

    @Test(
        "全件数と取得できる上限（1,000 件）から、次のページがあるかを判断する",
        arguments: [
            // (全件数, ページ番号, そのページの件数, 次のページがあるか)
            (100, 1, 30, true),
            (60, 2, 30, false),
            (31, 1, 30, true),
            (30, 1, 30, false),
            (5, 1, 5, false),
            // 全件数が 1,000 件を超えても、取得できるのは 1,000 件（33 ページ目の途中）まで
            (5000, 33, 30, true),
            (5000, 34, 10, false),
            // 全件数が残っていても、空のページが返ったらそれ以上は読み込まない
            (100, 2, 0, false),
        ]
    )
    func hasNextPage(totalCount: Int, page: Int, itemCount: Int, expected: Bool) async throws {
        let service = makeService(json: Self.searchResponseJSON(totalCount: totalCount, itemCount: itemCount))

        let result = try await service.searchRepositories(keyword: "swift", page: page)

        #expect(result.repositories.count == itemCount)
        #expect(result.hasNextPage == expected)
    }

    @Test("必須項目が欠けたレスポンスは decoding エラーになる")
    func searchThrowsForMissingField() async {
        let service = makeService(json: #"{"items": [{"full_name": "apple/swift"}]}"#)

        let error = await #expect(throws: APIError.self) {
            try await service.searchRepositories(keyword: "swift", page: 1)
        }
        guard case .decoding = error else {
            Issue.record("decoding エラーを期待したが \(String(describing: error)) だった")
            return
        }
    }

    /// 指定した件数のリポジトリを含む検索 API のレスポンス
    private static func searchResponseJSON(totalCount: Int, itemCount: Int) -> String {
        let items = (0..<itemCount).map { index in
            """
            {"full_name": "owner/repo\(index)", "language": null, "stargazers_count": 0, "watchers_count": 0, \
            "forks_count": 0, "open_issues_count": 0, "owner": {"avatar_url": "https://avatars.githubusercontent.com/u/1"}}
            """
        }
        return #"{"total_count": \#(totalCount), "items": [\#(items.joined(separator: ","))]}"#
    }

    private func makeService(json: String) -> RepositorySearchAPIService {
        RepositorySearchAPIService(apiClient: APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession.json(json)))
    }
}
