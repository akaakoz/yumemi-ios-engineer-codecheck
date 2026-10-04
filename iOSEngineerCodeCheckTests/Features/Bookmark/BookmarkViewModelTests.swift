//
//  BookmarkViewModelTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@MainActor
@Suite("BookmarkViewModel")
struct BookmarkViewModelTests {

    // MARK: - 読み込み

    @Test("生成しただけでは読み込まず、loadBookmarks で保存済みのブックマークを読み込む")
    func loadsSavedBookmarks() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two", isMarked: false)])
        let viewModel = BookmarkViewModel(storage: storage)

        #expect(viewModel.bookmarks.isEmpty)

        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks == storage.savedBookmarks)
        #expect(viewModel.storageError == nil)
    }

    @Test("読み込み直すと、保存先で追加・削除されたブックマークを反映する")
    func reloadReflectsStorageChanges() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        // Search タブでの追加・削除を想定して、保存先を直接書き換える
        try storage.saveBookmarks([.fixture(fullName: "b/two"), .fixture(fullName: "c/three")])
        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks == [.fixture(fullName: "b/two"), .fixture(fullName: "c/three")])
    }

    @Test("読み込み直しても、すでに一覧にある項目は保存されていない isMarked の変更を残す")
    func reloadKeepsUnsavedMarkedState() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()
        viewModel.setMarked(.fixture(fullName: "a/one"), isMarked: false)

        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks == [.fixture(fullName: "a/one", isMarked: false), .fixture(fullName: "b/two")])
    }

    @Test("保存データを読み込めない場合は空にし、失敗を storageError として公開する")
    func exposesLoadFailure() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        storage.loadError = .loadFailed(description: "broken")
        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks.isEmpty)
        #expect(viewModel.storageError == .loadFailed(description: "broken"))
    }

    @Test("読み込みに成功すると直前の失敗はクリアされる")
    func successfulLoadClearsError() {
        let storage = InMemoryBookmarkStorage(loadError: .loadFailed(description: "broken"))
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        storage.loadError = nil
        viewModel.loadBookmarks()

        #expect(viewModel.storageError == nil)
    }

    // MARK: - Bookmark タブでの操作

    @Test("Bookmark タブで削除しても一覧には残し、isMarked だけを false にして保存はしない")
    func unmarkOnlyChangesFlag() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        viewModel.setMarked(.fixture(fullName: "a/one"), isMarked: false)

        #expect(viewModel.bookmarks == [.fixture(fullName: "a/one", isMarked: false)])
        #expect(!viewModel.isMarked(.fixture(fullName: "a/one")))
        #expect(storage.saveCallCount == 0)
    }

    @Test("Bookmark タブで再度追加すると isMarked を true に戻す")
    func remarkRestoresFlag() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one", isMarked: false)])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        viewModel.setMarked(.fixture(fullName: "a/one"), isMarked: true)

        #expect(viewModel.isMarked(.fixture(fullName: "a/one")))
        #expect(storage.saveCallCount == 0)
    }

    @Test("一覧に無いリポジトリを操作しても何もしない")
    func operationForUnknownRepositoryIsIgnored() {
        let viewModel = BookmarkViewModel(storage: InMemoryBookmarkStorage())
        viewModel.loadBookmarks()

        viewModel.setMarked(.fixture(fullName: "a/one"), isMarked: true)

        #expect(viewModel.bookmarks.isEmpty)
    }
}
