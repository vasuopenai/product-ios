/// Pure display helpers shared by the screens.

import Foundation

public enum Tone: Sendable, Equatable {
    case accent, good, sale, warning, muted, info
}

public enum Format {
    /// Ingredient groups, most important first.
    static let groupOrder = ["seed_oils", "palm_oil", "hydrogenated_oils", "added_sugars", "artificial_sweeteners",
                             "sugar_alcohols", "gums_thickeners", "artificial_colors", "artificial_flavors",
                             "natural_flavors", "synthetic_preservatives"]
    static let groupLabels = [
        "seed_oils": "Seed oils", "palm_oil": "Palm oil", "hydrogenated_oils": "Hydrogenated oils",
        "added_sugars": "Added sugar", "artificial_sweeteners": "Artificial sweeteners",
        "sugar_alcohols": "Sugar alcohols", "gums_thickeners": "Gums", "artificial_colors": "Artificial colors",
        "artificial_flavors": "Artificial flavors", "natural_flavors": "Natural flavors",
        "synthetic_preservatives": "Preservatives",
    ]

    public static func groupLabel(_ g: String) -> String {
        groupLabels[g] ?? g.replacingOccurrences(of: "_", with: " ")
    }

    /// The product page's link to where its data came from.
    public static func sourceLinkLabel(_ origin: String?) -> String {
        switch origin {
        case "usda": "View USDA record"
        case "open_food_facts": "View on Open Food Facts"
        case "kroger": "View on Kroger"
        default: "View source"
        }
    }

    public static func money(_ v: Double?) -> String? {
        v.map { String(format: "$%.2f", $0) }
    }

    public struct Badge: Equatable, Sendable {
        public let label: String
        public let detail: String?
        public let tone: Tone
    }

    /// What the store badge says, and how loud.
    public static func krogerBadge(_ k: KrogerItem?) -> Badge? {
        guard let k else { return nil }
        // in_catalog: the chain lists this barcode but this store doesn't stock it; otherwise
        // the chain has no listing for it at all (common for regional and small brands).
        guard k.sold else { return Badge(label: k.inCatalog ? "Not stocked here" : "No store listing", detail: nil, tone: .muted) }
        let out = (k.stockLevel ?? "").uppercased().contains("OUT")
        let detail = [k.aisle.map(titleCase), out ? "Out of stock" : nil].compactMap { $0 }.joined(separator: " · ")
        if k.onSale, let price = money(k.price) {
            let was = money(k.regularPrice).map { "was \($0)" }
            let full = [was, detail.isEmpty ? nil : detail].compactMap { $0 }.joined(separator: " · ")
            return Badge(label: "\(price) sale", detail: full.isEmpty ? nil : full, tone: .sale)
        }
        return Badge(label: money(k.price) ?? "In store", detail: detail.isEmpty ? nil : detail, tone: out ? .warning : .accent)
    }

    public enum Basis: String, Sendable { case serving, per100g }

    public static func defaultBasis(_ p: Product) -> Basis {
        p.perServing.isEmpty ? .per100g : .serving
    }

    /// Two or three headline numbers for a product card.
    public static func keyStats(_ p: Product) -> [String] {
        let basis = defaultBasis(p)
        let values = basis == .serving ? p.perServing : p.per100g
        var out: [String] = []
        if let v = values[.proteinG] { out.append("\(number(v)) g protein") }
        if let v = values[.energyKcal] { out.append("\(Int(v.rounded())) kcal") }
        if let v = values[.sugarsG] { out.append("\(number(v)) g sugar") }
        if !out.isEmpty && basis == .per100g { out[out.count - 1] += " /100 g" }
        return Array(out.prefix(3))
    }

    /// How bad an ingredient group is when present: `high` shows red, `moderate` amber.
    public enum Severity: Sendable, Equatable { case high, moderate }

    static let highSeverity: Set<String> = ["seed_oils", "hydrogenated_oils", "added_sugars", "artificial_sweeteners",
                                            "artificial_colors", "synthetic_preservatives"]

    public static func severity(_ group: String) -> Severity {
        highSeverity.contains(group) ? .high : .moderate
    }

    public struct Flag: Equatable, Sendable {
        public let label: String
        public let tone: Tone
        public let severity: Severity
    }

    /// Ingredient groups the product contains (or may contain), most important first. A group that
    /// only may be present is a moderate concern whatever the group.
    public static func concerns(_ p: Product) -> [Flag] {
        p.groups.filter { $0.value == "contains" || $0.value == "possible" }
            .sorted { (groupOrder.firstIndex(of: $0.key) ?? -1, $0.key) < (groupOrder.firstIndex(of: $1.key) ?? -1, $1.key) }
            .map { g, status in
                status == "possible"
                    ? Flag(label: "May contain \(groupLabel(g).lowercased())", tone: .muted, severity: .moderate)
                    : Flag(label: groupLabel(g), tone: .warning, severity: severity(g))
            }
    }

    /// The loudest thing to flag on a tile: `high` for a serious ingredient group or an allergen,
    /// `moderate` for moderate or possible groups, nil when there's nothing to say.
    public static func worstSeverity(_ p: Product) -> Severity? {
        let flags = concerns(p)
        if !p.allergens.isEmpty || flags.contains(where: { $0.severity == .high }) { return .high }
        return flags.isEmpty ? nil : .moderate
    }

    public static func freeOf(_ p: Product, limit: Int = 4) -> [String] {
        let preferred = ["seed_oils", "added_sugars", "artificial_sweeteners", "artificial_colors", "palm_oil",
                         "synthetic_preservatives", "gums_thickeners", "hydrogenated_oils"]
        return preferred.filter { p.freeOf.contains($0) }.prefix(limit).map { "No \(groupLabel($0).lowercased())" }
    }

    static let nutrientRows: [(Nutrient, String, String)] = [
        (.energyKcal, "Calories", "kcal"), (.proteinG, "Protein", "g"), (.fatG, "Total fat", "g"),
        (.carbsG, "Carbohydrates", "g"), (.sugarsG, "Sugars", "g"), (.fiberG, "Fiber", "g"), (.sodiumMg, "Sodium", "mg"),
    ]

    public struct Row: Equatable, Sendable {
        public let label: String
        public let value: String
    }

    public static func nutritionRows(_ values: Nutrients) -> [Row] {
        nutrientRows.compactMap { n, label, unit in
            values[n].map { Row(label: label, value: "\(n == .energyKcal ? String(Int($0.rounded())) : number($0)) \(unit)") }
        }
    }

    /// 12 -> "12", 2.25 -> "2.3", 3.04 -> "3".
    public static func number(_ v: Double) -> String {
        if v == v.rounded() { return String(Int(v)) }
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    /// "AISLE 12 - CHIPS" -> "Aisle 12 - Chips": capitalizes each letter that follows a non-word character.
    public static func titleCase(_ s: String) -> String {
        var out = ""
        var atWordStart = true
        for ch in s.lowercased() {
            let wordChar = ch.isLetter || ch.isNumber || ch == "_"
            out.append(atWordStart && wordChar ? Character(ch.uppercased()) : ch)
            atWordStart = !wordChar
        }
        return out
    }

    /// "en:peanuts" -> "Peanuts", "en:tree-nuts" -> "Tree Nuts".
    public static func tagLabel(_ tag: String) -> String {
        let bare = tag.range(of: #"^\w+:"#, options: .regularExpression).map { String(tag[$0.upperBound...]) } ?? tag
        return titleCase(bare.replacingOccurrences(of: "-", with: " "))
    }

    public static func distance(_ meters: Double?) -> String? {
        guard let m = meters else { return nil }
        let miles = m / 1609.34
        if miles < 0.1 { return "\(Int((m * 3.281).rounded())) ft" }
        return miles < 10 ? String(format: "%.1f mi", miles) : "\(Int(miles.rounded())) mi"
    }

    public static func greeting(_ date: Date = .now, calendar: Calendar = .current) -> String {
        let h = calendar.component(.hour, from: date)
        return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
    }

    public static func storeShortName(_ name: String?) -> String {
        (name ?? "").replacingOccurrences(of: #"^Harris Teeter - "#, with: "Harris Teeter · ", options: .regularExpression)
            .replacingOccurrences(of: #"^Kroger - "#, with: "Kroger · ", options: .regularExpression)
    }

    /// The Nutri-Score letter to show, or nil for "NA".
    public static func nutriscoreGrade(_ grade: String?) -> String? {
        guard let g = grade?.uppercased(), ["A", "B", "C", "D", "E"].contains(g) else { return nil }
        return g
    }

    /// Words under the Nutri-Score badge on the product page.
    public static func nutriscoreCaption(_ p: Product) -> String {
        guard nutriscoreGrade(p.nutriscore) != nil else { return p.nutriscoreNote ?? "Not enough nutrition data" }
        return p.nutriscoreSource == "off" ? "Open Food Facts" : "Our estimate"
    }

    /// The product page's share text: name and brand, price at the store, Nutri-Score, barcode, source link.
    public static func shareText(_ p: Product, store: String?) -> String {
        var title = p.name ?? "A product"
        if let brand = p.brand, !brand.isEmpty { title += " by \(brand)" }
        var facts: [String] = []
        if let k = p.kroger, k.sold, let badge = krogerBadge(k) {
            facts.append(store.map { "\(badge.label) at \($0)" } ?? badge.label)
            if let aisle = k.aisle { facts.append(titleCase(aisle)) }
        }
        if let grade = nutriscoreGrade(p.nutriscore) { facts.append("Nutri-Score \(grade)") }
        let lines: [String?] = [title, facts.isEmpty ? nil : facts.joined(separator: " · "), "Barcode \(p.code)",
                                Links.webURL(p.url)?.absoluteString]
        return lines.compactMap { $0 }.joined(separator: "\n")
    }
}
