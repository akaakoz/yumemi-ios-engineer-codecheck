//
//  RepositorySearchViewModel.swift
//  iOSEngineerCodeCheck
//

import Foundation
import Observation
import os

/// ブックマークは Bookmark タブとインスタンスを共有せず、保存先を通して同期する。
/// 登録済みかどうかは、保存済みの一覧に含まれているかで決まる。
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
    /// 直近のブックマークの読み込み・保存の失敗。画面でアラートとして表示し、閉じたら `nil` に戻す。
    private(set) var bookmarkStorageError: BookmarkStorageError?

    var isShowingBookmarkStorageError: Bool {
        get { bookmarkStorageError != nil }
        set {
            if !newValue {
                bookmarkStorageError = nil
            }
        }
    }

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
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Search failed: \(String(describing: error), privacy: .public)")
                // 前回の結果が残っていると今回の結果と誤解されるため、消してから失敗を表示する
                repositories = []
                phase = .failed(error)
            }
        }
    }

    /// 検索に失敗したときに画面に表示する文言。原因に応じて、利用者が取れる対応が分かるようにする。
    static func failureMessage(for error: APIError) -> String {
        switch error {
        case .network(.notConnectedToInternet), .network(.networkConnectionLost), .network(.dataNotAllowed):
            return "インターネットに接続されていません。接続を確認してから再度お試しください。"
        case .network(.timedOut):
            return "通信がタイムアウトしました。通信環境の良い場所で再度お試しください。"
        case .httpStatus(403), .httpStatus(429):
            // GitHub の検索 API は回数制限を超えると 403 または 429 を返す
            return "検索できる回数の上限に達しました。しばらく時間をおいて再度お試しください。"
        case .httpStatus(422):
            return "検索できないキーワードです。キーワードを見直してください。"
        case .httpStatus(500...599):
            return "GitHub で問題が発生しています。時間をおいて再度お試しください。"
        case .decoding, .invalidResponse:
            return "予期しない応答を受け取りました。時間をおいて再度お試しください。"
        case .network, .httpStatus, .invalidRequest, .unexpected:
            return "検索に失敗しました。時間をおいて再度お試しください。"
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
            bookmarks.append(repository)
        } else {
            bookmarks.removeAll { $0.id == repository.id }
        }
        saveBookmarks(bookmarks)
    }

    // MARK: - Private

    private func clearResults() {
        searchTask?.cancel()
        searchTask = nil
        repositories = []
        phase = .idle
    }

    /// - Returns: 読み込めなかった場合は `nil`（失敗は `bookmarkStorageError` とログに残す）
    private func readStoredBookmarks() -> [Repository]? {
        do {
            return try bookmarkStorage.loadBookmarks()
        } catch {
            logger.error("Failed to load bookmarks: \(String(describing: error), privacy: .public)")
            bookmarkStorageError = error
            return nil
        }
    }

    private func saveBookmarks(_ bookmarks: [Repository]) {
        do {
            try bookmarkStorage.saveBookmarks(bookmarks)
            bookmarkStorageError = nil
        } catch {
            logger.error("Failed to save bookmarks: \(String(describing: error), privacy: .public)")
            bookmarkStorageError = error
        }
    }
}
