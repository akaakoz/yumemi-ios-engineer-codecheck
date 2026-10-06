//
//  UserDefaultsBookmarkStorage.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct UserDefaultsBookmarkStorage: BookmarkStorageProtocol {

    /// 保存済みのブックマークを読み込めるよう、値を変えないこと。
    static let storageKey = "data"
    /// 読み込めなかった保存データを退避するキーの接頭辞。退避したデータを上書きしないよう、後ろに退避した日時を付ける。
    static let corruptedDataKeyPrefix = "data.corrupted."

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

    func loadBookmarks() throws(BookmarkStorageError) -> [RepositoryDetail] {
        guard let data = userDefaults.data(forKey: Self.storageKey) else {
            return []
        }
        do {
            // 保存済みのデータは camelCase のキーで保存されているため、キー変換をしない
            let storedBookmarks = try JSONDecoder().decode([StoredBookmark].self, from: data)
            return storedBookmarks.filter { !$0.isRemoved }.map(\.repositoryDetail)
        } catch {
            // 壊れたデータを次の保存で上書きして失わないよう、別のキーに退避してから空の状態にする
            let backupKey = Self.corruptedDataKeyPrefix + Date().ISO8601Format()
            userDefaults.set(data, forKey: backupKey)
            userDefaults.removeObject(forKey: Self.storageKey)
            throw .loadFailed(description: "\(error)（退避先: \(backupKey)）")
        }
    }

    /// `marked` を書かずに保存する（`RepositoryDetail` の各項目だけを並べた JSON）
    func saveBookmarks(_ bookmarks: [RepositoryDetail]) throws(BookmarkStorageError) {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            throw .saveFailed(description: String(describing: error))
        }
    }

    private struct StoredBookmark: Decodable {
        let repositoryDetail: RepositoryDetail
        let isRemoved: Bool

        private enum CodingKeys: String, CodingKey {
            case marked
        }

        init(from decoder: any Decoder) throws {
            repositoryDetail = try RepositoryDetail(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // `marked` が無いデータ（このバージョン以降の保存形式）は登録済みとして扱う
            isRemoved = try container.decodeIfPresent(Bool.self, forKey: .marked) == false
        }
    }
}
