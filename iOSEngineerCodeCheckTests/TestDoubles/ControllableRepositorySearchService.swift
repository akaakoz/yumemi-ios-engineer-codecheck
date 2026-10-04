//
//  ControllableRepositorySearchService.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
@testable import iOSEngineerCodeCheck

/// 検索結果を返すタイミングと内容をテストから制御できるスタブ。
///
/// `searchRepositories` は `respond(to:with:)` が呼ばれるまで待機するため、
/// 通信中の状態やレスポンス順序の逆転を `Task.sleep` に頼らず再現できる。
actor ControllableRepositorySearchService: RepositorySearchAPIServiceProtocol {

    private var pendingResponses: [String: CheckedContinuation<Result<[Repository], APIError>, Never>] = [:]
    private var requestWaiters: [String: CheckedContinuation<Void, Never>] = [:]
    private(set) var requestedKeywords: [String] = []

    func searchRepositories(keyword: String) async throws(APIError) -> [Repository] {
        requestedKeywords.append(keyword)
        let result = await withCheckedContinuation { continuation in
            pendingResponses[keyword] = continuation
            requestWaiters.removeValue(forKey: keyword)?.resume()
        }
        return try result.get()
    }

    func waitForRequest(keyword: String) async {
        if pendingResponses[keyword] != nil {
            return
        }
        await withCheckedContinuation { continuation in
            requestWaiters[keyword] = continuation
        }
    }

    func respond(to keyword: String, with result: Result<[Repository], APIError>) {
        pendingResponses.removeValue(forKey: keyword)?.resume(returning: result)
    }
}
