//
//  NetworkSession.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// 本番では `URLSession` を使い、テストではスタブに差し替えて実際のネットワークに依存せず検証する。
protocol NetworkSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}
