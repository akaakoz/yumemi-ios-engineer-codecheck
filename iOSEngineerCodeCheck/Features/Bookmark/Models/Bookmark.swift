//
//  Bookmark.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// `isMarked` は Bookmark タブの詳細画面での登録状態。Search タブでの登録状態（保存済みの一覧に含まれるか）とは別に持つ。
///
/// - Important: 保存形式は `Repository` の各項目と `marked` を同じ階層に並べた JSON。
///   保存済みのブックマークを読み込めるよう、キー名を変えないこと。
struct Bookmark: Codable, Hashable, Identifiable, Sendable {
    let repository: Repository
    var isMarked: Bool

    var id: String { repository.id }

    init(repository: Repository, isMarked: Bool) {
        self.repository = repository
        self.isMarked = isMarked
    }

    private enum CodingKeys: String, CodingKey {
        case marked
    }

    init(from decoder: any Decoder) throws {
        repository = try Repository(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `marked` が保存されていないデータは登録状態が分からないため、未登録として扱う
        isMarked = try container.decodeIfPresent(Bool.self, forKey: .marked) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        try repository.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isMarked, forKey: .marked)
    }
}
