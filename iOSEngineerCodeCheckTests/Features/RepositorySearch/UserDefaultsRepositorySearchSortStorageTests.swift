//
//  UserDefaultsRepositorySearchSortStorageTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@Suite("UserDefaultsRepositorySearchSortStorage")
struct UserDefaultsRepositorySearchSortStorageTests {

    /// テストごとに別の領域を使い、端末に保存済みの値や他のテストの結果に依存しない
    private let suiteName = "UserDefaultsRepositorySearchSortStorageTests.\(UUID().uuidString)"

    private func withIsolatedUserDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        try body(userDefaults)
    }

    @Test("まだ保存していない場合は、関連度の順を返す")
    func loadReturnsBestMatchWhenNothingSaved() throws {
        try withIsolatedUserDefaults { userDefaults in
            #expect(UserDefaultsRepositorySearchSortStorage(userDefaults: userDefaults).loadSort() == .bestMatch)
        }
    }

    @Test("保存した並び順を、作り直した保存先からも読み込める", arguments: RepositorySearchSort.allCases)
    func savedSortSurvivesRecreation(sort: RepositorySearchSort) throws {
        try withIsolatedUserDefaults { userDefaults in
            UserDefaultsRepositorySearchSortStorage(userDefaults: userDefaults).saveSort(sort)

            #expect(UserDefaultsRepositorySearchSortStorage(userDefaults: userDefaults).loadSort() == sort)
        }
    }

    @Test("知らない値が保存されている場合は、関連度の順を返す")
    func loadReturnsBestMatchForUnknownValue() throws {
        try withIsolatedUserDefaults { userDefaults in
            userDefaults.set("forks", forKey: UserDefaultsRepositorySearchSortStorage.storageKey)

            #expect(UserDefaultsRepositorySearchSortStorage(userDefaults: userDefaults).loadSort() == .bestMatch)
        }
    }
}
