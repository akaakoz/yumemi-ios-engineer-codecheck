//
//  RepositorySearchAPIServiceProtocol.swift
//  iOSEngineerCodeCheck
//

import Foundation

protocol RepositorySearchAPIServiceProtocol: Sendable {
    /// - Parameter keyword: 前後の空白を取り除いた、空でない検索キーワード
    /// - Returns: 検索結果。0 件の場合は空配列
    func searchRepositories(keyword: String) async throws(APIError) -> [Repository]
}
