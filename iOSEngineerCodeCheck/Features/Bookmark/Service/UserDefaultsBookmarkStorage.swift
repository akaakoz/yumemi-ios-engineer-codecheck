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

    func loadBookmarks() throws(BookmarkStorageError) -> [Repository] {
        guard let data = userDefaults.data(forKey: Self.storageKey) else {
            return []
        }
        do {
            // 保存済みのデータは camelCase のキーで保存されているため、キー変換をしない
            let storedBookmarks = try JSONDecoder().decode([StoredBookmark].self, from: data)
            return storedBookmarks.filter { !$0.isRemoved }.map(\.repository)
        } catch {
            throw .loadFailed(description: String(describing: error))
        }
    }

    /// `marked` を書かずに保存する（`Repository` の各項目だけを並べた JSON）
    func saveBookmarks(_ bookmarks: [Repository]) throws(BookmarkStorageError) {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            throw .saveFailed(description: String(describing: error))
        }
    }

    /// 保存済みの 1 件。以前のバージョンは `Repository` の各項目と同じ階層に `marked` も保存しており、
    /// Bookmark タブで削除した項目を `marked: false` として残していたため、読み込み時に除外する。
    private struct StoredBookmark: Decodable {
        let repository: Repository
        let isRemoved: Bool

        private enum CodingKeys: String, CodingKey {
            case marked
        }

        init(from decoder: any Decoder) throws {
            repository = try Repository(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // `marked` が無いデータ（このバージョン以降の保存形式）は登録済みとして扱う
            isRemoved = try container.decodeIfPresent(Bool.self, forKey: .marked) == false
        }
    }
}
