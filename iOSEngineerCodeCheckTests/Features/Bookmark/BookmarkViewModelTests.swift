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
        let viewModel = BookmarkViewModel(bookmarkService: BookmarkService(storage: storage))

        #expect(viewModel.bookmarks.isEmpty)

        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks == storage.savedBookmarks)
        #expect(viewModel.storageError == nil)
    }

    @Test("読み込み直すと、詳細画面などで追加・削除された内容を反映する")
    func reloadReflectsStorageChanges() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let viewModel = BookmarkViewModel(bookmarkService: BookmarkService(storage: storage))
        viewModel.loadBookmarks()

        // 詳細画面での追加・削除を想定して、保存先を直接書き換える
        try storage.saveBookmarks([.fixture(fullName: "b/two"), .fixture(fullName: "c/three")])
        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks == [.fixture(fullName: "b/two"), .fixture(fullName: "c/three")])
    }

    @Test("保存データを読み込めない場合は空にし、失敗を storageError として公開する")
    func exposesLoadFailure() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let viewModel = BookmarkViewModel(bookmarkService: BookmarkService(storage: storage))
        viewModel.loadBookmarks()

        storage.loadError = .loadFailed(description: "broken")
        viewModel.loadBookmarks()

        #expect(viewModel.bookmarks.isEmpty)
        #expect(viewModel.storageError == .loadFailed(description: "broken"))
    }

    // MARK: - 失敗の表示
    @Test("失敗の表示を閉じると storageError がクリアされる")
    func dismissingErrorClearsIt() {
        let viewModel = BookmarkViewModel(bookmarkService: BookmarkService(storage: InMemoryBookmarkStorage(loadError: .loadFailed(description: "broken"))))
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
