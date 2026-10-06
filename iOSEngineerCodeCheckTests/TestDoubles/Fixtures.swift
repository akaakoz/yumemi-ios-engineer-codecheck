//
//  Fixtures.swift
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
            owner: Owner(avatarURLString: "https://avatars.githubusercontent.com/u/10639145")
        )
    }
}

extension RepositoryDetail {
    static func fixture(
        fullName: String = "apple/swift",
        language: String? = "C++",
        stargazersCount: Int = 100,
        subscribersCount: Int? = 2400
    ) -> RepositoryDetail {
        RepositoryDetail(
            fullName: fullName,
            language: language,
            stargazersCount: stargazersCount,
            subscribersCount: subscribersCount,
            forksCount: 5,
            openIssuesCount: 1,
            owner: Owner(avatarURLString: "https://avatars.githubusercontent.com/u/10639145")
        )
    }
}
