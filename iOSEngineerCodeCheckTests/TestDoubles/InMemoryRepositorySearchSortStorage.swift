//
//  InMemoryRepositorySearchSortStorage.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
@testable import iOSEngineerCodeCheck

final class InMemoryRepositorySearchSortStorage: RepositorySearchSortStorageProtocol {

    private(set) var savedSort: RepositorySearchSort

    init(savedSort: RepositorySearchSort = .bestMatch) {
        self.savedSort = savedSort
    }

    func loadSort() -> RepositorySearchSort {
        savedSort
    }

    func saveSort(_ sort: RepositorySearchSort) {
        savedSort = sort
    }
}
