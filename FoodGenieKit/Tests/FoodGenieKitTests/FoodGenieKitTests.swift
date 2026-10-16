import Foundation
import Testing

@testable import FoodGenieKit

// A product card the way mobile_api returns it (off_products.ask._facts + products.card).
let productJSON = """
{
  "name": "Protein Bar", "brand": "Acme", "code": "0049000028911", "url": "fdc.nal.usda.gov/food/123",
  "serving_size": "1 bar (60 g)",
  "per_serving": {"energy_kcal": 230, "protein_g": 20, "sugars_g": 1.04, "sodium_mg": null},
  "per_100g": {"energy_kcal": 383.3, "protein_g": 33.3},
  "ingredients": "almonds, whey protein, palm oil", "ingredient_count": 3,
  "ingredient_amounts": [{"id": "en:almond", "percent": 30, "declared": true}],
  "groups": {"palm_oil": "contains", "natural_flavors": "possible", "added_sugars": "unknown"},
  "free_of": ["seed_oils", "artificial_colors", "added_sugars"],
  "labels": ["en:gluten-free"], "retailers": [],
  "nutriscore": "B", "nutriscore_source": "computed",
  "image_url": null, "category": "Protein bars", "categories": [], "allergens": ["en:tree-nuts"],
  "origin": "usda",
  "kroger": {"sold": true, "in_catalog": true, "price": 2.5, "regular_price": 3.29, "on_sale": true,
             "aisle": "AISLE 12", "image_url": "https://img/k.jpg", "stock_level": "LOW", "extra": 1}
}
"""

func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

@Suite struct Decoding {
    @Test func product() throws {
        let p = try decode(Product.self, productJSON)
        #expect(p.code == "0049000028911")
        #expect(p.perServing[.proteinG] == 20)
        #expect(p.perServing[.sodiumMg] == nil)
        #expect(p.per100g[.energyKcal] == 383.3)
        #expect(p.groups["palm_oil"] == "contains")
        #expect(p.kroger?.onSale == true)
        #expect(p.kroger?.aisle == "AISLE 12")
        #expect(p.preview == false)
        #expect(p.displayImageURL == "https://img/k.jpg")
    }

    @Test func minimalProduct() throws {
        let p = try decode(Product.self, #"{"code": "123", "groups": "not a dict", "kroger": null}"#)
        #expect(p.name == nil)
        #expect(p.groups.isEmpty)
        #expect(p.kroger == nil)
        #expect(p.perServing.isEmpty)
    }

    @Test func ask() throws {
        let r = try decode(AskResult.self, """
            {"question": "q", "answer": "a", "notes": [], "filters": {"x": [1, {"y": null}]},
             "products": [\(productJSON)], "location_id": null}
            """)
        #expect(r.products.count == 1)
        #expect(r.locationId == nil)
    }

    @Test func scanPending() throws {
        let r = try decode(ScanResult.self, """
            {"status": "pending", "staged": {"barcode": "1", "status": "pending", "confidence": null, "scan_count": 2,
             "sources": {"usda": null}, "draft": {"name": "Chips", "package_size": "5 oz",
             "nutrients_100g": {"energy_kcal": 500}}, "product": null}}
            """)
        #expect(r.status == .pending)
        #expect(r.staged?.draft.name == "Chips")
        #expect(r.staged?.draft.packageSize == "5 oz")
        #expect(r.staged?.product == nil)
        #expect(try decode(ScanResult.self, #"{"status": "something_new"}"#).status == .unknown)
        #expect(try decode(ScanResult.self, #"{"status": "not_found"}"#).status == .notFound)
    }

    @Test func nearbyAndStoreRoundTrip() throws {
        let n = try decode(Nearby.self, """
            {"at_store": null, "stores": [{"location_id": "029", "name": "Kroger - Main St", "chain": "KROGER",
             "address": "1 Main St", "lat": 1.5, "lng": 2.5, "distance_m": 300.2}]}
            """)
        #expect(n.atStore == nil)
        let s = try #require(n.stores.first)
        let again = try JSONDecoder().decode(Store.self, from: JSONEncoder().encode(s))
        #expect(again == s)
    }
}

@Suite struct Formatting {
    @Test func badges() {
        let sale = Format.krogerBadge(KrogerItem(sold: true, price: 2.5, regularPrice: 3.29, onSale: true, aisle: "AISLE 12"))
        #expect(sale == .init(label: "$2.50 sale", detail: "was $3.29 · Aisle 12", tone: .sale))
        let out = Format.krogerBadge(KrogerItem(sold: true, price: 4, stockLevel: "TEMPORARILY_OUT_OF_STOCK"))
        #expect(out == .init(label: "$4.00", detail: "Out of stock", tone: .warning))
        #expect(Format.krogerBadge(KrogerItem(sold: false, inCatalog: true))?.label == "Not stocked here")
        #expect(Format.krogerBadge(KrogerItem(sold: false, inCatalog: false))?.label == "No store listing")
        #expect(Format.krogerBadge(KrogerItem(sold: true))?.label == "In store")
        #expect(Format.krogerBadge(nil) == nil)
    }

    @Test func stats() throws {
        let p = try decode(Product.self, productJSON)
        #expect(Format.keyStats(p) == ["20 g protein", "230 kcal", "1 g sugar"])
        let per100 = Product(code: "1", per100g: Nutrients(["protein_g": 8.25, "energy_kcal": 120]))
        #expect(Format.keyStats(per100) == ["8.2 g protein", "120 kcal /100 g"])
    }

    @Test func flags() throws {
        let p = try decode(Product.self, productJSON)
        #expect(Format.concerns(p) == [.init(label: "Palm oil", tone: .warning),
                                       .init(label: "May contain natural flavors", tone: .muted)])
        #expect(Format.freeOf(p) == ["No seed oils", "No added sugar", "No artificial colors"])
        #expect(Format.freeOf(p, limit: 1) == ["No seed oils"])
    }

    @Test func rows() {
        let rows = Format.nutritionRows(Nutrients(["sodium_mg": 140, "energy_kcal": 229.6, "fat_g": 9.5]))
        #expect(rows == [.init(label: "Calories", value: "230 kcal"), .init(label: "Total fat", value: "9.5 g"),
                         .init(label: "Sodium", value: "140 mg")])
    }

    @Test func text() {
        #expect(Format.titleCase("AISLE 12 - CHIPS & dips") == "Aisle 12 - Chips & Dips")
        #expect(Format.tagLabel("en:tree-nuts") == "Tree Nuts")
        #expect(Format.tagLabel("organic") == "Organic")
        #expect(Format.number(3.04) == "3")
        #expect(Format.number(12) == "12")
        #expect(Format.storeShortName("Kroger - Main St") == "Kroger · Main St")
        #expect(Format.distance(20) == "66 ft")
        #expect(Format.distance(1609.34 * 2.345) == "2.3 mi")
        #expect(Format.distance(1609.34 * 12.6) == "13 mi")
        #expect(Format.distance(nil) == nil)
        #expect(Format.nutriscoreGrade("b") == "B")
        #expect(Format.nutriscoreGrade(nil) == nil)
        #expect(Format.sourceLinkLabel("open_food_facts") == "View on Open Food Facts")
    }

    @Test func share() throws {
        let p = try decode(Product.self, productJSON)
        #expect(Format.shareText(p, store: "Kroger · Main St") == """
            Protein Bar by Acme
            $2.50 sale at Kroger · Main St · Aisle 12 · Nutri-Score B
            Barcode 0049000028911
            https://fdc.nal.usda.gov/food/123
            """)
        #expect(Format.shareText(Product(code: "1"), store: nil) == "A product\nBarcode 1")
    }

    @Test func greeting() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try #require(TimeZone(identifier: "UTC"))
        let at = { (h: Int) in cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: h))! }
        #expect(Format.greeting(at(9), calendar: cal) == "Good morning")
        #expect(Format.greeting(at(13), calendar: cal) == "Good afternoon")
        #expect(Format.greeting(at(20), calendar: cal) == "Good evening")
    }
}

@Suite struct History {
    @Test func recents() throws {
        #expect(Recents.adding("b", to: ["a", "b", "c"], by: { $0 }) == ["b", "a", "c"])
        #expect(Recents.adding("z", to: ["a", "b"], by: { $0 }, limit: 2) == ["z", "a"])
        #expect(Recents.adding("A", to: ["a"], by: { $0.lowercased() }) == ["A"])

        let scan = RecentScan(try decode(Product.self, productJSON))
        #expect(scan.imageURL == "https://img/k.jpg")
        #expect(scan.nutriscore == "B")
        let again = try JSONDecoder().decode(RecentScan.self, from: JSONEncoder().encode(scan))
        #expect(again == scan)
    }
}

@Suite struct LinksAndRequests {
    @Test func webURLs() {
        #expect(Links.webURL("fdc.nal.usda.gov/food/123")?.absoluteString == "https://fdc.nal.usda.gov/food/123")
        #expect(Links.webURL("https://example.com/a b")?.absoluteString == "https://example.com/a%20b")
        #expect(Links.webURL("https://example.com/a%20b")?.absoluteString == "https://example.com/a%20b")
        #expect(Links.webURL("javascript:alert(1)") == nil)
        #expect(Links.webURL("  ") == nil)
        #expect(Links.webURL(nil) == nil)
        #expect(Links.displayHost(URL(string: "https://www.wholefoods.com/x")!) == "wholefoods.com")
    }

    @Test func urls() {
        let api = APIClient(baseURL: URL(string: "https://api.example.com")!, appKey: nil, clientId: "c")
        #expect(api.url("api/products/012", ["location_id": nil]).absoluteString == "https://api.example.com/api/products/012")
        #expect(api.url("api/nearby", ["lng": "2", "lat": "1"]).absoluteString == "https://api.example.com/api/nearby?lat=1&lng=2")
        #expect(api.url("api/scan/1", ["location_id": ""]).absoluteString == "https://api.example.com/api/scan/1")
    }

    @Test func errors() {
        #expect(APIClient.error(status: 429, body: Data()).status == 429)
        #expect(APIClient.error(status: 400, body: Data(#"{"detail": "Bad barcode"}"#.utf8)).message == "Bad barcode")
        #expect(APIClient.error(status: 502, body: Data("<html>".utf8)).message == "Something went wrong (502).")
    }
}
