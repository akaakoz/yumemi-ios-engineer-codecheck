//
//  RepositoryDetailAPIServiceTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@Suite("RepositoryDetailAPIService")
struct RepositoryDetailAPIServiceTests {

    @Test("リポジトリ API のパスに、owner/name をそのまま使う")
    func requestPathUsesFullName() throws {
        let urlRequest = try APIClient(baseURL: APIClient.gitHubBaseURL).makeURLRequest(for: RepositoryDetailRequest(fullName: "apple/swift"))

        #expect(urlRequest.url?.absoluteString == "https://api.github.com/repos/apple/swift")
    }

    @Test("リポジトリ API のレスポンスを RepositoryDetail に変換し、Watch 数には subscribers_count を使う")
    func decodesRepositoryDetail() async throws {
        let service = makeService(json: """
            {
              "full_name": "apple/swift",
              "description": "The Swift Programming Language",
              "language": null,
              "stargazers_count": 67000,
              "watchers_count": 67000,
              "subscribers_count": 2400,
              "forks_count": 10000,
              "open_issues_count": 7000,
              "pushed_at": "2024-01-02T03:04:05Z",
              "owner": { "avatar_url": "https://avatars.githubusercontent.com/u/10639145" }
            }
            """)

        let detail = try await service.fetchRepositoryDetail(fullName: "apple/swift")

        #expect(detail.fullName == "apple/swift")
        #expect(detail.description == "The Swift Programming Language")
        #expect(detail.pushedAt == ISO8601DateFormatter().date(from: "2024-01-02T03:04:05Z"))
        #expect(detail.language == nil)
        #expect(detail.stargazersCount == 67000)
        #expect(detail.subscribersCount == 2400)
        #expect(detail.forksCount == 10000)
        #expect(detail.openIssuesCount == 7000)
        #expect(detail.owner.avatarURLString == "https://avatars.githubusercontent.com/u/10639145")
    }

    @Test("必須項目（stargazers_count など）が無いレスポンスは decoding エラーになる")
    func throwsWhenRequiredFieldIsMissing() async {
        let service = makeService(json: #"{"full_name": "apple/swift", "subscribers_count": 2400}"#)

        let error = await #expect(throws: APIError.self) {
            try await service.fetchRepositoryDetail(fullName: "apple/swift")
        }
        guard case .decoding = error else {
            Issue.record("decoding エラーを期待したが \(String(describing: error)) だった")
            return
        }
    }

    @Test("リポジトリが見つからない場合は httpStatus(404) になる")
    func throwsHTTPStatusForNotFound() async {
        let service = makeService(json: #"{"message": "Not Found"}"#, statusCode: 404)

        await #expect(throws: APIError.httpStatus(404)) {
            try await service.fetchRepositoryDetail(fullName: "unknown/repository")
        }
    }

    private func makeService(json: String, statusCode: Int = 200) -> RepositoryDetailAPIService {
        RepositoryDetailAPIService(apiClient: APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession.json(json, statusCode: statusCode)))
    }
}
