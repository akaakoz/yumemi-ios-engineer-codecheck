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
    private let session: any NetworkSession

    init(
        baseURL: URLComponents = APIClient.defaultBaseURL(),
        session: any NetworkSession = URLSession.shared
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

    /// - Note: `URLComponents` は `+` をエンコードしないため、`c++` は GitHub 側で `c` の検索として扱われる。
    func makeURLRequest<Request: APIRequest>(for request: Request) throws(APIError) -> URLRequest {
        var components = baseURL
        components.path = request.path
        components.queryItems = request.queryItems.isEmpty ? nil : request.queryItems

        guard let url = components.url else {
            throw .invalidRequest
        }
        return URLRequest(url: url)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
