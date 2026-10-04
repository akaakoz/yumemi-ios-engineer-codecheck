//
//  RepositorySearchResponse.swift
//  iOSEngineerCodeCheck
//

import Foundation

struct RepositorySearchResponse: Decodable, Sendable {
    let items: [Repository]
}
