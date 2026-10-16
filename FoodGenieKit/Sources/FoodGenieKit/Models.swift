/// Shapes returned by the mobile gateway (product-langflow/mobile_api). Decoding is lenient:
/// a missing or malformed optional field falls back to a default instead of failing the response.

import Foundation

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }

    func optional<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

public enum Nutrient: String, CaseIterable, Sendable {
    case energyKcal = "energy_kcal", proteinG = "protein_g", fatG = "fat_g", carbsG = "carbs_g"
    case sugarsG = "sugars_g", fiberG = "fiber_g", sodiumMg = "sodium_mg"
}

public struct Nutrients: Decodable, Sendable, Equatable {
    public var values: [String: Double]

    public init(_ values: [String: Double] = [:]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode([String: Double?].self)) ?? [:]
        values = raw.compactMapValues { $0 }
    }

    public var isEmpty: Bool { values.isEmpty }
    public subscript(_ n: Nutrient) -> Double? { values[n.rawValue] }
}

public struct KrogerItem: Decodable, Sendable, Equatable {
    public var sold: Bool
    public var inCatalog: Bool
    public var description: String?
    public var size: String?
    public var price: Double?
    public var regularPrice: Double?
    public var onSale: Bool
    public var aisle: String?
    public var imageURL: String?
    public var inStore: Bool?
    public var stockLevel: String?

    enum CodingKeys: String, CodingKey {
        case sold, description, size, price, aisle
        case inCatalog = "in_catalog", regularPrice = "regular_price", onSale = "on_sale", imageURL = "image_url"
        case inStore = "in_store", stockLevel = "stock_level"
    }

    public init(sold: Bool, inCatalog: Bool = true, size: String? = nil, price: Double? = nil,
                regularPrice: Double? = nil, onSale: Bool = false, aisle: String? = nil, stockLevel: String? = nil) {
        self.sold = sold
        self.inCatalog = inCatalog
        self.size = size
        self.price = price
        self.regularPrice = regularPrice
        self.onSale = onSale
        self.aisle = aisle
        self.stockLevel = stockLevel
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sold = c.value(.sold, default: false)
        inCatalog = c.value(.inCatalog, default: false)
        description = c.optional(.description)
        size = c.optional(.size)
        price = c.optional(.price)
        regularPrice = c.optional(.regularPrice)
        onSale = c.value(.onSale, default: false)
        aisle = c.optional(.aisle)
        imageURL = c.optional(.imageURL)
        inStore = c.optional(.inStore)
        stockLevel = c.optional(.stockLevel)
    }
}

public struct Product: Decodable, Sendable, Identifiable, Equatable {
    public var code: String
    public var name: String?
    public var brand: String?
    public var url: String?
    public var servingSize: String?
    public var perServing: Nutrients
    public var per100g: Nutrients
    public var ingredients: String
    public var ingredientCount: Int?
    /// Ingredient group -> "contains" | "possible" | "unknown".
    public var groups: [String: String]
    public var freeOf: [String]
    public var labels: [String]
    public var imageURL: String?
    public var category: String?
    public var allergens: [String]
    /// "usda", "scan", "kroger" or "open_food_facts".
    public var origin: String
    /// Open Food Facts' grade, else our estimate; nil when neither.
    public var nutriscore: String?
    /// "off" or "computed".
    public var nutriscoreSource: String?
    /// Why there's no grade (shown next to NA).
    public var nutriscoreNote: String?
    /// Found online after a scan, not reviewed yet.
    public var preview: Bool
    public var kroger: KrogerItem?

    public var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code, name, brand, url, ingredients, groups, labels, category, allergens, origin, nutriscore, preview, kroger
        case servingSize = "serving_size", perServing = "per_serving", per100g = "per_100g"
        case ingredientCount = "ingredient_count", freeOf = "free_of", imageURL = "image_url"
        case nutriscoreSource = "nutriscore_source", nutriscoreNote = "nutriscore_note"
    }

    public init(code: String, name: String? = nil, brand: String? = nil, perServing: Nutrients = .init(),
                per100g: Nutrients = .init(), groups: [String: String] = [:], freeOf: [String] = [],
                nutriscore: String? = nil, kroger: KrogerItem? = nil) {
        self.code = code
        self.name = name
        self.brand = brand
        self.perServing = perServing
        self.per100g = per100g
        self.ingredients = ""
        self.groups = groups
        self.freeOf = freeOf
        self.labels = []
        self.allergens = []
        self.origin = "usda"
        self.nutriscore = nutriscore
        self.preview = false
        self.kroger = kroger
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        name = c.optional(.name)
        brand = c.optional(.brand)
        url = c.optional(.url)
        servingSize = c.optional(.servingSize)
        perServing = c.value(.perServing, default: Nutrients())
        per100g = c.value(.per100g, default: Nutrients())
        ingredients = c.value(.ingredients, default: "")
        ingredientCount = c.optional(.ingredientCount)
        groups = c.value(.groups, default: [:])
        freeOf = c.value(.freeOf, default: [])
        labels = c.value(.labels, default: [])
        imageURL = c.optional(.imageURL)
        category = c.optional(.category)
        allergens = c.value(.allergens, default: [])
        origin = c.value(.origin, default: "")
        nutriscore = c.optional(.nutriscore)
        nutriscoreSource = c.optional(.nutriscoreSource)
        nutriscoreNote = c.optional(.nutriscoreNote)
        preview = c.value(.preview, default: false)
        kroger = c.optional(.kroger)
    }

    /// The photo to show: the product's own, else the store's when the store sells it.
    public var displayImageURL: String? {
        if let imageURL, !imageURL.isEmpty { return imageURL }
        return kroger?.sold == true ? kroger?.imageURL : nil
    }
}

public struct AskResult: Decodable, Sendable {
    public var question: String
    public var answer: String
    public var notes: [String]
    public var products: [Product]
    public var locationId: String?

    enum CodingKeys: String, CodingKey {
        case question, answer, notes, products
        case locationId = "location_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        question = c.value(.question, default: "")
        answer = c.value(.answer, default: "")
        notes = c.value(.notes, default: [])
        products = c.value(.products, default: [])
        locationId = c.optional(.locationId)
    }
}

public struct WebProduct: Decodable, Sendable, Equatable {
    public var title: String
    public var brand: String?
    public var why: String?
    public var price: String?
    public var retailer: String?
    public var url: String?
    public var imageURL: String?

    enum CodingKeys: String, CodingKey {
        case title, brand, why, price, retailer, url
        case imageURL = "image_url"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.value(.title, default: "")
        brand = c.optional(.brand)
        why = c.optional(.why)
        price = c.optional(.price)
        retailer = c.optional(.retailer)
        url = c.optional(.url)
        imageURL = c.optional(.imageURL)
    }
}

public struct WebResult: Decodable, Sendable {
    public var query: String
    public var products: [WebProduct]
    public var cached: Bool

    enum CodingKeys: String, CodingKey { case query, products, cached }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        query = c.value(.query, default: "")
        products = c.value(.products, default: [])
        cached = c.value(.cached, default: false)
    }
}

public struct Store: Codable, Sendable, Hashable, Identifiable {
    public var locationId: String
    public var name: String
    public var chain: String?
    public var address: String
    public var lat: Double?
    public var lng: Double?
    public var distanceM: Double?

    public var id: String { locationId }

    enum CodingKeys: String, CodingKey {
        case name, chain, address, lat, lng
        case locationId = "location_id", distanceM = "distance_m"
    }

    public init(locationId: String, name: String, address: String = "", distanceM: Double? = nil) {
        self.locationId = locationId
        self.name = name
        self.address = address
        self.distanceM = distanceM
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        locationId = try c.decode(String.self, forKey: .locationId)
        name = c.value(.name, default: "")
        chain = c.optional(.chain)
        address = c.value(.address, default: "")
        lat = c.optional(.lat)
        lng = c.optional(.lng)
        distanceM = c.optional(.distanceM)
    }
}

public struct Nearby: Decodable, Sendable {
    /// The store the shopper is standing in (within ~200 m), if any.
    public var atStore: Store?
    public var stores: [Store]
    public var note: String?

    enum CodingKeys: String, CodingKey {
        case stores, note
        case atStore = "at_store"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        atStore = c.optional(.atStore)
        stores = c.value(.stores, default: [])
        note = c.optional(.note)
    }
}

public struct Draft: Decodable, Sendable, Equatable {
    public var name: String?
    public var brand: String?
    public var packageSize: String?
    public var imageURL: String?

    enum CodingKeys: String, CodingKey {
        case name, brand
        case packageSize = "package_size", imageURL = "image_url"
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.optional(.name)
        brand = c.optional(.brand)
        packageSize = c.optional(.packageSize)
        imageURL = c.optional(.imageURL)
    }
}

public enum ScanStatus: String, Decodable, Sendable {
    case found, researching, pending, notFound = "not_found", error, approved, rejected, unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ScanStatus(rawValue: raw) ?? .unknown
    }
}

public struct StagedScan: Decodable, Sendable {
    public var barcode: String
    public var status: ScanStatus
    public var draft: Draft
    public var confidence: String?
    public var scanCount: Int
    public var product: Product?

    enum CodingKeys: String, CodingKey {
        case barcode, status, draft, confidence, product
        case scanCount = "scan_count"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        barcode = c.value(.barcode, default: "")
        status = c.value(.status, default: .unknown)
        draft = c.value(.draft, default: Draft())
        confidence = c.optional(.confidence)
        scanCount = c.value(.scanCount, default: 0)
        product = c.optional(.product)
    }
}

public struct ScanResult: Decodable, Sendable {
    public var status: ScanStatus
    public var product: Product?
    public var staged: StagedScan?

    enum CodingKeys: String, CodingKey { case status, product, staged }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.value(.status, default: .unknown)
        product = c.optional(.product)
        staged = c.optional(.staged)
    }
}

public struct Health: Decodable, Sendable {
    public var ok: Bool
    public var products: Int
    public var kroger: Bool
}
