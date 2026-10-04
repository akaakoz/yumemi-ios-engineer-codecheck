//
//  BookmarkViewModel.swift
//  iOSEngineerCodeCheck
//

import Foundation
import Observation
import os

/// Search タブとはインスタンスを共有せず、保存先を通して同期する。
/// `isMarked` の変更は保存しないため、読み込み直したときもすでに一覧にある項目はメモリ上の値を残す。
@MainActor
@Observable
final class BookmarkViewModel {

    private(set) var bookmarks: [Bookmark] = []
    /// 画面には表示しない。原因調査とテストのために保持する。
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
