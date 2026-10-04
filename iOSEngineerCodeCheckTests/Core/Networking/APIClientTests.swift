//
//  APIClientTests.swift
//  iOSEngineerCodeCheckTests
//

import Foundation
import Testing
@testable import iOSEngineerCodeCheck

@Suite("APIClient")
struct APIClientTests {

    private struct SampleRequest: APIRequest {
        struct Response: Decodable, Equatable {
            let fullName: String
        }

        var path = "/sample"
        var queryItems: [URLQueryItem] = []
    }

    @Test("クエリはパーセントエンコードされて URL に含まれる")
    func makeURLRequestEncodesQuery() throws {
        let client = APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession.json("{}"))
        let request = SampleRequest(queryItems: [URLQueryItem(name: "q", value: "swift ui 日本語")])

        let urlRequest = try client.makeURLRequest(for: request)

        #expect(urlRequest.url?.absoluteString == "https://api.github.com/sample?q=swift%20ui%20%E6%97%A5%E6%9C%AC%E8%AA%9E")
    }

    @Test("snake_case のキーを camelCase のプロパティへデコードする")
    func sendDecodesSnakeCaseResponse() async throws {
        let client = APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession.json(#"{"full_name": "apple/swift"}"#))

        let response = try await client.send(SampleRequest())

        #expect(response == SampleRequest.Response(fullName: "apple/swift"))
    }

    @Test("2xx 以外のステータスコードは httpStatus として throw する", arguments: [403, 422, 500])
    func sendThrowsHTTPStatusError(statusCode: Int) async {
        let client = APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession.json(#"{"message": "error"}"#, statusCode: statusCode))

        await #expect(throws: APIError.httpStatus(statusCode)) {
            try await client.send(SampleRequest())
        }
    }

    @Test("想定外の形式の JSON は decoding として throw する")
    func sendThrowsDecodingErrorForUnexpectedJSON() async {
        let client = APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession.json(#"{"unexpected": true}"#))

        let error = await #expect(throws: APIError.self) {
            try await client.send(SampleRequest())
        }
        guard case .decoding = error else {
            Issue.record("decoding エラーを期待したが \(String(describing: error)) だった")
            return
        }
    }

    @Test("JSON でないレスポンスは decoding として throw する")
    func sendThrowsDecodingErrorForBrokenBody() async {
        let client = APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession.json("<html>not json</html>"))

        let error = await #expect(throws: APIError.self) {
            try await client.send(SampleRequest())
        }
        guard case .decoding = error else {
            Issue.record("decoding エラーを期待したが \(String(describing: error)) だった")
            return
        }
    }

    @Test("通信の失敗は URLError のコードを保持した network として throw する")
    func sendThrowsNetworkError() async {
        let client = APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession(outcome: .failure(.notConnectedToInternet)))

        await #expect(throws: APIError.network(.notConnectedToInternet)) {
            try await client.send(SampleRequest())
        }
    }

    @Test("接続先の上書きが指定されている場合はその接続先にリクエストする")
    func defaultBaseURLUsesOverride() throws {
        let suiteName = "APIClientTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set("http://localhost:8080", forKey: APIClient.baseURLOverrideKey)
        let client = APIClient(baseURL: APIClient.defaultBaseURL(userDefaults: userDefaults), session: StubNetworkSession.json("{}"))

        let urlRequest = try client.makeURLRequest(for: SampleRequest())

        #expect(urlRequest.url?.absoluteString == "http://localhost:8080/sample")
    }

    @Test("接続先の上書きが無い場合は GitHub に接続する")
    func defaultBaseURLIsGitHub() throws {
        let suiteName = "APIClientTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        #expect(APIClient.defaultBaseURL(userDefaults: userDefaults) == APIClient.gitHubBaseURL)
    }

    @Test("HTTP 以外のレスポンスは invalidResponse として throw する")
    func sendThrowsInvalidResponse() async {
        let client = APIClient(baseURL: APIClient.gitHubBaseURL, session: StubNetworkSession(outcome: .nonHTTPResponse))

        await #expect(throws: APIError.invalidResponse) {
            try await client.send(SampleRequest())
        }
    }
}
