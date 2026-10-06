//
//  BookmarkStorageError+Message.swift
//  iOSEngineerCodeCheck
//

import Foundation

extension BookmarkStorageError {
    /// 画面に表示する文言
    var message: String {
        switch self {
        case .loadFailed:
            "保存されていたブックマークを読み込めませんでした。読み込めなかったデータは別の場所に保管し、空の状態から始めます。"
        case .saveFailed:
            "ブックマークを保存できませんでした。時間をおいて再度お試しください。"
        }
    }
}
