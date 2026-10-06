//
//  BookmarkServiceProtocol.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// ブックマークの読み込みと追加・削除。Search タブと Bookmark タブは、この保存先を通して登録状態を共有する。
protocol BookmarkServiceProtocol {
    func loadBookmarks() throws(BookmarkStorageError) -> [RepositoryDetail]

    /// 保存先に無ければ末尾に追加して保存する。
    /// - Returns: 変更後の一覧。すでに登録済みの場合は保存せず、保存先の一覧をそのまま返す
    func addBookmark(_ repositoryDetail: RepositoryDetail) throws(BookmarkStorageError) -> [RepositoryDetail]

    /// 保存先にあれば削除して保存する。
    /// - Returns: 変更後の一覧。登録されていない場合は保存せず、保存先の一覧をそのまま返す
    func removeBookmark(fullName: String) throws(BookmarkStorageError) -> [RepositoryDetail]
}
