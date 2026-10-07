//
//  RepositoryDetailTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@Suite("RepositoryDetail")
struct RepositoryDetailTests {

    @Test("GitHub 上のページは、リポジトリ名から作る")
    func webPageURLIsMadeFromFullName() {
        #expect(RepositoryDetail.fixture(fullName: "apple/swift").webPageURL?.absoluteString == "https://github.com/apple/swift")
    }
}
