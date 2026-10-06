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
    private(set) var bookmarks: [RepositoryDetail] = []
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

    func isBookmarked(fullName: String) -> Bool {
        bookmarks.contains { $0.fullName == fullName }
    }

    /// 削除した後に詳細画面で追加し直すと、取得した `RepositoryDetail` で末尾に再登録される。
    func addBookmark(_ repositoryDetail: RepositoryDetail) {
        guard !isBookmarked(fullName: repositoryDetail.fullName) else {
            return
        }
        save(bookmarks + [repositoryDetail])
    }

    /// 一覧から消えて保存される。詳細画面は値で遷移しているため、表示されたまま残る。
    func removeBookmark(fullName: String) {
        guard isBookmarked(fullName: fullName) else {
            return
        }
        save(bookmarks.filter { $0.fullName != fullName })
    }

    /// 保存に成功したときだけ一覧を差し替え、保存先の内容と食い違わないようにする。
    private func save(_ updatedBookmarks: [RepositoryDetail]) {
        do {
            try storage.saveBookmarks(updatedBookmarks)
            bookmarks = updatedBookmarks
            storageError = nil
        } catch {
            logger.error("Failed to save bookmarks: \(String(describing: error), privacy: .public)")
            storageError = error
        }
    }
}
