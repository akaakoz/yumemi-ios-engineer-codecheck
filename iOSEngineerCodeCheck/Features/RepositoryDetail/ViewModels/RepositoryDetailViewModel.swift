//
//  RepositoryDetailViewModel.swift
//  iOSEngineerCodeCheck
//

import Foundation
import Observation
import os

/// 詳細画面の状態。Search タブから開いた場合は、画面を開いたときにリポジトリ API から詳細を取得する。
/// Bookmark タブから開いた場合は、保存している詳細だけで表示し、通信しない。
///
/// ブックマークの登録状態は、どちらのタブから開いた場合も、画面が表示されるたびに保存先から読み込む。
/// 保存に成功したときだけ登録状態を変え、失敗したときは変えずに保存先の内容と食い違わないようにする。
@MainActor
@Observable
final class RepositoryDetailViewModel {

    /// 表示する詳細の取得元
    enum Source {
        /// リポジトリ API から取得する。"owner/name" の形式のリポジトリ名を持つ
        case remote(fullName: String)
        /// ブックマークに保存している詳細を使う
        case saved(RepositoryDetail)
    }

    enum Phase: Equatable {
        case loading
        case loaded(RepositoryDetail)
        case failed(APIError)
    }

    private(set) var phase: Phase

    /// 表示できている詳細。ブックマークに追加するときに使う
    var loadedDetail: RepositoryDetail? {
        if case .loaded(let detail) = phase {
            return detail
        }
        return nil
    }

    /// "owner/name" の形式のリポジトリ名。詳細を表示できるまでのタイトルに使う
    let fullName: String

    private(set) var isBookmarked = false
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

    /// 実行中の取得。画面が表示し直されても、重ねて取得しない
    @ObservationIgnored private(set) var loadTask: Task<Void, Never>?

    private let source: Source
    private let apiService: RepositoryDetailAPIServiceProtocol
    private let bookmarkService: BookmarkServiceProtocol
    private let logger = Logger(subsystem: "jp.yumemi.iOSEngineerCodeCheck", category: "RepositoryDetail")

    init(
        source: Source,
        apiService: RepositoryDetailAPIServiceProtocol = RepositoryDetailAPIService(),
        bookmarkService: BookmarkServiceProtocol = BookmarkService()
    ) {
        self.source = source
        self.apiService = apiService
        self.bookmarkService = bookmarkService
        switch source {
        case .remote(let fullName):
            self.fullName = fullName
            phase = .loading
        case .saved(let detail):
            fullName = detail.fullName
            phase = .loaded(detail)
        }
    }

    /// 画面が表示されたときに呼ぶ。Search タブから開いた場合に、まだ取得していなければリポジトリ API から詳細を取得する。
    /// 取得中・表示済み・失敗後（`reload()` を待つ）は何もしない。
    func loadIfNeeded() {
        guard case .remote = source, phase == .loading, loadTask == nil else {
            return
        }
        load()
    }

    /// 取得に失敗した詳細を、もう一度取得する。
    func reload() {
        guard case .failed = phase else {
            return
        }
        load()
    }

    // MARK: - ブックマーク

    /// 画面が表示されたときに呼ぶ。もう一方のタブでの変更も含めて、保存先から登録状態を読み込む。
    func loadBookmarkState() {
        do {
            isBookmarked = try bookmarkService.loadBookmarks().contains { $0.fullName == fullName }
        } catch {
            logger.error("Failed to load bookmarks: \(String(describing: error), privacy: .public)")
            bookmarkStorageError = error
        }
    }

    /// 表示できている詳細をブックマークに追加する。詳細を表示できるまでは何もしない。
    func addBookmark() {
        guard let loadedDetail else {
            return
        }
        updateBookmarks { () throws(BookmarkStorageError) in
            try bookmarkService.addBookmark(loadedDetail)
        }
    }

    /// ブックマークから削除する。画面は表示したまま残り、`addBookmark()` で追加し直せる。
    func removeBookmark() {
        updateBookmarks { () throws(BookmarkStorageError) in
            try bookmarkService.removeBookmark(fullName: fullName)
        }
    }

    /// 取得に失敗したときに画面に表示する文言。原因に応じて、利用者が取れる対応が分かるようにする。
    static func failureMessage(for error: APIError) -> String {
        switch error {
        case .network(.notConnectedToInternet), .network(.networkConnectionLost), .network(.dataNotAllowed):
            return "インターネットに接続されていません。接続を確認してから再度お試しください。"
        case .httpStatus(403), .httpStatus(429):
            // GitHub の API は回数制限を超えると 403 または 429 を返す
            return "情報を取得できる回数の上限に達しました。しばらく時間をおいて再度お試しください。"
        case .httpStatus(404):
            return "リポジトリが見つかりませんでした。削除されたか、非公開になった可能性があります。"
        case .network, .httpStatus, .decoding, .invalidResponse, .invalidRequest, .unexpected:
            return "リポジトリの情報を取得できませんでした。時間をおいて再度お試しください。"
        }
    }

    // MARK: - Private

    /// 成功したときだけ登録状態を保存先の内容に合わせ、失敗したときは変えずに `bookmarkStorageError` とログに残す。
    private func updateBookmarks(_ update: () throws(BookmarkStorageError) -> [RepositoryDetail]) {
        do {
            isBookmarked = try update().contains { $0.fullName == fullName }
            bookmarkStorageError = nil
        } catch {
            logger.error("Failed to update bookmarks: \(String(describing: error), privacy: .public)")
            bookmarkStorageError = error
        }
    }
    private func load() {
        phase = .loading
        loadTask = Task {
            do throws(APIError) {
                phase = .loaded(try await apiService.fetchRepositoryDetail(fullName: fullName))
            } catch {
                logger.error("Failed to fetch repository detail: \(String(describing: error), privacy: .public)")
                phase = .failed(error)
            }
        }
    }
}
