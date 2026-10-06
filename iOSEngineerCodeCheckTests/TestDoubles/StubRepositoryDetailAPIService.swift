//
//  StubRepositoryDetailAPIService.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
@testable import iOSEngineerCodeCheck

/// 決まった詳細（または失敗）を返し、問い合わせたリポジトリ名を記録するスタブ。
actor StubRepositoryDetailAPIService: RepositoryDetailAPIServiceProtocol {

    private let result: Result<RepositoryDetail, APIError>
    private(set) var requestedFullNames: [String] = []

    init(result: Result<RepositoryDetail, APIError>) {
        self.result = result
    }

    func fetchRepositoryDetail(fullName: String) async throws(APIError) -> RepositoryDetail {
        requestedFullNames.append(fullName)
        return try result.get()
    }
}
