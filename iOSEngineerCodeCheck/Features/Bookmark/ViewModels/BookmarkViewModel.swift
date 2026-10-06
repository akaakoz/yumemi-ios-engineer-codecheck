//
//  BookmarkViewModel.swift
//  iOSEngineerCodeCheck
//

import Foundation
import Observation
import os

/// Search タブとはインスタンスを共有せず、保存先を通して同期する。表示されるたびに `loadBookmarks()` で読み込み直す。
@MainActor
@Observable
final class BookmarkViewModel {

    /// 追加した順に並ぶブックマーク
    private(set) var bookmarks: [Repository] = []
    /// 直近の読み込み・保存の失敗。画面でアラートとして表示し、閉じたら `nil` に戻す。
    private(set) var storageError: BookmarkStorageError?

    var isShowingStorageError: Bool {
        get { storageError != nil }
        set {
            if !newValue {
                storageError = nil
            }
        }
    }

    private let storage: BookmarkStorageProtocol
    private let logger = Logger(subsystem: "jp.yumemi.iOSEngineerCodeCheck", category: "Bookmark")

    init(storage: BookmarkStorageProtocol = UserDefaultsBookmarkStorage()) {
        self.storage = storage
    }

    func loadBookmarks() {
        do {
            bookmarks = try storage.loadBookmarks()
            storageError = nil
        } catch {
            logger.error("Failed to load bookmarks: \(String(describing: error), privacy: .public)")
            storageError = error
            bookmarks = []
        }
    }

    func isBookmarked(_ repository: Repository) -> Bool {
        bookmarks.contains { $0.id == repository.id }
    }

    /// 削除すると一覧から消えて保存される。詳細画面は値で遷移しているため表示されたままで、追加すると末尾に再登録される。
    func setBookmarked(_ repository: Repository, isBookmarked: Bool) {
        guard isBookmarked != self.isBookmarked(repository) else {
            return
        }

        if isBookmarked {
            bookmarks.append(repository)
        } else {
            bookmarks.removeAll { $0.id == repository.id }
        }

        do {
            try storage.saveBookmarks(bookmarks)
            storageError = nil
        } catch {
            logger.error("Failed to save bookmarks: \(String(describing: error), privacy: .public)")
            storageError = error
        }
    }
}
