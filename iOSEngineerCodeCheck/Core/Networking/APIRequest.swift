//
//  APIRequest.swift
//  iOSEngineerCodeCheck
//

import Foundation

protocol APIRequest: Sendable {
    associatedtype Response: Decodable & Sendable

    /// ホストからのパス（例: `/search/repositories`）
    var path: String { get }
    var queryItems: [URLQueryItem] { get }
}
