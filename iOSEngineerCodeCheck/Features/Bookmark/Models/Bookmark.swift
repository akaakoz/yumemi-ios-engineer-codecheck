//
//  Bookmark.swift
//  iOSEngineerCodeCheck
//

import Foundation

/// Bookmark タブに並ぶ 1 件。
///
/// `isMarked` は Bookmark タブの詳細画面での登録状態。旧実装の挙動を維持するため、
/// Bookmark タブで Remove しても一覧からは消さずにこのフラグだけを false にする（`BookmarkViewModel` 参照）。
/// Search タブから見た登録状態は、このフラグではなく保存済みの一覧に含まれているかで決まる（`RepositorySearchViewModel` 参照）。
///
/// - Important: 保存形式は旧実装（`Repository` の各項目と `marked` を同じ階層に並べた JSON）と同じにしている。
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
        // 旧実装は `marked == true` のときだけ登録済みとして扱っていたため、欠けている場合は未登録と同じ扱いにする
        isMarked = try container.decodeIfPresent(Bool.self, forKey: .marked) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        try repository.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isMarked, forKey: .marked)
    }
}
