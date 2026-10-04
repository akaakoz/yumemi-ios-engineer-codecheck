//
//  RepositorySearchViewModel.swift
//  iOSEngineerCodeCheck
//

import Foundation
import Observation
import os

/// ブックマークは Bookmark タブとインスタンスを共有せず、保存先を通して同期する。
/// - 登録済みかどうかは保存済みの一覧に含まれているかで決まり、`Bookmark.isMarked` は見ない。
/// - 検索結果に含まれるブックマークは `isMarked` を true に戻して保存する。
/// - 保存に失敗しても画面上の登録状態は変更後のまま残す。
@MainActor
@Observable
final class RepositorySearchViewModel {

    enum Phase: Equatable {
        /// まだ検索していない、または入力をクリアした
        case idle
        case loading
        /// 検索に成功した。0 件の場合も含む
        case loaded
        case failed(APIError)
    }

    var query = "" {
        didSet {
            if query.isEmpty {
                clearResults()
            }
        }
    }
    private(set) var phase = Phase.idle
    /// 直近に成功した検索の結果。新しい検索の通信中は前回の結果を表示し続け、失敗したら空にする。
    private(set) var repositories: [Repository] = []
    /// 画面には表示しない。原因調査とテストのために保持する。
    private(set) var bookmarkStorageError: BookmarkStorageError?

    /// 実行中の検索。新しい検索を始めるときにキャンセルし、古い結果で上書きされないようにする。
    @ObservationIgnored private(set) var searchTask: Task<Void, Never>?
    /// ブックマーク済みのリポジトリ。ブックマークの登録・削除は Search タブからしか行えないため、
    /// `loadBookmarks()` で読み込んだ後はこの ViewModel での変更に合わせて更新すれば保存内容と一致する。
    private var bookmarkedRepositoryIDs: Set<Repository.ID> = []

    private let apiService: RepositorySearchAPIServiceProtocol
    private let bookmarkStorage: BookmarkStorageProtocol
    private let logger = Logger(subsystem: "jp.yumemi.iOSEngineerCodeCheck", category: "RepositorySearch")

    init(
        apiService: RepositorySearchAPIServiceProtocol = RepositorySearchAPIService(),
        bookmarkStorage: BookmarkStorageProtocol = UserDefaultsBookmarkStorage()
    ) {
        self.apiService = apiService
        self.bookmarkStorage = bookmarkStorage
    }

    func search() {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return
        }

        searchTask?.cancel()
        phase = .loading

        searchTask = Task {
            do throws(APIError) {
                let result = try await apiService.searchRepositories(keyword: keyword)
                // キャンセル済み = より新しい検索が始まっている、またはクリアされたので結果を反映しない
                guard !Task.isCancelled else { return }
                repositories = result
                phase = .loaded
                remarkBookmarksInSearchResults()
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Search failed: \(String(describing: error), privacy: .public)")
                // 前回の結果が残っていると今回の結果と誤解されるため、消してから失敗を表示する
                repositories = []
                phase = .failed(error)
            }
        }
    }

    // MARK: - ブックマーク
    func loadBookmarks() {
        guard let bookmarks = readStoredBookmarks() else {
            return
        }
        bookmarkedRepositoryIDs = Set(bookmarks.map(\.id))
    }

    func isBookmarked(_ repository: Repository) -> Bool {
        bookmarkedRepositoryIDs.contains(repository.id)
    }

    func setBookmarked(_ repository: Repository, isBookmarked: Bool) {
        guard isBookmarked != self.isBookmarked(repository) else {
            return
        }

        if isBookmarked {
            bookmarkedRepositoryIDs.insert(repository.id)
        } else {
            bookmarkedRepositoryIDs.remove(repository.id)
        }

        guard var bookmarks = readStoredBookmarks() else {
            return
        }
        if isBookmarked {
            bookmarks.append(Bookmark(repository: repository, isMarked: true))
        } else {
            bookmarks.removeAll { $0.id == repository.id }
        }
        remarkBookmarks(&bookmarks, in: repositories)
        saveBookmarks(bookmarks)
    }

    // MARK: - Private

    private func clearResults() {
        searchTask?.cancel()
        searchTask = nil
        repositories = []
        phase = .idle
    }

    /// 検索結果に含まれるブックマークの `isMarked` を true に戻し、変更があれば保存する。
    private func remarkBookmarksInSearchResults() {
        guard var bookmarks = readStoredBookmarks() else {
            return
        }
        if remarkBookmarks(&bookmarks, in: repositories) {
            saveBookmarks(bookmarks)
        }
    }

    /// - Returns: 変更があった場合は true
    @discardableResult
    private func remarkBookmarks(_ bookmarks: inout [Bookmark], in searchResults: [Repository]) -> Bool {
        let searchResultIDs = Set(searchResults.map(\.id))
        var changed = false
        for index in bookmarks.indices where searchResultIDs.contains(bookmarks[index].id) && !bookmarks[index].isMarked {
            bookmarks[index].isMarked = true
            changed = true
        }
        return changed
    }

    /// - Returns: 読み込めなかった場合は `nil`（失敗は `bookmarkStorageError` とログに残す）
    private func readStoredBookmarks() -> [Bookmark]? {
        do {
            return try bookmarkStorage.loadBookmarks()
        } catch {
            logger.error("Failed to load bookmarks: \(String(describing: error), privacy: .public)")
            bookmarkStorageError = error
            return nil
        }
    }

    private func saveBookmarks(_ bookmarks: [Bookmark]) {
        do {
            try bookmarkStorage.saveBookmarks(bookmarks)
            bookmarkStorageError = nil
        } catch {
            logger.error("Failed to save bookmarks: \(String(describing: error), privacy: .public)")
            bookmarkStorageError = error
        }
    }
}
