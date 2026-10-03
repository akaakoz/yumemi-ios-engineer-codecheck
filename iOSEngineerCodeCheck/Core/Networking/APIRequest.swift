//
//  APIRequest.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// `APIClient` に渡すリクエスト定義。
protocol APIRequest: Sendable {
    associatedtype Response: Decodable & Sendable

    /// ホストからのパス（例: `/search/repositories`）
    var path: String { get }
    var queryItems: [URLQueryItem] { get }
}
