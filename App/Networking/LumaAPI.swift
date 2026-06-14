import Foundation

/// The single networking actor for all LUMA API calls.
/// Automatically retries once on 401 after attempting a token refresh.
actor LumaAPI {
    private let baseURL: URL
    // nonisolated let: immutable, so safe to read from any concurrency context
    // without await. AccountModel.init reads this synchronously.
    nonisolated let keychain: KeychainStore

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    init(baseURL: URL = LumaConfig.apiBaseURL,
         keychain: KeychainStore = KeychainStore(service: "com.luma.tuner")) {
        self.baseURL = baseURL
        self.keychain = keychain
    }

    var jwt: String? { keychain.read(key: "jwt") }

    func setJWT(_ token: String) { keychain.write(key: "jwt", value: token) }
    func clearJWT() { keychain.delete(key: "jwt") }

    // MARK: - Convenience methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await perform(method: "GET", path: path, body: nil as EmptyBody?)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await perform(method: "POST", path: path, body: body)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await perform(method: "DELETE", path: path, body: nil as EmptyBody?)
    }

    // MARK: - Core request

    private func perform<B: Encodable, T: Decodable>(
        method: String, path: String, body: B?
    ) async throws -> T {
        var req = makeRequest(method: method, path: path, body: body, token: jwt)
        let (data, response) = try await session.data(for: req)
        let http = response as! HTTPURLResponse

        if http.statusCode == 401 {
            guard let refreshed = try? await refreshToken() else {
                clearJWT()
                throw LumaAPIError.unauthorized
            }
            setJWT(refreshed)
            req = makeRequest(method: method, path: path, body: body, token: refreshed)
            let (data2, _) = try await session.data(for: req)
            return try decode(data2)
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error ?? "Unknown error"
            throw LumaAPIError.server(msg, http.statusCode)
        }
        return try decode(data)
    }

    private func makeRequest<B: Encodable>(
        method: String, path: String, body: B?, token: String?
    ) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body, !(body is EmptyBody) {
            req.httpBody = try? JSONEncoder().encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw LumaAPIError.decoding(error) }
    }

    private func refreshToken() async throws -> String? {
        guard let current = jwt else { return nil }
        var req = URLRequest(url: baseURL.appendingPathComponent("auth/refresh"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(current)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        guard (response as! HTTPURLResponse).statusCode == 200 else { return nil }
        return (try? JSONDecoder().decode(TokenResponse.self, from: data))?.token
    }
}
