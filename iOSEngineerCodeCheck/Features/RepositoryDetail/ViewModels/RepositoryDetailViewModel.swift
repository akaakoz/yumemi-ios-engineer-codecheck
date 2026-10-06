//
//  RepositoryDetailViewModel.swift
//  iOSEngineerCodeCheck
//

import Foundation
import Observation
import os

/// 詳細画面の状態。Search タブから開いた場合は、画面を開いたときにリポジトリ API から詳細を取得する。
/// Bookmark タブから開いた場合は、保存している詳細だけで表示し、通信しない。
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

    private let source: Source
    private let apiService: RepositoryDetailAPIServiceProtocol
    private let logger = Logger(subsystem: "jp.yumemi.iOSEngineerCodeCheck", category: "RepositoryDetail")

    init(source: Source, apiService: RepositoryDetailAPIServiceProtocol = RepositoryDetailAPIService()) {
        self.source = source
        self.apiService = apiService
        switch source {
        case .remote(let fullName):
            self.fullName = fullName
            phase = .loading
        case .saved(let detail):
            fullName = detail.fullName
            phase = .loaded(detail)
        }
    }

    /// Search タブから開いた場合だけ、リポジトリ API から詳細を取得する。
    func loadRepositoryDetail() async {
        guard case .remote = source else {
            return
        }
        phase = .loading
        do throws(APIError) {
            phase = .loaded(try await apiService.fetchRepositoryDetail(fullName: fullName))
        } catch {
            // 画面を閉じてキャンセルされた場合は、失敗として扱わない
            guard !Task.isCancelled else { return }
            logger.error("Failed to fetch repository detail: \(String(describing: error), privacy: .public)")
            phase = .failed(error)
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
}
