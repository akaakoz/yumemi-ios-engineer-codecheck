//
//  APIClient.swift
//  iOSEngineerCodeCheck
//

import Foundation

protocol APIClientProtocol: Sendable {
    func send<Request: APIRequest>(_ request: Request) async throws(APIError) -> Request.Response
}

struct APIClient: APIClientProtocol {

    static let gitHubBaseURL: URLComponents = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        return components
    }()

    /// 接続先を上書きする UserDefaults のキー（Debug ビルドのみ有効）。
    /// 起動引数 `-APIBaseURL <URL>` で指定でき、UI テストがローカルのモックサーバーへ接続させるために使う。
    static let baseURLOverrideKey = "APIBaseURL"

    private let baseURL: URLComponents
    private let session: NetworkSession

    init(
        baseURL: URLComponents = APIClient.defaultBaseURL(),
        session: NetworkSession = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    static func defaultBaseURL(userDefaults: UserDefaults = .standard) -> URLComponents {
        #if DEBUG
        if let override = userDefaults.string(forKey: baseURLOverrideKey) {
            guard let components = URLComponents(string: override) else {
                // 指定の誤りに気付けるよう、黙って GitHub に接続せずに止める
                preconditionFailure("\(baseURLOverrideKey) に指定された URL を解釈できません: \(override)")
            }
            return components
        }
        #endif
        return gitHubBaseURL
    }

    func send<Request: APIRequest>(_ request: Request) async throws(APIError) -> Request.Response {
        let urlRequest = try makeURLRequest(for: request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw .network(error.code)
        } catch {
            throw .unexpected(description: String(describing: error))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw .httpStatus(httpResponse.statusCode)
        }

        do {
            return try Self.makeDecoder().decode(Request.Response.self, from: data)
        } catch {
            throw .decoding(description: String(describing: error))
        }
    }

    func makeURLRequest<Request: APIRequest>(for request: Request) throws(APIError) -> URLRequest {
        var components = baseURL
        components.path = request.path
        components.queryItems = request.queryItems.isEmpty ? nil : request.queryItems
        // URLComponents は `+` をエンコードしないが、GitHub はクエリの `+` を空白として扱うため `%2B` にする。
        // 空白は `%20` にエンコードされるので、ここに残る `+` は入力された `+` だけ
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")

        guard let url = components.url else {
            throw .invalidRequest
        }
        return URLRequest(url: url)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // GitHub の日時は ISO 8601 形式（例: 2024-01-01T12:34:56Z）
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
