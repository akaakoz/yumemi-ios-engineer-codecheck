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
        guard let storedBookmarks = readStoredBookmarks() else {
            return
        }
        guard !storedBookmarks.contains(where: { $0.fullName == repositoryDetail.fullName }) else {
            // Search タブで追加済みの場合は、保存し直さずに一覧だけ保存先に合わせる
            bookmarks = storedBookmarks
            return
        }
        save(storedBookmarks + [repositoryDetail])
    }

    /// 一覧から消えて保存される。詳細画面は値で遷移しているため、表示されたまま残る。
    func removeBookmark(fullName: String) {
        guard let storedBookmarks = readStoredBookmarks() else {
            return
        }
        guard storedBookmarks.contains(where: { $0.fullName == fullName }) else {
            // Search タブで削除済みの場合は、保存し直さずに一覧だけ保存先に合わせる
            bookmarks = storedBookmarks
            return
        }
        save(storedBookmarks.filter { $0.fullName != fullName })
    }

    /// 一覧は詳細画面を開いている間は読み込み直されず、その間に Search タブで追加・削除されていることがある。
    /// 古い一覧で上書きしてその変更を消さないよう、追加・削除の直前に保存先から読み直す。
    /// - Returns: 読み込めなかった場合は `nil`（失敗は `storageError` とログに残す）
    private func readStoredBookmarks() -> [RepositoryDetail]? {
        do {
            return try storage.loadBookmarks()
        } catch {
            logger.error("Failed to load bookmarks: \(String(describing: error), privacy: .public)")
            storageError = error
            return nil
        }
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
