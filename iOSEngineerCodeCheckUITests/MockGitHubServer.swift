//
//  MockGitHubServer.swift
//  iOSEngineerCodeCheckUITests
//

import Foundation
import Network
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
    }

    private let listener: NWListener
    private let behavior: Behavior
    private let queue = DispatchQueue(label: "MockGitHubServer")

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
        listener.newConnectionHandler = { [behavior, queue] connection in
            Self.handle(connection, behavior: behavior, queue: queue)
        }
        listener.start(queue: queue)
        testCase.wait(for: [ready], timeout: 5)

        let port = try XCTUnwrap(listener.port, "MockGitHubServer のポートを取得できません")
        return "http://localhost:\(port.rawValue)"
    }

    func stop() {
        listener.cancel()
    }

    private static func handle(_ connection: NWConnection, behavior: Behavior, queue: DispatchQueue) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, _ in
            let requestLine = data.flatMap { String(data: $0, encoding: .utf8) }?
                .components(separatedBy: "\r\n").first ?? ""
            let response = makeResponse(requestLine: requestLine, behavior: behavior)
            let send: @Sendable () -> Void = {
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
            if behavior == .slowSuccess {
                queue.asyncAfter(deadline: .now() + 2, execute: send)
            } else {
                send()
            }
        }
    }

    /// - Parameter requestLine: 例 `GET /search/repositories?q=swift HTTP/1.1`
    private static func makeResponse(requestLine: String, behavior: Behavior) -> Data {
        let path = requestLine.split(separator: " ").dropFirst().first.map(String.init) ?? ""
        guard path.hasPrefix("/search/repositories") else {
            return httpResponse(status: "404 Not Found", body: #"{"message": "Not Found"}"#)
        }
        switch behavior {
        case .success, .slowSuccess:
            return httpResponse(status: "200 OK", body: searchResultsJSON)
        case .noResults:
            return httpResponse(status: "200 OK", body: #"{"total_count": 0, "incomplete_results": false, "items": []}"#)
        case .serverError:
            return httpResponse(status: "500 Internal Server Error", body: #"{"message": "Server Error"}"#)
        }
    }

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

    /// GitHub の `GET /search/repositories` と同じ形式（snake_case）の固定レスポンス
    private static let searchResultsJSON = """
        {
          "total_count": 2,
          "items": [
            {
              "full_name": "apple/swift",
              "language": "C++",
              "stargazers_count": 67000,
              "watchers_count": 2400,
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
