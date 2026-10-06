//
//  RepositorySearchAPIServiceProtocol.swift
//  iOSEngineerCodeCheck
//

import Foundation

protocol RepositorySearchAPIServiceProtocol: Sendable {
    /// - Parameters:
    ///   - keyword: 前後の空白を取り除いた、空でない検索キーワード
    ///   - page: 1 始まりのページ番号
    /// - Returns: 指定したページの検索結果。0 件の場合は空配列
    func searchRepositories(keyword: String, page: Int) async throws(APIError) -> RepositorySearchPage
}
