//
//  RepositorySearchSort.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// 検索結果の並び順
enum RepositorySearchSort: String, CaseIterable, Sendable {
    /// GitHub の関連度の順（`sort` を指定しない）
    case bestMatch
    /// Star 数の多い順
    case stars
    /// 最近更新された順
    case updated

    /// 検索 API の `sort` に指定する値。関連度の順では指定しない
    var queryValue: String? {
        switch self {
        case .bestMatch:
            return nil
        case .stars:
            return "stars"
        case .updated:
            return "updated"
        }
    }
}
