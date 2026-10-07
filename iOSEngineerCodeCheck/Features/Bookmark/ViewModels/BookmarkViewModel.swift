//
//  BookmarkViewModel.swift
//  iOSEngineerCodeCheck
//

import Foundation
import Observation
import os

/// 保存済みのブックマークの一覧。表示されるたびに `loadBookmarks()` で読み込み直し、詳細画面での追加・削除も反映する。
@MainActor
@Observable
final class BookmarkViewModel {

    /// 追加した順に並ぶブックマーク
    private(set) var bookmarks: [RepositoryDetail] = []
    /// 直近の読み込みの失敗。画面でアラートとして表示し、閉じたら `nil` に戻す。
    private(set) var storageError: BookmarkStorageError?

    var isShowingStorageError: Bool {
        get { storageError != nil }
        set {
            if !newValue {
                storageError = nil
            }
        }
    }

    private let bookmarkService: BookmarkServiceProtocol
    private let logger = Logger(subsystem: "jp.yumemi.iOSEngineerCodeCheck", category: "Bookmark")

    init(bookmarkService: BookmarkServiceProtocol = BookmarkService()) {
        self.bookmarkService = bookmarkService
    }

    func loadBookmarks() {
        do {
            bookmarks = try bookmarkService.loadBookmarks()
            storageError = nil
        } catch {
            logger.error("Failed to load bookmarks: \(String(describing: error), privacy: .public)")
            storageError = error
            bookmarks = []
        }
    }
}
