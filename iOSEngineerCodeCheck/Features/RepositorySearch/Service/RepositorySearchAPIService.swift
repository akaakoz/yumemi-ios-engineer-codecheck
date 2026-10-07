//
//  RepositorySearchAPIService.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct RepositorySearchAPIService: RepositorySearchAPIServiceProtocol {

    /// GitHub の検索 API で取得できる件数の上限。これを超えるページを要求すると 422 になる
    static let maxReachableResultCount = 1000

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    func searchRepositories(keyword: String, sort: RepositorySearchSort, page: Int) async throws(APIError) -> RepositorySearchPage {
        let response = try await apiClient.send(RepositorySearchRequest(keyword: keyword, sort: sort, page: page))
        let reachableResultCount = min(response.totalCount, Self.maxReachableResultCount)
        let hasNextPage = !response.items.isEmpty && page * RepositorySearchRequest.perPage < reachableResultCount
        return RepositorySearchPage(repositories: response.items, hasNextPage: hasNextPage)
    }
}
