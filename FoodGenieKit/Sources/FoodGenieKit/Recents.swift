/// Local history: what this phone has asked and scanned, newest first. A scan keeps only what a
/// row needs; the product page reloads the rest from the gateway with the current store.

import Foundation

public struct RecentScan: Codable, Sendable, Hashable, Identifiable {
    public var code: String
    public var name: String?
    public var brand: String?
    public var imageURL: String?
    public var nutriscore: String?
    public var date: Date

    public var id: String { code }

    public init(_ product: Product, date: Date = .now) {
        code = product.code
        name = product.name
        brand = product.brand
        imageURL = product.displayImageURL
        nutriscore = product.nutriscore
        self.date = date
    }
}

public enum Recents {
    public static let limit = 20

    /// `item` moved to the front, earlier copies (same `key`) dropped, and the list capped at `limit`.
    public static func adding<T, K: Equatable>(_ item: T, to items: [T], by key: (T) -> K, limit: Int = limit) -> [T] {
        let k = key(item)
        return Array(([item] + items.filter { key($0) != k }).prefix(limit))
    }
}
