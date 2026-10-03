//
//  BookmarkViewModel.swift
//  iOSEngineerCodeCheck
//

import Foundation
import Observation
import os

/// Search タブとはインスタンスを共有せず、保存先（`BookmarkStorageProtocol`）を通して同期する。
/// 画面が表示されるたびに `loadBookmarks()` で読み込み直し、Search タブでの追加・削除を反映する。
///
/// 旧実装の挙動を変えないよう、次のルールに従う。
/// - Bookmark タブの詳細画面での追加・削除は `Bookmark.isMarked` だけを切り替える。一覧からは消さず、保存もしない。
/// - 保存されない `isMarked` の変更を失わないよう、読み込み直したときもすでに一覧にある項目はメモリ上の値を残す。
@MainActor
@Observable
final class BookmarkViewModel {

    /// 追加した順に並ぶブックマーク
    private(set) var bookmarks: [Bookmark] = []
    /// 画面には表示しない（旧実装の挙動を維持）。原因調査とテストのために保持する。
    private(set) var storageError: BookmarkStorageError?

    private let storage: any BookmarkStorageProtocol
    private let logger = Logger(subsystem: "jp.yumemi.iOSEngineerCodeCheck", category: "Bookmark")

    init(storage: any BookmarkStorageProtocol = UserDefaultsBookmarkStorage()) {
        self.storage = storage
    }

    func loadBookmarks() {
        let storedBookmarks: [Bookmark]
        do {
            storedBookmarks = try storage.loadBookmarks()
            storageError = nil
        } catch {
            // 読み込めなかったデータは使わず空の状態にする（旧実装の挙動を維持）。失敗は storageError に残す
            logger.error("Failed to load bookmarks: \(String(describing: error), privacy: .public)")
            storageError = error
            bookmarks = []
            return
        }

        let markedStates = Dictionary(bookmarks.map { ($0.id, $0.isMarked) }, uniquingKeysWith: { first, _ in first })
        bookmarks = storedBookmarks.map { stored in
            var bookmark = stored
            if let isMarked = markedStates[stored.id] {
                bookmark.isMarked = isMarked
            }
            return bookmark
        }
    }

    func isMarked(_ repository: Repository) -> Bool {
        bookmarks.first { $0.id == repository.id }?.isMarked == true
    }

    func setMarked(_ repository: Repository, isMarked: Bool) {
        guard let index = bookmarks.firstIndex(where: { $0.id == repository.id }) else {
            return
        }
        bookmarks[index].isMarked = isMarked
    }
}
