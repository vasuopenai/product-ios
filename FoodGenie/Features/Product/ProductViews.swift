/// Product rows, grid tiles and badges used on the Ask, Scan and Product screens.

import SwiftUI
import FoodGenieKit

struct ProductImage: View {
    let url: String?
    var size: CGFloat = 72
    var radius: CGFloat = Radius.m

    var body: some View {
        ProductPhoto(url: url, iconSize: size * 0.32)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// A product photo fitted on a white well (product shots are mostly on white), or a placeholder.
struct ProductPhoto: View {
    let url: String?
    var iconSize: CGFloat = 24
    var placeholder: String?
    /// Room between the photo and its edges.
    var inset: CGFloat = 6

    var body: some View {
        ZStack {
            Rectangle().fill(url == nil ? Theme.surfaceStrong : Color.white)
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit().padding(inset)
                    case .failure: missing
                    default: Rectangle().fill(Theme.surfaceStrong)
                    }
                }
            } else {
                missing
            }
        }
    }

    private var missing: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "photo").font(.system(size: iconSize, weight: .light))
            if let placeholder { Text(placeholder).font(.caption) }
        }
        .foregroundStyle(Theme.textTertiary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surfaceStrong)
    }
}

/// The Nutri-Score letter, or "NA" when neither Open Food Facts nor our calculation has one.
/// Colored with the official Nutri-Score palette, dark green for A through red for E.
struct NutriScoreBadge: View {
    let grade: String?
    var showLabel = false

    var body: some View {
        let letter = Format.nutriscoreGrade(grade)
        HStack(spacing: 5) {
            if showLabel {
                Text("NUTRI-SCORE").font(.system(size: 9, weight: .bold)).tracking(0.5).opacity(0.75)
            }
            Text(letter ?? "NA").font(.caption.weight(.heavy))
        }
        .foregroundStyle(letter == nil ? Theme.textSecondary : Theme.nutriscoreText(letter))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(minWidth: 24)
        .background(Theme.nutriscore(letter) ?? Theme.surfaceStrong, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(letter.map { "Nutri-Score \($0)" } ?? "Nutri-Score not available")
    }
}

/// The product page's Nutri-Score: a circle filled with the grade's color, the letter in the
/// center, and beside it the label and where the grade came from.
struct NutriScoreCircle: View {
    let grade: String?
    let caption: String

    var body: some View {
        let letter = Format.nutriscoreGrade(grade)
        HStack(spacing: Spacing.m) {
            Text(letter ?? "NA")
                .font(letter == nil ? .footnote.weight(.heavy) : .title2.weight(.heavy))
                .foregroundStyle(letter == nil ? Theme.textSecondary : Theme.nutriscoreText(letter))
                .frame(width: 52, height: 52)
                .background(Theme.nutriscore(letter) ?? Theme.surfaceStrong, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("NUTRI-SCORE")
                    .font(.caption2.weight(.bold)).tracking(0.5)
                    .foregroundStyle(Theme.textSecondary)
                Text(caption).font(.footnote).foregroundStyle(Theme.text)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(letter.map { "Nutri-Score \($0), \(caption)" } ?? "Nutri-Score not available, \(caption)")
    }
}

/// Price, sale and stock at the chosen store.
struct StoreBadge: View {
    let item: KrogerItem?
    var compact = false

    var body: some View {
        if let badge = Format.krogerBadge(item) {
            HStack(spacing: 5) {
                Image(systemName: "cart").font(.caption2.weight(.semibold))
                Text(badge.label)
                    .font((compact ? Font.footnote : .callout).weight(badge.tone == .muted ? .regular : .semibold))
                if let detail = badge.detail, !compact {
                    Text("· \(detail)").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .foregroundStyle(badge.tone == .muted ? Theme.textSecondary : Theme.text)
        }
    }
}

/// The "what's inside" chips: flagged ingredient groups (red for the worst, amber for moderate
/// ones and "may contain"), then the good news with green checkmarks.
struct IngredientChips: View {
    let product: Product
    var flagLimit = Int.max
    var goodLimit = 4

    var body: some View {
        let flags = Array(Format.concerns(product).prefix(flagLimit))
        let good = flags.isEmpty || goodLimit > 2 ? Format.freeOf(product, limit: goodLimit) : []
        if !flags.isEmpty || !good.isEmpty {
            FlowLayout {
                ForEach(flags, id: \.label) { f in
                    Chip(label: f.label, icon: f.tone == .warning ? "exclamationmark" : "questionmark",
                         style: f.tone == .warning ? .filled : .outlined,
                         tint: f.severity == .high ? Theme.bad : Theme.caution)
                }
                ForEach(good, id: \.self) { g in
                    Chip(label: g, icon: "checkmark", style: .outlined, tint: Theme.good)
                }
            }
        }
    }
}

/// A product as a full-width row (scan results).
struct ProductCard: View {
    let product: Product

    var body: some View {
        NavigationLink(value: ProductRoute(code: product.code)) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(spacing: Spacing.m) {
                    ProductImage(url: product.displayImageURL)
                    VStack(alignment: .leading, spacing: 3) {
                        if let brand = product.brand, !brand.isEmpty {
                            Text(brand.uppercased())
                                .font(.caption2.weight(.semibold)).tracking(0.4)
                                .foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                        Text(product.name ?? "Unnamed product")
                            .font(.headline).foregroundStyle(Theme.text).lineLimit(2)
                            .multilineTextAlignment(.leading)
                        let stats = Format.keyStats(product)
                        if !stats.isEmpty {
                            Text(stats.joined(separator: "  ·  "))
                                .font(.footnote).foregroundStyle(Theme.textSecondary)
                        }
                        HStack(spacing: Spacing.s) {
                            NutriScoreBadge(grade: product.nutriscore)
                            StoreBadge(item: product.kroger, compact: true)
                        }
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                IngredientChips(product: product, flagLimit: 2, goodLimit: 2)
            }
            .card()
        }
        .buttonStyle(PressStyle())
        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
    }
}

/// The small grey "i" on a tile's photo, shown only when the product has flagged ingredient
/// groups or allergens. Tapping shows the chips; the color is left to them.
struct ConcernsInfoButton: View {
    let product: Product
    @State private var showing = false

    var body: some View {
        if let severity = Format.worstSeverity(product) {
            Button {
                Haptics.tap()
                showing = true
            } label: {
                // The classic info glyph: a serif italic "i", quiet but unmistakable.
                Text("i")
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(severity == .high ? "Serious concerns, show details" : "Some concerns, show details")
            .popover(isPresented: $showing, arrowEdge: .top) {
                ConcernsPopover(product: product)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}

/// What the "i" opens: the flagged ingredient groups and allergens, as on the product page.
struct ConcernsPopover: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Heads up").font(.headline).foregroundStyle(Theme.text)
            if !Format.concerns(product).isEmpty {
                IngredientChips(product: product, goodLimit: 0)
            }
            if !product.allergens.isEmpty {
                Text("ALLERGENS")
                    .font(.caption2.weight(.bold)).tracking(0.5)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Spacing.xs)
                FlowLayout {
                    ForEach(product.allergens, id: \.self) {
                        Chip(label: Format.tagLabel($0), icon: "exclamationmark", tint: Theme.bad)
                    }
                }
            }
        }
        .padding(Spacing.l)
        .frame(width: 280, alignment: .leading)
        .presentationBackground(Theme.background)
    }
}

/// A product in the Ask grid: a square photo flush with the top of the card, then brand and
/// Nutri-Score, a two-line name (space reserved so price rows line up), price and aisle.
struct ProductTile: View {
    let product: Product

    var body: some View {
        NavigationLink(value: ProductRoute(code: product.code)) {
            VStack(alignment: .leading, spacing: 0) {
                ProductPhoto(url: product.displayImageURL, iconSize: 24, inset: 14)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(alignment: .topTrailing) { ConcernsInfoButton(product: product) }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 6) {
                        if let brand = product.brand, !brand.isEmpty {
                            Text(brand.uppercased())
                                .font(.caption2.weight(.semibold)).tracking(0.6)
                                .foregroundStyle(Theme.textTertiary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        NutriScoreBadge(grade: product.nutriscore)
                    }
                    Text(product.name ?? "Unnamed product")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                    price.padding(.top, 4)
                }
                .padding(Spacing.m)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .tileCard()
        }
        .buttonStyle(PressStyle())
        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
    }

    @ViewBuilder private var price: some View {
        let k = product.kroger
        if let badge = Format.krogerBadge(k) {
            if k?.sold == true {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(badge.label).font(.headline).foregroundStyle(Theme.text).lineLimit(1)
                        Spacer(minLength: 0)
                        if let aisle = k?.aisle {
                            Text(Format.titleCase(aisle))
                                .font(.caption2.weight(.medium)).lineLimit(1)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .overlay { Capsule().strokeBorder(Theme.border) }
                        }
                    }
                    if badge.tone == .warning {
                        Text("OUT OF STOCK").font(.caption2.weight(.bold)).tracking(0.4)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            } else {
                Text(badge.label).font(.footnote).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
        }
    }
}

/// A recently scanned product, in the horizontal strip on the Ask home.
struct RecentScanTile: View {
    let scan: RecentScan

    var body: some View {
        NavigationLink(value: ProductRoute(code: scan.code)) {
            VStack(alignment: .leading, spacing: 0) {
                ProductPhoto(url: scan.imageURL, iconSize: 20, inset: 10)
                    .frame(width: 132, height: 132)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        if let brand = scan.brand, !brand.isEmpty {
                            Text(brand.uppercased())
                                .font(.caption2.weight(.semibold)).tracking(0.6)
                                .foregroundStyle(Theme.textTertiary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        NutriScoreBadge(grade: scan.nutriscore)
                    }
                    Text(scan.name ?? "Unnamed product")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                }
                .padding(Spacing.s)
            }
            .frame(width: 132, alignment: .topLeading)
            .tileCard()
        }
        .buttonStyle(PressStyle())
        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
    }
}

/// A product found on the web, opened in the in-app browser.
struct WebCard: View {
    let item: WebProduct
    @Environment(AppRouter.self) private var router

    var body: some View {
        let url = Links.webURL(item.url)
        Button {
            Haptics.tap()
            router.open(item.url)
        } label: {
            HStack(spacing: Spacing.m) {
                ProductImage(url: item.imageURL, size: 52, radius: Radius.s)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    if let why = item.why, !why.isEmpty {
                        Text(why).font(.footnote).foregroundStyle(Theme.textSecondary).lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: Spacing.s) {
                        if let price = item.price, !price.isEmpty {
                            Text(price).font(.footnote.weight(.semibold)).foregroundStyle(Theme.text)
                        }
                        if let where_ = item.retailer ?? url.flatMap(Links.displayHost) {
                            Text(where_).font(.footnote).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                if url != nil {
                    Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.vertical, Spacing.m)
            .padding(.horizontal, Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .disabled(url == nil)
    }
}
