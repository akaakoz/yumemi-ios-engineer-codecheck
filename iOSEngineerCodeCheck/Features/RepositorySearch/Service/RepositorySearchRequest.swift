//
//  RepositorySearchRequest.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct RepositorySearchRequest: APIRequest {
    typealias Response = RepositorySearchResponse

    /// 1 ページあたりの件数（GitHub の既定値）
    static let perPage = 30

    let keyword: String
    /// 1 始まりのページ番号
    let page: Int

    var path: String { "/search/repositories" }
    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "per_page", value: String(Self.perPage)),
            URLQueryItem(name: "page", value: String(page)),
        ]
    }
}
