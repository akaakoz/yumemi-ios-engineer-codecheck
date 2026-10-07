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
    let sort: RepositorySearchSort
    /// 1 始まりのページ番号
    let page: Int

    var path: String { "/search/repositories" }
    var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: "q", value: keyword)]
        if let sortValue = sort.queryValue {
            items += [
                URLQueryItem(name: "sort", value: sortValue),
                URLQueryItem(name: "order", value: "desc"),
            ]
        }
        return items + [
            URLQueryItem(name: "per_page", value: String(Self.perPage)),
            URLQueryItem(name: "page", value: String(page)),
        ]
    }
}
