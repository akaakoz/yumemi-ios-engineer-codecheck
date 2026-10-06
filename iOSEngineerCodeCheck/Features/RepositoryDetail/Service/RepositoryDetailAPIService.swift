//
//  RepositoryDetailAPIService.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct RepositoryDetailAPIService: RepositoryDetailAPIServiceProtocol {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchRepositoryDetail(fullName: String) async throws(APIError) -> RepositoryDetail {
        try await apiClient.send(RepositoryDetailRequest(fullName: fullName))
    }
}
