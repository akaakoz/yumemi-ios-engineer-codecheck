//
//  InMemoryBookmarkStorage.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
@testable import iOSEngineerCodeCheck

/// 端末の UserDefaults を使わずにブックマークを保持するテスト用ストレージ。読み込み・保存の失敗も再現できる。
final class InMemoryBookmarkStorage: BookmarkStorageProtocol {

    private(set) var savedBookmarks: [Bookmark]
    private(set) var saveCallCount = 0
    var loadError: BookmarkStorageError?
    var saveError: BookmarkStorageError?

    init(savedBookmarks: [Bookmark] = [], loadError: BookmarkStorageError? = nil) {
        self.savedBookmarks = savedBookmarks
        self.loadError = loadError
    }

    func loadBookmarks() throws(BookmarkStorageError) -> [Bookmark] {
        if let loadError {
            throw loadError
        }
        return savedBookmarks
    }

    func saveBookmarks(_ bookmarks: [Bookmark]) throws(BookmarkStorageError) {
        saveCallCount += 1
        if let saveError {
            throw saveError
        }
        savedBookmarks = bookmarks
    }
}
