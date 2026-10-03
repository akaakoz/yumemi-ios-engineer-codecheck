//
//  AppStrings.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

/// ユーザー向けの文言。ローカライズ時に String Catalog へ移しやすいよう、画面ごとにここへ集約する。
///
/// 旧実装の `Text("\(count) stars")` と同じ表示（ロケールに応じた数値の書式）を保つため `LocalizedStringKey` を使う。
enum AppStrings {

    enum MainTab {
        static var bookmarkTab: LocalizedStringKey { "Bookmark" }
        static var searchTab: LocalizedStringKey { "Search" }
    }

    enum RepositorySearch {
        static var navigationTitle: LocalizedStringKey { "Search" }
        /// 起動直後に検索欄へ入力値として表示する案内文（TextField の値になるため String）
        static var initialFieldText: String { String(localized: "GitHubのリポジトリを検索できるよー") }
        static var emptyMessage: LocalizedStringKey { "GitHubのリポジトリを検索できるよー" }
    }

    enum BookmarkList {
        static var navigationTitle: LocalizedStringKey { "Bookmarks" }
        static var emptyMessage: LocalizedStringKey { "検索ボタンをタップして" }
    }

    enum RepositoryDetail {
        static var addBookmark: LocalizedStringKey { "Add to Bookmark" }
        static var removeBookmark: LocalizedStringKey { "Remove from Bookmark" }

        static func writtenIn(_ language: String) -> LocalizedStringKey {
            "Written in \(language)"
        }

        static func stars(_ count: Int) -> LocalizedStringKey {
            "\(count) stars"
        }

        static func watchers(_ count: Int) -> LocalizedStringKey {
            "\(count) watchers"
        }

        static func forks(_ count: Int) -> LocalizedStringKey {
            "\(count) forks"
        }

        static func openIssues(_ count: Int) -> LocalizedStringKey {
            "\(count) open issues"
        }
    }
}
