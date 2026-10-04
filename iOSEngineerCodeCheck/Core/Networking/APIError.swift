//
//  APIError.swift
//  iOSEngineerCodeCheck
//

import Foundation

enum APIError: Error, Equatable, Sendable {
    case invalidRequest
    case network(URLError.Code)
    /// HTTP 以外のレスポンスが返ってきた
    case invalidResponse
    case httpStatus(Int)
    case decoding(description: String)
    case unexpected(description: String)
}
