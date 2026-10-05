//
//  UserDefaultsBookmarkStorageTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

/// 端末の `UserDefaults.standard` を汚さないよう、テストごとに専用の suite を作って破棄する。
@Suite("UserDefaultsBookmarkStorage")
struct UserDefaultsBookmarkStorageTests {

    private let suiteName = "UserDefaultsBookmarkStorageTests.\(UUID().uuidString)"

    private func withIsolatedUserDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        try body(userDefaults)
    }

    @Test("一度も保存していない場合は空配列を返す")
    func loadReturnsEmptyWhenNothingSaved() throws {
        try withIsolatedUserDefaults { userDefaults in
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)

            let bookmarks = try storage.loadBookmarks()

            #expect(bookmarks.isEmpty)
        }
    }

    @Test("保存したブックマークを同じ順序で読み込める")
    func saveAndLoadRoundTrip() throws {
        try withIsolatedUserDefaults { userDefaults in
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)
            let bookmarks: [Repository] = [.fixture(fullName: "b/two"), .fixture(fullName: "a/one", language: nil)]

            try storage.saveBookmarks(bookmarks)
            let loadedBookmarks = try storage.loadBookmarks()

            #expect(loadedBookmarks == bookmarks)
        }
    }

    @Test("以前の保存形式を読み込み、marked: false（Bookmark タブで削除済み）の項目は除外する")
    func loadsLegacyFormat() throws {
        try withIsolatedUserDefaults { userDefaults in
            let legacyJSON = """
                [
                  {
                    "fullName": "apple/swift", "language": "C++",
                    "stargazersCount": 1, "watchersCount": 2, "forksCount": 3, "openIssuesCount": 4,
                    "owner": { "avatarUrl": "https://avatars.githubusercontent.com/u/10639145" },
                    "marked": true
                  },
                  {
                    "fullName": "example/unmarked", "language": null,
                    "stargazersCount": 0, "watchersCount": 0, "forksCount": 0, "openIssuesCount": 0,
                    "owner": { "avatarUrl": "https://avatars.githubusercontent.com/u/1" },
                    "marked": false
                  },
                  {
                    "fullName": "example/no-flag", "language": null,
                    "stargazersCount": 0, "watchersCount": 0, "forksCount": 0, "openIssuesCount": 0,
                    "owner": { "avatarUrl": "https://avatars.githubusercontent.com/u/1" }
                  }
                ]
                """
            userDefaults.set(Data(legacyJSON.utf8), forKey: UserDefaultsBookmarkStorage.storageKey)
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)

            let bookmarks = try storage.loadBookmarks()

            #expect(bookmarks.map(\.id) == ["apple/swift", "example/no-flag"])
            #expect(bookmarks.first?.openIssuesCount == 4)
        }
    }

    @Test("Repository の各項目を camelCase のキーで保存し、marked は保存しない")
    func savesRepositoryFieldsWithoutMarked() throws {
        try withIsolatedUserDefaults { userDefaults in
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)

            try storage.saveBookmarks([.fixture(fullName: "apple/swift")])

            let data = try #require(userDefaults.data(forKey: UserDefaultsBookmarkStorage.storageKey))
            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(json.first?["fullName"] as? String == "apple/swift")
            #expect(json.first?["stargazersCount"] as? Int == 100)
            #expect((json.first?["owner"] as? [String: Any])?["avatarUrl"] is String)
            #expect(json.first?["marked"] == nil)
        }
    }

    @Test("壊れた保存データは loadFailed として throw する")
    func loadThrowsForCorruptedData() throws {
        try withIsolatedUserDefaults { userDefaults in
            userDefaults.set(Data("not json".utf8), forKey: UserDefaultsBookmarkStorage.storageKey)
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)

            let error = #expect(throws: BookmarkStorageError.self) {
                try storage.loadBookmarks()
            }
            guard case .loadFailed = error else {
                Issue.record("loadFailed を期待したが \(String(describing: error)) だった")
                return
            }
        }
    }

    @Test("保存先の切り替えが指定されている場合は、その領域に読み書きする")
    func defaultUserDefaultsUsesOverride() throws {
        try withIsolatedUserDefaults { standard in
            let overrideSuiteName = "\(suiteName).override"
            defer { UserDefaults().removePersistentDomain(forName: overrideSuiteName) }
            standard.set(overrideSuiteName, forKey: UserDefaultsBookmarkStorage.suiteNameOverrideKey)
            let storage = UserDefaultsBookmarkStorage(userDefaults: UserDefaultsBookmarkStorage.defaultUserDefaults(standard: standard))

            try storage.saveBookmarks([.fixture(fullName: "a/one")])

            let overrideDefaults = try #require(UserDefaults(suiteName: overrideSuiteName))
            #expect(overrideDefaults.data(forKey: UserDefaultsBookmarkStorage.storageKey) != nil)
            #expect(standard.data(forKey: UserDefaultsBookmarkStorage.storageKey) == nil)
        }
    }

    @Test("保存先の切り替えが無い場合は、渡した UserDefaults をそのまま使う")
    func defaultUserDefaultsWithoutOverride() throws {
        try withIsolatedUserDefaults { standard in
            #expect(UserDefaultsBookmarkStorage.defaultUserDefaults(standard: standard) === standard)
        }
    }
}
