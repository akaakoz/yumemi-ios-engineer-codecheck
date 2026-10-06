//
//  Repository.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct Repository: Decodable, Hashable, Identifiable, Sendable {
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
    struct Owner: Decodable, Hashable, Sendable {
        let avatarURLString: String

        /// 不正な文字列の場合は `nil`（画面ではプレースホルダー画像を表示する）
        var avatarURL: URL? { URL(string: avatarURLString) }

        /// API のレスポンス（`avatar_url` を変換したもの）と保存済みのブックマークのキーに合わせる
        private enum CodingKeys: String, CodingKey {
            case avatarURLString = "avatarUrl"
        }
    }
}
