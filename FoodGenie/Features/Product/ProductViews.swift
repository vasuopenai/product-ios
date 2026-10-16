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

    var body: some View {
        ZStack {
            Rectangle().fill(url == nil ? Theme.surfaceStrong : Color.white)
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit().padding(6)
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
/// Monochrome: the letter carries the grade, a filled badge means there is one.
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
        .foregroundStyle(letter == nil ? Theme.textSecondary : Theme.inverse)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(minWidth: 24)
        .background(letter == nil ? Theme.surfaceStrong : Theme.text, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(letter.map { "Nutri-Score \($0)" } ?? "Nutri-Score not available")
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

/// The "what's inside" chips: flagged ingredient groups, then the good news.
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
                         style: f.tone == .warning ? .filled : .outlined)
                }
                ForEach(good, id: \.self) { g in
                    Chip(label: g, icon: "checkmark", style: .outlined)
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

/// A product in the Ask grid: photo, name, price and aisle.
struct ProductTile: View {
    let product: Product

    var body: some View {
        NavigationLink(value: ProductRoute(code: product.code)) {
            VStack(alignment: .leading, spacing: 6) {
                ProductPhoto(url: product.displayImageURL, iconSize: 24)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        NutriScoreBadge(grade: product.nutriscore).padding(6)
                    }
                    .padding(.bottom, 2)
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand.uppercased())
                        .font(.caption2.weight(.semibold)).tracking(0.4)
                        .foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                Text(product.name ?? "Unnamed product")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                price
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
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
                                .background(Theme.background, in: Capsule())
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
