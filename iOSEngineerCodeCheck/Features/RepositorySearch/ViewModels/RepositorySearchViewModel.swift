//
//  RepositorySearchViewModel.swift
//  iOSEngineerCodeCheck
//

import Foundation
import Observation
import os

/// 検索結果の状態。最初のページは `search()`、2 ページ目以降は `loadMoreIfNeeded()` で同じ検索条件のまま読み込む。
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

    /// 2 ページ目以降の追加読み込みの状態。最初の検索の状態（`phase`）とは分けて持ち、失敗してもそれまでの結果は残す。
    enum LoadMorePhase: Equatable {
        case idle
        case loading
        /// 自動では読み込み直さず、`retryLoadMore()` を待つ
        case failed(APIError)
    }

    /// 次に読み込むページ。追加読み込みは、表示中の結果と同じキーワード・並び順で行う
    private struct NextPage {
        let keyword: String
        let sort: RepositorySearchSort
        let page: Int
    }

    var query = "" {
        didSet {
            if query.isEmpty {
                clearResults()
            }
        }
    }
    private(set) var phase = Phase.idle
    /// 検索結果の並び順。アプリを終了しても覚えておく
    private(set) var sort: RepositorySearchSort
    private(set) var loadMorePhase = LoadMorePhase.idle
    /// 直近に成功した検索の結果（読み込んだページを順に連結し、同じリポジトリは 1 件にまとめたもの）。
    /// 新しい検索の通信中は前回の結果を表示し続け、失敗したら空にする。
    private(set) var repositories: [Repository] = []

    /// 実行中の検索。新しい検索を始めるときにキャンセルし、古い結果で上書きされないようにする。
    @ObservationIgnored private(set) var searchTask: Task<Void, Never>?
    /// 実行中の追加読み込み。新しい検索を始めるときにキャンセルし、前の検索の続きを新しい結果に混ぜない。
    @ObservationIgnored private(set) var loadMoreTask: Task<Void, Never>?
    /// 次のページが無い場合（最後まで読み込んだ、またはまだ検索に成功していない）は `nil`
    private var nextPage: NextPage?

    /// 続きのページを今読み込める状態か。最初の検索に成功していて、追加読み込みの通信中・失敗中でなく、次のページがある
    var canLoadMore: Bool {
        phase == .loaded && loadMorePhase == .idle && nextPage != nil
    }

    private let apiService: RepositorySearchAPIServiceProtocol
    private let sortStorage: RepositorySearchSortStorageProtocol
    private let logger = Logger(subsystem: "jp.yumemi.iOSEngineerCodeCheck", category: "RepositorySearch")

    init(
        apiService: RepositorySearchAPIServiceProtocol = RepositorySearchAPIService(),
        sortStorage: RepositorySearchSortStorageProtocol = UserDefaultsRepositorySearchSortStorage()
    ) {
        self.apiService = apiService
        self.sortStorage = sortStorage
        sort = sortStorage.loadSort()
    }

    func search() {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return
        }

        cancelLoading()
        phase = .loading
        let sort = sort

        searchTask = Task {
            do throws(APIError) {
                let result = try await apiService.searchRepositories(keyword: keyword, sort: sort, page: 1)
                // キャンセル済み = より新しい検索が始まっている、またはクリアされたので結果を反映しない
                guard !Task.isCancelled else { return }
                repositories = Self.removingDuplicates(result.repositories)
                nextPage = result.hasNextPage ? NextPage(keyword: keyword, sort: sort, page: 2) : nil
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

    /// 並び順を変えて保存する。検索したことがあれば、検索欄の今のキーワードで 1 ページ目から検索し直す。
    /// まだ検索していない場合は、次の検索から使う。
    func changeSort(to newSort: RepositorySearchSort) {
        guard newSort != sort else {
            return
        }
        sort = newSort
        sortStorage.saveSort(newSort)
        if phase != .idle {
            search()
        }
    }

    /// 一覧の一番下が表示されたときに呼ぶ。次のページがあれば、同じ検索条件で読み込んで結果の末尾に足す。
    /// 最初の検索の通信中・追加読み込みの通信中・追加読み込みの失敗後（`retryLoadMore()` を待つ）は何もしない。
    func loadMoreIfNeeded() {
        guard canLoadMore, let nextPage else {
            return
        }
        loadMore(nextPage)
    }

    /// 追加読み込みに失敗したページを、もう一度読み込む。
    func retryLoadMore() {
        guard phase == .loaded, case .failed = loadMorePhase, let nextPage else {
            return
        }
        loadMore(nextPage)
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

    // MARK: - Private

    private func loadMore(_ page: NextPage) {
        loadMorePhase = .loading
        loadMoreTask = Task {
            do throws(APIError) {
                let result = try await apiService.searchRepositories(keyword: page.keyword, sort: page.sort, page: page.page)
                // キャンセル済み = 新しい検索が始まっている、またはクリアされたので、前の検索の続きを反映しない
                guard !Task.isCancelled else { return }
                let existingIDs = Set(repositories.map(\.id))
                // 検索結果の順位は読み込みの間にも変わるため、前のページで表示したリポジトリが再び含まれることがある
                repositories += Self.removingDuplicates(result.repositories).filter { !existingIDs.contains($0.id) }
                nextPage = result.hasNextPage ? NextPage(keyword: page.keyword, sort: page.sort, page: page.page + 1) : nil
                loadMorePhase = .idle
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Loading more search results failed: \(String(describing: error), privacy: .public)")
                loadMorePhase = .failed(error)
            }
        }
    }

    /// 実行中の検索と追加読み込みをキャンセルし、追加読み込みの状態を初期化する
    private func cancelLoading() {
        searchTask?.cancel()
        searchTask = nil
        loadMoreTask?.cancel()
        loadMoreTask = nil
        nextPage = nil
        loadMorePhase = .idle
    }

    private func clearResults() {
        cancelLoading()
        repositories = []
        phase = .idle
    }

    /// 同じリポジトリ（`id` が同じもの）は最初の 1 件だけを残す
    private static func removingDuplicates(_ repositories: [Repository]) -> [Repository] {
        var seenIDs = Set<Repository.ID>()
        return repositories.filter { seenIDs.insert($0.id).inserted }
    }
}
