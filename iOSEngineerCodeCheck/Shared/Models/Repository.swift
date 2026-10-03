//
//  Repository.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// Codable 表現は 2 か所で使われる。
/// - API レスポンスのデコード（`APIClient` が snake_case から変換する）
/// - ブックマークの永続化（`Bookmark` が camelCase のまま保存する）
///
/// - Important: プロパティ名を変えると保存済みのブックマークを読み込めなくなるため、変更時は移行処理を検討すること。
struct Repository: Codable, Hashable, Identifiable, Sendable {
    let fullName: String
    let language: String?
    let stargazersCount: Int
    let watchersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let owner: Owner

    /// GitHub 上で一意な "owner/name" を識別子にする。
    /// スター数などは検索のたびに変わりうるため、同一リポジトリの判定には使わない。
    var id: String { fullName }
}

extension Repository {
    struct Owner: Codable, Hashable, Sendable {
        let avatarUrl: String

        /// 不正な文字列の場合は `nil`（画面ではプレースホルダー画像を表示する）
        var avatarURL: URL? { URL(string: avatarUrl) }
    }
}
