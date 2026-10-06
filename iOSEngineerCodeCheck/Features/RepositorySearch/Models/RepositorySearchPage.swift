//
//  RepositorySearchPage.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// 検索結果の 1 ページ分。次のページを読み込めるかは API の制約をもとに Service が判断する。
struct RepositorySearchPage: Equatable, Sendable {
    let repositories: [Repository]
    let hasNextPage: Bool
}
