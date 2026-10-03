//
//  Repository+Fixture.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
@testable import iOSEngineerCodeCheck

extension Repository {
    static func fixture(
        fullName: String = "apple/swift",
        language: String? = "Swift",
        stargazersCount: Int = 100
    ) -> Repository {
        Repository(
            fullName: fullName,
            language: language,
            stargazersCount: stargazersCount,
            watchersCount: 10,
            forksCount: 5,
            openIssuesCount: 1,
            owner: Owner(avatarUrl: "https://avatars.githubusercontent.com/u/10639145")
        )
    }
}
