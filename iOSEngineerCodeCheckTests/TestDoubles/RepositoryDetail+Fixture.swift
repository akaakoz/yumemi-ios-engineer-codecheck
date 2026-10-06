//
//  RepositoryDetail+Fixture.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
@testable import iOSEngineerCodeCheck

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
