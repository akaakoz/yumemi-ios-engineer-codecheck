//
//  RepositoryDetailRequest.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct RepositoryDetailRequest: APIRequest {
    typealias Response = RepositoryDetail

    /// "owner/name" の形式のリポジトリ名
    let fullName: String

    var path: String { "/repos/\(fullName)" }
    var queryItems: [URLQueryItem] { [] }
}
