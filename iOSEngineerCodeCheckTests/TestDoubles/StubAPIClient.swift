//
//  StubAPIClient.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
@testable import iOSEngineerCodeCheck

/// 全 API で共通に使えるテスト用の `APIClient`。実際のネットワークには接続しない。
///
/// - `stub(_:with:)` で結果を登録したリクエストには、その結果をすぐに返す。
/// - 登録していないリクエストは、`respond(to:with:)` が呼ばれるまで待機する。
///   通信中の状態やレスポンス順序の逆転を `Task.sleep` に頼らず再現できる。
///
/// API を追加しても、このスタブにリクエストと結果を登録するだけでテストできる。
actor StubAPIClient: APIClientProtocol {

    private var stubbedResults: [String: Result<any Sendable, APIError>] = [:]
    private var pendingResponses: [String: CheckedContinuation<Result<any Sendable, APIError>, Never>] = [:]
    private var requestWaiters: [String: CheckedContinuation<Void, Never>] = [:]
    /// 受け取ったリクエストのキー（`key(for:)`）を受け取った順に並べたもの
    private(set) var requestedKeys: [String] = []

    init() {}

    init<Request: APIRequest>(stubbing request: Request, with result: Result<Request.Response, APIError>) {
        stubbedResults[Self.key(for: request)] = result.map { $0 }
    }

    /// リクエストを識別するキー（例: `/search/repositories?q=swift`）
    static func key(for request: some APIRequest) -> String {
        let query = request.queryItems.map { item in
            [item.name, item.value].compactMap { $0 }.joined(separator: "=")
        }
        return query.isEmpty ? request.path : request.path + "?" + query.joined(separator: "&")
    }

    func stub<Request: APIRequest>(_ request: Request, with result: Result<Request.Response, APIError>) {
        stubbedResults[Self.key(for: request)] = result.map { $0 }
    }

    func send<Request: APIRequest>(_ request: Request) async throws(APIError) -> Request.Response {
        let key = Self.key(for: request)
        requestedKeys.append(key)

        let result: Result<any Sendable, APIError>
        if let stubbedResult = stubbedResults[key] {
            result = stubbedResult
        } else {
            result = await withCheckedContinuation { continuation in
                pendingResponses[key] = continuation
                requestWaiters.removeValue(forKey: key)?.resume()
            }
        }

        let value = try result.get()
        guard let response = value as? Request.Response else {
            throw .unexpected(description: "\(key) に登録した結果の型が \(Request.Response.self) ではない")
        }
        return response
    }

    /// 指定したリクエストが届くまで待つ。
    func waitForRequest(_ request: some APIRequest) async {
        let key = Self.key(for: request)
        if pendingResponses[key] != nil {
            return
        }
        await withCheckedContinuation { continuation in
            requestWaiters[key] = continuation
        }
    }

    /// 待機中のリクエストに結果を返す。
    func respond<Request: APIRequest>(to request: Request, with result: Result<Request.Response, APIError>) {
        pendingResponses.removeValue(forKey: Self.key(for: request))?.resume(returning: result.map { $0 })
    }
}
