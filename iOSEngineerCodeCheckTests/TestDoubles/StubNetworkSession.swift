//
//  StubNetworkSession.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
@testable import iOSEngineerCodeCheck

/// 決まったレスポンス（または失敗）を返す `NetworkSession`。実際のネットワークには接続しない。
struct StubNetworkSession: NetworkSession {

    enum Outcome: Sendable {
        case response(statusCode: Int, body: Data)
        case nonHTTPResponse
        case failure(URLError.Code)
    }

    let outcome: Outcome

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        // URL は APIClient が組み立て済みのため、取得できない場合はテスト側の前提が崩れている
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        switch outcome {
        case let .response(statusCode, body):
            guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badServerResponse)
            }
            return (body, response)
        case .nonHTTPResponse:
            let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        case let .failure(code):
            throw URLError(code)
        }
    }
}

extension StubNetworkSession {
    static func json(_ json: String, statusCode: Int = 200) -> StubNetworkSession {
        StubNetworkSession(outcome: .response(statusCode: statusCode, body: Data(json.utf8)))
    }
}
