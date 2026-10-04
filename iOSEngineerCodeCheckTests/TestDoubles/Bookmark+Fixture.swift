//
//  Bookmark+Fixture.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
@testable import iOSEngineerCodeCheck

extension Bookmark {
    static func fixture(fullName: String, isMarked: Bool = true) -> Bookmark {
        Bookmark(repository: .fixture(fullName: fullName), isMarked: isMarked)
    }
}
