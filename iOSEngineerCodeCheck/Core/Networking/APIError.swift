//
//  APIError.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// 通信処理で発生しうる失敗。`APIClient` はどの失敗もこの型に変換して throw する。
enum APIError: Error, Equatable, Sendable {
    /// リクエストの URL を組み立てられなかった
    case invalidRequest
    /// 通信そのものが失敗した（オフライン・タイムアウトなど）
    case network(URLError.Code)
    /// HTTP 以外のレスポンスが返ってきた
    case invalidResponse
    case httpStatus(Int)
    case decoding(description: String)
    /// 上記に分類できない失敗
    case unexpected(description: String)
}
