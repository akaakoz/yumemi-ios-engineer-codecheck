//
//  UserDefaultsRepositorySearchSortStorage.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct UserDefaultsRepositorySearchSortStorage: RepositorySearchSortStorageProtocol {

    /// 並び順を保存する UserDefaults のキー。
    /// UI テストは起動引数 `-RepositorySearchSort <値>` でこのキーの値を上書きし、前のテストで選んだ並び順に左右されないようにする
    static let storageKey = "RepositorySearchSort"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadSort() -> RepositorySearchSort {
        // 保存していない場合と、以前のバージョンなどで知らない値が保存されている場合は、関連度の順にする
        userDefaults.string(forKey: Self.storageKey).flatMap(RepositorySearchSort.init(rawValue:)) ?? .bestMatch
    }

    func saveSort(_ sort: RepositorySearchSort) {
        userDefaults.set(sort.rawValue, forKey: Self.storageKey)
    }
}
