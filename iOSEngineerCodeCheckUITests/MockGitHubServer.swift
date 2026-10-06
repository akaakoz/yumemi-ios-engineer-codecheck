//
//  MockGitHubServer.swift
//  iOSEngineerCodeCheckUITests
//

import Foundation
import Network
import Synchronization
import XCTest

/// UI テストのプロセス内で動く、GitHub API の代わりのローカル HTTP サーバー。
///
/// アプリは起動引数 `-APIBaseURL http://localhost:<port>` でこのサーバーに接続するため、
/// アプリ側にスタブを用意しなくても、実際のネットワークに依存せずに検索の成功・失敗を再現できる。
final class MockGitHubServer: Sendable {

    enum Behavior: Equatable, Sendable {
        /// 固定の検索結果（`searchResultsJSON`）を返す
        case success
        /// 固定の検索結果を 2 秒遅れて返す（検索中の状態を確認するため）
        case slowSuccess
        /// 結果 0 件を返す
        case noResults
        /// 検索 API が 500 を返す
        case serverError
        /// 検索は成功し、リポジトリ API（詳細の取得）だけが 500 を返す
        case detailServerError
        /// 検索結果を 2 ページに分けて返す（`pagedSearchResultsJSON`）。
        /// 2 ページ目は 2 秒遅れて返す（追加読み込み中の状態を確認するため）
        case paginated
        /// `paginated` と同じ 2 ページを返すが、2 ページ目の最初の要求だけ 500 を返す（再試行を確認するため）
        case paginatedNextPageFailsOnce
    }

    private let listener: NWListener
    private let behavior: Behavior
    private let queue = DispatchQueue(label: "MockGitHubServer")
    /// `paginatedNextPageFailsOnce` で、2 ページ目の要求に一度失敗を返したか。接続をまたいで共有する
    private let hasFailedNextPage = Mutex(false)

    init(behavior: Behavior) throws {
        self.behavior = behavior
        // 他のテストやプロセスと衝突しないよう、空いているポートを OS に選ばせる
        listener = try NWListener(using: .tcp, on: .any)
    }

    /// サーバーを起動し、アプリに渡す接続先（`http://localhost:<port>`）を返す。
    func start(testCase: XCTestCase) throws -> String {
        let ready = testCase.expectation(description: "MockGitHubServer is ready")
        ready.assertForOverFulfill = false
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                ready.fulfill()
            }
        }
        listener.newConnectionHandler = { [self] connection in
            handle(connection)
        }
        listener.start(queue: queue)
        testCase.wait(for: [ready], timeout: 5)

        let port = try XCTUnwrap(listener.port, "MockGitHubServer のポートを取得できません")
        return "http://localhost:\(port.rawValue)"
    }

    func stop() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [self] data, _, _, _ in
            let requestLine = data.flatMap { String(data: $0, encoding: .utf8) }?
                .components(separatedBy: "\r\n").first ?? ""
            let path = requestLine.split(separator: " ").dropFirst().first.map(String.init) ?? ""
            let response = makeResponse(path: path)
            let send: @Sendable () -> Void = {
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
            if let delay = responseDelay(path: path) {
                queue.asyncAfter(deadline: .now() + delay, execute: send)
            } else {
                send()
            }
        }
    }

    /// 応答を遅らせる秒数。遅らせない場合は `nil`
    private func responseDelay(path: String) -> TimeInterval? {
        switch behavior {
        case .slowSuccess:
            return 2
        case .paginated where Self.searchPage(path: path) >= 2:
            return 2
        case .success, .noResults, .serverError, .detailServerError, .paginated, .paginatedNextPageFailsOnce:
            return nil
        }
    }

    /// - Parameter path: 例 `/search/repositories?q=swift&per_page=30&page=1`
    private func makeResponse(path: String) -> Data {
        if path.hasPrefix("/repos/") {
            return Self.makeRepositoryDetailResponse(path: path, behavior: behavior)
        }
        guard path.hasPrefix("/search/repositories") else {
            return Self.httpResponse(status: "404 Not Found", body: #"{"message": "Not Found"}"#)
        }
        return makeSearchResponse(page: Self.searchPage(path: path))
    }

    private func makeSearchResponse(page: Int) -> Data {
        switch behavior {
        case .success, .slowSuccess, .detailServerError:
            return Self.httpResponse(status: "200 OK", body: Self.searchResultsJSON)
        case .noResults:
            return Self.httpResponse(status: "200 OK", body: #"{"total_count": 0, "incomplete_results": false, "items": []}"#)
        case .serverError:
            return Self.httpResponse(status: "500 Internal Server Error", body: #"{"message": "Server Error"}"#)
        case .paginated:
            return Self.httpResponse(status: "200 OK", body: Self.pagedSearchResultsJSON(page: page))
        case .paginatedNextPageFailsOnce:
            let shouldFail = page >= 2 && hasFailedNextPage.withLock { hasFailed in
                defer { hasFailed = true }
                return !hasFailed
            }
            if shouldFail {
                return Self.httpResponse(status: "500 Internal Server Error", body: #"{"message": "Server Error"}"#)
            }
            return Self.httpResponse(status: "200 OK", body: Self.pagedSearchResultsJSON(page: page))
        }
    }

    /// 検索のリクエストのページ番号。指定が無い場合は 1
    private static func searchPage(path: String) -> Int {
        let pageValue = URLComponents(string: path)?.queryItems?.first { $0.name == "page" }?.value
        return pageValue.flatMap(Int.init) ?? 1
    }

    /// `GET /repos/{owner}/{repo}`。実際の Watch 数（`subscribers_count`）は、検索結果の `watchers_count`（Star 数と同じ値）とは違う値にする
    private static func makeRepositoryDetailResponse(path: String, behavior: Behavior) -> Data {
        switch behavior {
        case .serverError, .detailServerError:
            return httpResponse(status: "500 Internal Server Error", body: #"{"message": "Server Error"}"#)
        case .success, .slowSuccess, .noResults, .paginated, .paginatedNextPageFailsOnce:
            guard let body = repositoryDetailJSONs[path] else {
                return httpResponse(status: "404 Not Found", body: #"{"message": "Not Found"}"#)
            }
            return httpResponse(status: "200 OK", body: body)
        }
    }

    /// リポジトリ API のパスごとの固定レスポンス
    private static let repositoryDetailJSONs = [
        "/repos/apple/swift": """
            {
              "full_name": "apple/swift",
              "language": "C++",
              "stargazers_count": 67000,
              "watchers_count": 67000,
              "subscribers_count": 2400,
              "forks_count": 10000,
              "open_issues_count": 7000,
              "owner": { "avatar_url": "https://example.invalid/avatar.png" }
            }
            """,
        "/repos/yumemi/sample": """
            {
              "full_name": "yumemi/sample",
              "language": null,
              "stargazers_count": 1,
              "watchers_count": 1,
              "subscribers_count": 1,
              "forks_count": 0,
              "open_issues_count": 0,
              "owner": { "avatar_url": "https://example.invalid/avatar.png" }
            }
            """,
    ]

    private static func httpResponse(status: String, body: String) -> Data {
        let bodyData = Data(body.utf8)
        let header = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(bodyData.count)",
            "Connection: close",
            "",
            "",
        ].joined(separator: "\r\n")
        return Data(header.utf8) + bodyData
    }

    /// 2 ページに分かれる検索結果の全件数。1 ページ目に 30 件、2 ページ目に 1 件を返す
    static let pagedSearchTotalCount = 31

    /// `paginated` の検索結果。`paged/repo1` 〜 `paged/repo31` を 1 ページ 30 件ずつ返す
    private static func pagedSearchResultsJSON(page: Int) -> String {
        let perPage = 30
        let first = (page - 1) * perPage + 1
        let last = min(page * perPage, pagedSearchTotalCount)
        let items = first > last ? [] : (first...last).map { number in
            """
            {"full_name": "paged/repo\(number)", "language": "Swift", "stargazers_count": \(number), "watchers_count": \(number), \
            "forks_count": 0, "open_issues_count": 0, "owner": {"avatar_url": "https://example.invalid/avatar.png"}}
            """
        }
        return #"{"total_count": \#(pagedSearchTotalCount), "incomplete_results": false, "items": [\#(items.joined(separator: ","))]}"#
    }

    /// GitHub の `GET /search/repositories` と同じ形式（snake_case）の固定レスポンス
    private static let searchResultsJSON = """
        {
          "total_count": 2,
          "items": [
            {
              "full_name": "apple/swift",
              "language": "C++",
              "stargazers_count": 67000,
              "watchers_count": 67000,
              "forks_count": 10000,
              "open_issues_count": 7000,
              "owner": { "avatar_url": "https://example.invalid/avatar.png" }
            },
            {
              "full_name": "yumemi/sample",
              "language": null,
              "stargazers_count": 1,
              "watchers_count": 1,
              "forks_count": 0,
              "open_issues_count": 0,
              "owner": { "avatar_url": "https://example.invalid/avatar.png" }
            }
          ]
        }
        """
}
