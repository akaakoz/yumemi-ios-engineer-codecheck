//
//  RepositoryDetailAPIServiceProtocol.swift
//  iOSEngineerCodeCheck
//

import Foundation

protocol RepositoryDetailAPIServiceProtocol: Sendable {
    /// - Parameter fullName: "owner/name" の形式のリポジトリ名
    func fetchRepositoryDetail(fullName: String) async throws(APIError) -> RepositoryDetail
}
