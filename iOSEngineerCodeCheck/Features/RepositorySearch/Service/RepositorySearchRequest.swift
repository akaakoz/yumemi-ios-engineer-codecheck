//
//  RepositorySearchRequest.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct RepositorySearchRequest: APIRequest {
    typealias Response = RepositorySearchResponse

    let keyword: String

    var path: String { "/search/repositories" }
    var queryItems: [URLQueryItem] { [URLQueryItem(name: "q", value: keyword)] }
}
