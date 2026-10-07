//
//  RepositorySearchSortStorageProtocol.swift
//  iOSEngineerCodeCheck
//

import Foundation

protocol RepositorySearchSortStorageProtocol {
    /// 保存している並び順。まだ選んでいない場合は関連度の順
    func loadSort() -> RepositorySearchSort
    func saveSort(_ sort: RepositorySearchSort)
}
