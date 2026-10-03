//
//  RepositorySearchResponse.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// `GET /search/repositories` のレスポンスのうち、アプリで使う部分。
struct RepositorySearchResponse: Decodable, Sendable {
    let items: [Repository]
}
