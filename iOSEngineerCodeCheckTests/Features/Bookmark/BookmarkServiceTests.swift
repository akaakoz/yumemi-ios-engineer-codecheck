//
//  BookmarkServiceTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@Suite("BookmarkService")
struct BookmarkServiceTests {

    @Test("追加すると、保存先の一覧の末尾に足して保存し、変更後の一覧を返す")
    func addAppendsAndSaves() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let service = BookmarkService(storage: storage)

        let bookmarks = try service.addBookmark(.fixture(fullName: "b/two"))

        #expect(bookmarks == [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        #expect(storage.savedBookmarks == bookmarks)
    }

    @Test("登録済みのリポジトリを追加しても、保存せずに保存先の一覧を返す")
    func addDoesNotDuplicate() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one", stargazersCount: 1)])
        let service = BookmarkService(storage: storage)

        let bookmarks = try service.addBookmark(.fixture(fullName: "a/one", stargazersCount: 999))

        #expect(bookmarks == [.fixture(fullName: "a/one", stargazersCount: 1)])
        #expect(storage.saveCallCount == 0)
    }

    @Test("削除すると、保存先の一覧から除いて保存し、変更後の一覧を返す")
    func removeDeletesAndSaves() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])
        let service = BookmarkService(storage: storage)

        let bookmarks = try service.removeBookmark(fullName: "a/one")

        #expect(bookmarks == [.fixture(fullName: "b/two")])
        #expect(storage.savedBookmarks == bookmarks)
    }

    @Test("登録されていないリポジトリを削除しても、保存せずに保存先の一覧を返す")
    func removeOfMissingDoesNotSave() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let service = BookmarkService(storage: storage)

        let bookmarks = try service.removeBookmark(fullName: "b/two")

        #expect(bookmarks == [.fixture(fullName: "a/one")])
        #expect(storage.saveCallCount == 0)
    }

    @Test("呼び出し側が持つ一覧ではなく、保存先の最新の内容に対して変更する")
    func operatesOnLatestStoredBookmarks() throws {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        let service = BookmarkService(storage: storage)
        // もう一方のタブでの追加を想定して、保存先を直接書き換える
        try storage.saveBookmarks([.fixture(fullName: "a/one"), .fixture(fullName: "b/two")])

        let bookmarks = try service.removeBookmark(fullName: "a/one")

        #expect(bookmarks == [.fixture(fullName: "b/two")])
    }

    @Test("読み込みに失敗した場合は、保存せずにその失敗を返す")
    func loadFailureIsThrownWithoutSaving() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        storage.loadError = .loadFailed(description: "broken")
        let service = BookmarkService(storage: storage)

        #expect(throws: BookmarkStorageError.loadFailed(description: "broken")) {
            try service.addBookmark(.fixture(fullName: "b/two"))
        }
        #expect(storage.saveCallCount == 0)
    }

    @Test("保存に失敗した場合は、その失敗を返す")
    func saveFailureIsThrown() {
        let storage = InMemoryBookmarkStorage(savedBookmarks: [.fixture(fullName: "a/one")])
        storage.saveError = .saveFailed(description: "disk full")
        let service = BookmarkService(storage: storage)

        #expect(throws: BookmarkStorageError.saveFailed(description: "disk full")) {
            try service.removeBookmark(fullName: "a/one")
        }
        #expect(storage.savedBookmarks == [.fixture(fullName: "a/one")])
    }
}
