//
//  RepositoryDetail.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// リポジトリ API（`GET /repos/{owner}/{repo}`）のレスポンス。詳細画面の表示と、ブックマークの保存に使う。
///
/// 検索 API の `Repository` とは別の API のため、型を分けている。
///
/// - Important: ブックマークの保存形式にも同じ Codable 表現（camelCase のキー）を使う。
///   保存済みのブックマークを読み込めるよう、プロパティ名を変えないこと。
struct RepositoryDetail: Codable, Hashable, Identifiable, Sendable {
    let fullName: String
    let language: String?
    let stargazersCount: Int
    /// 実際の Watch 数（リポジトリの通知を受け取っている人数）。
    /// `watchers_count` は互換性のために残された項目で、Star 数と同じ値になるため使わない。
    /// API のレスポンスには常に含まれる。Watch 数を保存していなかった以前の形式のブックマークから読み込んだ場合は `nil`
    let subscribersCount: Int?
    let forksCount: Int
    let openIssuesCount: Int
    let owner: Owner

    /// GitHub 上で一意な "owner/name" を識別子にする
    var id: String { fullName }
}

extension RepositoryDetail {
    struct Owner: Codable, Hashable, Sendable {
        let avatarURLString: String

        /// 不正な文字列の場合は `nil`（画面ではプレースホルダー画像を表示する）
        var avatarURL: URL? { URL(string: avatarURLString) }

        /// API のレスポンス（`avatar_url` を変換したもの）と保存済みのブックマークのキーに合わせる
        private enum CodingKeys: String, CodingKey {
            case avatarURLString = "avatarUrl"
        }
    }
}

extension RepositoryDetail: RepositoryListItem {}
