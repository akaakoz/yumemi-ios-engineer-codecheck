//
//  RepositorySearchResponse.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct RepositorySearchResponse: Decodable, Sendable {
    /// 検索条件に一致した全件数（取得できるのは、このうち先頭の最大 1,000 件まで）
    let totalCount: Int
    let items: [Repository]
}
