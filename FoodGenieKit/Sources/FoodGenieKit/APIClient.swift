/// Mobile gateway client. Every failure is an APIError whose message can be shown to the user
/// as is, except cancellation, which is rethrown as CancellationError so callers can ignore it.

import Foundation

public struct APIError: Error, Sendable, Equatable {
    public let message: String
    public let status: Int?

    public init(_ message: String, status: Int? = nil) {
        self.message = message
        self.status = status
    }
}

public extension Error {
    /// A message for the user: the gateway's for APIError, else the system's.
    var userMessage: String {
        (self as? APIError)?.message ?? localizedDescription
    }
}

public final class APIClient: Sendable {
    public let baseURL: URL
    private let appKey: String?
    private let clientId: String
    private let session: URLSession

    public init(baseURL: URL, appKey: String?, clientId: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.appKey = appKey
        self.clientId = clientId
        self.session = session
    }

    // MARK: Endpoints

    public func health() async throws -> Health {
        try await send(get("api/health"), timeout: 8)
    }

    public func nearby(lat: Double, lng: Double) async throws -> Nearby {
        try await send(get("api/nearby", ["lat": String(lat), "lng": String(lng)]), timeout: 60)
    }

    public func ask(_ question: String, locationId: String?) async throws -> AskResult {
        try await send(post("api/ask", AskBody(question: question, location_id: locationId)), timeout: 120)
    }

    public func web(_ query: String) async throws -> WebResult {
        try await send(post("api/web", WebBody(query: query)), timeout: 120)
    }

    public func scan(_ barcode: String, lat: Double?, lng: Double?, locationId: String?) async throws -> ScanResult {
        try await send(post("api/scan", ScanBody(barcode: barcode, lat: lat, lng: lng, location_id: locationId)),
                       timeout: 60)
    }

    public func scanStatus(_ barcode: String, locationId: String?) async throws -> ScanResult {
        try await send(get("api/scan/\(barcode)", ["location_id": locationId]), timeout: 60)
    }

    public func product(_ code: String, locationId: String?) async throws -> Product {
        try await send(get("api/products/\(code)", ["location_id": locationId]), timeout: 60)
    }

    // MARK: Requests

    private struct AskBody: Encodable { let question: String; let location_id: String? }
    private struct WebBody: Encodable { let query: String }
    private struct ScanBody: Encodable {
        let barcode: String
        let lat: Double?
        let lng: Double?
        let location_id: String?
    }

    func url(_ path: String, _ query: [String: String?] = [:]) -> URL {
        let full = baseURL.appending(path: path)
        let items = query.compactMap { k, v in v.flatMap { $0.isEmpty ? nil : URLQueryItem(name: k, value: $0) } }
            .sorted { $0.name < $1.name }
        guard !items.isEmpty, var parts = URLComponents(url: full, resolvingAgainstBaseURL: false) else { return full }
        parts.queryItems = items
        return parts.url ?? full
    }

    private func get(_ path: String, _ query: [String: String?] = [:]) -> URLRequest {
        URLRequest(url: url(path, query))
    }

    private func post(_ path: String, _ body: some Encodable) -> URLRequest {
        var req = URLRequest(url: url(path))
        req.httpMethod = "POST"
        req.httpBody = try? JSONEncoder().encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private func send<T: Decodable>(_ request: URLRequest, timeout: TimeInterval) async throws -> T {
        var req = request
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(clientId, forHTTPHeaderField: "X-Client-Id")
        if let appKey, !appKey.isEmpty { req.setValue(appKey, forHTTPHeaderField: "X-App-Key") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let e as URLError where e.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch let e as URLError where e.code == .timedOut {
            throw APIError("That took too long. Please try again.")
        } catch {
            throw APIError("Can’t reach Food Genie right now. Check your connection.")
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        guard (200..<300).contains(status) else { throw Self.error(status: status, body: data) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError("Something went wrong reading the response.", status: status)
        }
    }

    static func error(status: Int, body: Data) -> APIError {
        if status == 429 { return APIError("You’ve asked a lot this hour. Please try again a bit later.", status: 429) }
        struct Detail: Decodable { let detail: String }
        if let detail = try? JSONDecoder().decode(Detail.self, from: body).detail, !detail.isEmpty {
            return APIError(detail, status: status)
        }
        return APIError("Something went wrong (\(status)).", status: status)
    }
}
