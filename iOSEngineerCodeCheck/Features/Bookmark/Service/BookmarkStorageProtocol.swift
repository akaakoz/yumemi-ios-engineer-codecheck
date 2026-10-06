//
//  BookmarkStorageProtocol.swift
//  iOSEngineerCodeCheck
//

import Foundation

protocol BookmarkStorageProtocol {
    /// 保存済みのブックマークを読み込む。一度も保存していない場合は空配列を返す。
    func loadBookmarks() throws(BookmarkStorageError) -> [RepositoryDetail]
    func saveBookmarks(_ bookmarks: [RepositoryDetail]) throws(BookmarkStorageError)
}

enum BookmarkStorageError: Error, Equatable, Sendable {
    case loadFailed(description: String)
    case saveFailed(description: String)
}
