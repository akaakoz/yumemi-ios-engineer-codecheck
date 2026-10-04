//
//  MainTabView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct MainTabView: View {

    enum Tab: Hashable {
        case bookmark
        case search
    }

    @State private var selectedTab = Tab.search

    var body: some View {
        TabView(selection: $selectedTab) {
            bookmarkTab
            searchTab
        }
        .tint(.black)
        .background(.ultraThinMaterial)
    }

    private var bookmarkTab: some View {
        NavigationStack {
            BookmarkListView()
        }
        .tabItem {
            Image(systemName: "bookmark.fill")
            Text("Bookmark")
        }
        .tag(Tab.bookmark)
    }

    private var searchTab: some View {
        NavigationStack {
            RepositorySearchView(isSelected: selectedTab == .search)
        }
        .tabItem {
            Image(systemName: "magnifyingglass.circle.fill")
            Text("Search")
        }
        .tag(Tab.search)
    }
}
