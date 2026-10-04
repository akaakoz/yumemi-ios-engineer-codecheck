//
//  UserDefaultsBookmarkStorage.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct UserDefaultsBookmarkStorage: BookmarkStorageProtocol {

    /// 保存済みのブックマークを読み込めるよう、値を変えないこと。
    static let storageKey = "data"

    /// 保存先の UserDefaults を別の領域（suite）に切り替えるキー（Debug ビルドのみ有効）。
    /// 起動引数 `-BookmarkStorageSuiteName <名前>` で指定でき、UI テストが端末の保存データと分けて検証するために使う。
    static let suiteNameOverrideKey = "BookmarkStorageSuiteName"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = UserDefaultsBookmarkStorage.defaultUserDefaults()) {
        self.userDefaults = userDefaults
    }

    static func defaultUserDefaults(standard: UserDefaults = .standard) -> UserDefaults {
        #if DEBUG
        if let suiteName = standard.string(forKey: suiteNameOverrideKey) {
            guard let userDefaults = UserDefaults(suiteName: suiteName) else {
                // 指定の誤りに気付けるよう、黙って端末の保存データを使わずに止める
                preconditionFailure("\(suiteNameOverrideKey) に指定された名前を使えません: \(suiteName)")
            }
            return userDefaults
        }
        #endif
        return standard
    }

    func loadBookmarks() throws(BookmarkStorageError) -> [Bookmark] {
        guard let data = userDefaults.data(forKey: Self.storageKey) else {
            return []
        }
        do {
            // 保存済みのデータは camelCase のキーで保存されているため、キー変換をしない
            return try JSONDecoder().decode([Bookmark].self, from: data)
        } catch {
            throw .loadFailed(description: String(describing: error))
        }
    }

    func saveBookmarks(_ bookmarks: [Bookmark]) throws(BookmarkStorageError) {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            throw .saveFailed(description: String(describing: error))
        }
    }
}
