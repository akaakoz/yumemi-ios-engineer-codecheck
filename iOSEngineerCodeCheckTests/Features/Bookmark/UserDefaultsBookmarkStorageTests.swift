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
            let bookmarks: [RepositoryDetail] = [
                .fixture(fullName: "b/two"),
                .fixture(fullName: "a/one", language: nil, subscribersCount: nil),
            ]

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

    @Test("検索結果（Repository）の形式で保存されていたブックマークを、Watch 数を nil として RepositoryDetail に移行する")
    func migratesRepositoryFormatToRepositoryDetail() throws {
        try withIsolatedUserDefaults { userDefaults in
            let repositoryFormatJSON = """
                [
                  {
                    "fullName": "apple/swift", "language": "C++",
                    "stargazersCount": 67000, "watchersCount": 67000, "forksCount": 10000, "openIssuesCount": 7000,
                    "owner": { "avatarUrl": "https://avatars.githubusercontent.com/u/10639145" }
                  }
                ]
                """
            userDefaults.set(Data(repositoryFormatJSON.utf8), forKey: UserDefaultsBookmarkStorage.storageKey)
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)

            let bookmarks = try storage.loadBookmarks()

            // Star 数と同じ値の watchersCount は Watch 数として移行しない
            #expect(bookmarks == [
                RepositoryDetail(
                    fullName: "apple/swift",
                    description: nil,
                    language: "C++",
                    stargazersCount: 67000,
                    subscribersCount: nil,
                    forksCount: 10000,
                    openIssuesCount: 7000,
                    pushedAt: nil,
                    owner: .init(avatarURLString: "https://avatars.githubusercontent.com/u/10639145")
                ),
            ])
        }
    }

    @Test("RepositoryDetail の各項目を camelCase のキーで保存し、marked は保存しない")
    func savesRepositoryFieldsWithoutMarked() throws {
        try withIsolatedUserDefaults { userDefaults in
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)

            try storage.saveBookmarks([.fixture(fullName: "apple/swift")])

            let data = try #require(userDefaults.data(forKey: UserDefaultsBookmarkStorage.storageKey))
            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            #expect(json.first?["fullName"] as? String == "apple/swift")
            #expect(json.first?["stargazersCount"] as? Int == 100)
            #expect(json.first?["subscribersCount"] as? Int == 2400)
            #expect((json.first?["owner"] as? [String: Any])?["avatarUrl"] is String)
            #expect(json.first?["marked"] == nil)
        }
    }

    @Test("説明文と最終 push 日時を保存し、読み込み直しても同じ値になる")
    func savesDescriptionAndPushedAt() throws {
        try withIsolatedUserDefaults { userDefaults in
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)
            let bookmark = RepositoryDetail.fixture(
                fullName: "apple/swift",
                description: "The Swift Programming Language",
                pushedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )

            try storage.saveBookmarks([bookmark])

            #expect(try storage.loadBookmarks() == [bookmark])
        }
    }

    @Test("説明文と最終 push 日時を保存していなかった以前のブックマークは、どちらも nil として読み込む")
    func loadsBookmarkWithoutDescriptionAndPushedAt() throws {
        try withIsolatedUserDefaults { userDefaults in
            let previousFormatJSON = """
                [{"fullName": "apple/swift", "language": "C++", "stargazersCount": 1, "subscribersCount": 2, \
                "forksCount": 3, "openIssuesCount": 4, "owner": {"avatarUrl": "https://avatars.githubusercontent.com/u/1"}}]
                """
            userDefaults.set(Data(previousFormatJSON.utf8), forKey: UserDefaultsBookmarkStorage.storageKey)
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)

            let bookmarks = try storage.loadBookmarks()

            #expect(bookmarks.map(\.fullName) == ["apple/swift"])
            #expect(bookmarks.first?.description == nil)
            #expect(bookmarks.first?.pushedAt == nil)
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

    @Test("壊れた保存データは別のキーに退避し、通常のキーは空にする")
    func corruptedDataIsBackedUp() throws {
        try withIsolatedUserDefaults { userDefaults in
            let corruptedData = Data("not json".utf8)
            userDefaults.set(corruptedData, forKey: UserDefaultsBookmarkStorage.storageKey)
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)

            #expect(throws: BookmarkStorageError.self) {
                try storage.loadBookmarks()
            }

            let backupKeys = userDefaults.dictionaryRepresentation().keys
                .filter { $0.hasPrefix(UserDefaultsBookmarkStorage.corruptedDataKeyPrefix) }
            #expect(backupKeys.count == 1)
            let backupKey = try #require(backupKeys.first)
            #expect(userDefaults.data(forKey: backupKey) == corruptedData)
            #expect(userDefaults.data(forKey: UserDefaultsBookmarkStorage.storageKey) == nil)
        }
    }

    @Test("退避した後は空の状態から読み込め、保存しても退避したデータは上書きされない")
    func savingAfterBackupKeepsCorruptedData() throws {
        try withIsolatedUserDefaults { userDefaults in
            let corruptedData = Data("not json".utf8)
            userDefaults.set(corruptedData, forKey: UserDefaultsBookmarkStorage.storageKey)
            let storage = UserDefaultsBookmarkStorage(userDefaults: userDefaults)
            #expect(throws: BookmarkStorageError.self) {
                try storage.loadBookmarks()
            }

            let bookmarksAfterBackup = try storage.loadBookmarks()
            try storage.saveBookmarks([.fixture(fullName: "a/one")])

            #expect(bookmarksAfterBackup.isEmpty)
            #expect(try storage.loadBookmarks() == [.fixture(fullName: "a/one")])
            let backupKey = try #require(userDefaults.dictionaryRepresentation().keys
                .first { $0.hasPrefix(UserDefaultsBookmarkStorage.corruptedDataKeyPrefix) })
            #expect(userDefaults.data(forKey: backupKey) == corruptedData)
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
