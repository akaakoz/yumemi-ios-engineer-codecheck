//
//  BookmarkService.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// 追加・削除の直前に保存先を読み直し、その内容に対して変更する。
/// 呼び出し側が持つ一覧が古くても、もう一方のタブでの変更を上書きしたり、重複して保存したりしない。
struct BookmarkService: BookmarkServiceProtocol {

    private let storage: BookmarkStorageProtocol

    init(storage: BookmarkStorageProtocol = UserDefaultsBookmarkStorage()) {
        self.storage = storage
    }

    func loadBookmarks() throws(BookmarkStorageError) -> [RepositoryDetail] {
        try storage.loadBookmarks()
    }

    func addBookmark(_ repositoryDetail: RepositoryDetail) throws(BookmarkStorageError) -> [RepositoryDetail] {
        let storedBookmarks = try storage.loadBookmarks()
        guard !storedBookmarks.contains(where: { $0.fullName == repositoryDetail.fullName }) else {
            return storedBookmarks
        }
        let updatedBookmarks = storedBookmarks + [repositoryDetail]
        try storage.saveBookmarks(updatedBookmarks)
        return updatedBookmarks
    }

    func removeBookmark(fullName: String) throws(BookmarkStorageError) -> [RepositoryDetail] {
        let storedBookmarks = try storage.loadBookmarks()
        guard storedBookmarks.contains(where: { $0.fullName == fullName }) else {
            return storedBookmarks
        }
        let updatedBookmarks = storedBookmarks.filter { $0.fullName != fullName }
        try storage.saveBookmarks(updatedBookmarks)
        return updatedBookmarks
    }
}
