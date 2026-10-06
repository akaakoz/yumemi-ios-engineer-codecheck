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
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let viewModel = BookmarkViewModel(storage: storage)

        #expect(viewModel.bookmarks.isEmpty)

        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks == storage.savedBookmarks)
        #expect(viewModel.storageError == nil)
    }

    @Test("読み込み直すと、Search タブで追加・削除された内容を反映する")
    func reloadReflectsStorageChanges() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        // Search タブでの追加・削除を想定して、保存先を直接書き換える
        try storage.saveBookmarks([.fixture(fullName: "b/two"), .fixture(fullName: "c/three")])
        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks == [.fixture(fullName: "b/two"), .fixture(fullName: "c/three")])
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

    // MARK: - 追加・削除

    @Test("削除すると一覧から消え、保存される")
    func removeDeletesAndSaves() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        viewModel.removeBookmark(fullName: "a/one")

        #expect(viewModel.bookmarks == [.fixture(fullName: "b/two")])
        #expect(!viewModel.isBookmarked(fullName: "a/one"))
        #expect(storage.savedBookmarks == [.fixture(fullName: "b/two")])
    }

    @Test("削除した後に追加し直すと、末尾に再登録されて保存される")
    func reAddAppendsToEnd() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        viewModel.removeBookmark(fullName: "a/one")
        viewModel.addBookmark(.fixture(fullName: "a/one"))

        #expect(viewModel.bookmarks == [.fixture(fullName: "b/two"), .fixture(fullName: "a/one")])
        #expect(viewModel.isBookmarked(fullName: "a/one"))
        #expect(storage.savedBookmarks == viewModel.bookmarks)
    }

    @Test("削除した内容は、読み込み直しても戻らない")
    func removalSurvivesReload() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()
        viewModel.removeBookmark(fullName: "a/one")

        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks.isEmpty)
    }

    @Test("登録状態が変わらない操作では保存しない")
    func noOpOperationDoesNotSave() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        viewModel.addBookmark(.fixture(fullName: "a/one"))
        viewModel.removeBookmark(fullName: "b/two")

        #expect(storage.saveCallCount == 0)
    }

    @Test("一覧を読み込んだ後に Search タブで追加されたブックマークは、削除しても残る")
    func removeKeepsBookmarkAddedFromSearchTab() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()
        // 詳細画面を開いている間に、Search タブで追加されたことを想定して保存先を直接書き換える
        try storage.saveBookmarks([.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])

        viewModel.removeBookmark(fullName: "a/one")

        #expect(storage.savedBookmarks == [.fixture(fullName: "b/two")])
        #expect(viewModel.bookmarks == [.fixture(fullName: "b/two")])
    }

    @Test("一覧を読み込んだ後に Search タブで追加されたブックマークは、再登録しても残る")
    func reAddKeepsBookmarkAddedFromSearchTab() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()
        viewModel.removeBookmark(fullName: "a/one")
        try storage.saveBookmarks([.fixture(fullName: "b/two")])

        viewModel.addBookmark(.fixture(fullName: "a/one"))

        #expect(storage.savedBookmarks == [.fixture(fullName: "b/two"), .fixture(fullName: "a/one")])
        #expect(viewModel.bookmarks == storage.savedBookmarks)
    }

    @Test("Search タブで追加済みのブックマークを再登録しても、重複して保存しない")
    func reAddDoesNotDuplicateBookmarkAddedFromSearchTab() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()
        viewModel.removeBookmark(fullName: "a/one")
        try storage.saveBookmarks([.fixture(fullName: "a/one")])
        let saveCountBeforeAdd = storage.saveCallCount

        viewModel.addBookmark(.fixture(fullName: "a/one"))

        #expect(storage.savedBookmarks == [.fixture(fullName: "a/one")])
        #expect(storage.saveCallCount == saveCountBeforeAdd)
        #expect(viewModel.isBookmarked(fullName: "a/one"))
    }

    @Test("Search タブで削除済みのブックマークを削除しても保存せず、一覧を保存先に合わせる")
    func removeOfBookmarkRemovedFromSearchTabOnlyRefreshesList() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()
        try storage.saveBookmarks([.fixture(fullName: "b/two")])
        let saveCountBeforeRemove = storage.saveCallCount

        viewModel.removeBookmark(fullName: "a/one")

        #expect(storage.saveCallCount == saveCountBeforeRemove)
        #expect(viewModel.bookmarks == [.fixture(fullName: "b/two")])
    }

    @Test("追加・削除の前に保存先を読み込めない場合は保存せず、失敗を storageError として公開する")
    func operationDoesNotSaveWhenLoadFails() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()
        storage.loadError = .loadFailed(description: "broken")

        viewModel.removeBookmark(fullName: "a/one")

        #expect(storage.saveCallCount == 0)
        #expect(viewModel.bookmarks == [.fixture(fullName: "a/one")])
        #expect(viewModel.storageError == .loadFailed(description: "broken"))
    }

    @Test("削除の保存に失敗した場合は一覧を変えず、失敗を storageError として公開する")
    func removeKeepsListWhenSaveFails() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        storage.saveError = .saveFailed(description: "disk full")
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()

        viewModel.removeBookmark(fullName: "a/one")

        #expect(viewModel.bookmarks == [.fixture(fullName: "a/one")])
        #expect(viewModel.isBookmarked(fullName: "a/one"))
        #expect(viewModel.storageError == .saveFailed(description: "disk full"))
    }

    @Test("再登録の保存に失敗した場合は一覧を変えず、失敗を公開する")
    func reAddKeepsListWhenSaveFails() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()
        viewModel.removeBookmark(fullName: "a/one")
        storage.saveError = .saveFailed(description: "disk full")

        viewModel.addBookmark(.fixture(fullName: "a/one"))

        #expect(viewModel.bookmarks.isEmpty)
        #expect(!viewModel.isBookmarked(fullName: "a/one"))
        #expect(viewModel.storageError == .saveFailed(description: "disk full"))
    }

    @Test("保存に失敗した後に読み込み直しても、一覧が変わらない")
    func listIsConsistentAfterReloadFollowingSaveFailure() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        storage.saveError = .saveFailed(description: "disk full")
        let viewModel = BookmarkViewModel(storage: storage)
        viewModel.loadBookmarks()
        viewModel.removeBookmark(fullName: "a/one")
        let listBeforeReload = viewModel.bookmarks

        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks == listBeforeReload)
    }

    // MARK: - 失敗の表示
    @Test("失敗の表示を閉じると storageError がクリアされる")
    func dismissingErrorClearsIt() {
        let viewModel = BookmarkViewModel(storage: InMemoryBookmarkStorage(loadError: .loadFailed(description: "broken")))
        viewModel.loadBookmarks()
        #expect(viewModel.isShowingStorageError)

        viewModel.isShowingStorageError = false

        #expect(viewModel.storageError == nil)
    }

    @Test(
        "失敗の種類に応じた文言を表示する",
        arguments: [
            (BookmarkStorageError.loadFailed(description: "broken"), "保存されていたブックマークを読み込めませんでした。読み込めなかったデータは別の場所に保管し、空の状態から始めます。"),
            (BookmarkStorageError.saveFailed(description: "disk full"), "ブックマークを保存できませんでした。時間をおいて再度お試しください。"),
        ]
    )
    func storageErrorMessage(error: BookmarkStorageError, expectedMessage: String) {
        #expect(error.message == expectedMessage)
    }
}
