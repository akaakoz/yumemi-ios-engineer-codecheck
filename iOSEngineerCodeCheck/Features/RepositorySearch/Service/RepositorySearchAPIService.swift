//
//  RepositorySearchAPIService.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct RepositorySearchAPIService: RepositorySearchAPIServiceProtocol {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    func searchRepositories(keyword: String) async throws(APIError) -> [Repository] {
        try await apiClient.send(RepositorySearchRequest(keyword: keyword)).items
    }
}
