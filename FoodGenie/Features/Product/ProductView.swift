import SwiftUI
import FoodGenieKit

struct ProductView: View {
    let code: String
    @Environment(StoreModel.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var loaded: (key: String, result: Result<Product, APIError>)?
    @State private var basis: Format.Basis = .serving

    /// Loaded data is keyed by product and store, so choosing another store reloads the price.
    private var key: String { "\(code)|\(store.store?.locationId ?? "")" }

    var body: some View {
        Group {
            switch loaded?.key == key ? loaded?.result : nil {
            case .success(let product)?: content(product)
            case .failure(let error)?:
                Page {
                    EmptyState(icon: "exclamationmark.triangle", title: "Couldn’t load this product", message: error.message) {
                        AppButton(label: "Try again", kind: .secondary) { Task { await load() } }
                    }
                }
            case nil:
                Page {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Skeleton(height: 280, radius: Radius.xl)
                        Skeleton(height: 22).frame(maxWidth: 240)
                        Skeleton(height: 16).frame(maxWidth: 160)
                        Skeleton(height: 120, radius: Radius.l)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            if let product {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: Format.shareText(product, store: store.store.map { Format.storeShortName($0.name) }),
                              subject: Text(product.name ?? "Product"))
                }
            }
        }
        .task(id: key) { await load() }
    }

    /// The product on screen, once it has loaded for the current store.
    private var product: Product? {
        if loaded?.key == key, case .success(let p)? = loaded?.result { return p }
        return nil
    }

    private func load() async {
        let key = self.key
        do {
            let product = try await AppConfig.api.product(code, locationId: store.store?.locationId)
            basis = Format.defaultBasis(product)
            loaded = (key, .success(product))
        } catch is CancellationError {
        } catch {
            loaded = (key, .failure(error as? APIError ?? APIError(error.localizedDescription)))
        }
    }

    // MARK: Content

    private func content(_ p: Product) -> some View {
        let sold = p.kroger?.sold == true
        let badge = Format.krogerBadge(p.kroger)
        return Page {
            ProductPhoto(url: p.displayImageURL, iconSize: 32, placeholder: "No photo yet")
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).strokeBorder(Theme.border)
                }

            HStack(alignment: .top, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let brand = p.brand, !brand.isEmpty {
                        Text(brand).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    Text(p.name ?? "Unnamed product").font(.title2.weight(.bold)).foregroundStyle(Theme.text)
                }
                Spacer(minLength: 0)
                if sold, let badge {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(badge.label).font(.title3.weight(.bold)).foregroundStyle(Theme.text)
                        if let aisle = p.kroger?.aisle {
                            Text(Format.titleCase(aisle))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.inverse)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Theme.text, in: Capsule())
                        }
                    }
                }
            }
            .padding(.top, Spacing.xl)

            if p.preview {
                HStack(spacing: Spacing.s) {
                    Image(systemName: "globe")
                    Text("Found online after a scan and not reviewed by us yet, so some details may be missing or off.")
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .card()
                .padding(.top, Spacing.m)
            }

            NutriScoreCircle(grade: p.nutriscore, caption: Format.nutriscoreCaption(p))
                .padding(.top, Spacing.l)

            if p.category != nil || p.origin == "scan" {
                FlowLayout {
                    if let category = p.category { Chip(label: category) }
                    if p.origin == "scan" { Chip(label: "Added from a scan", icon: "barcode.viewfinder", style: .outlined) }
                }
                .padding(.top, Spacing.m)
            }

            storeInfo(p, sold: sold, badge: badge)
            sections(p)
        }
    }

    @ViewBuilder private func storeInfo(_ p: Product, sold: Bool, badge: Format.Badge?) -> some View {
        let storeName = store.store.map { Format.storeShortName($0.name) }
        if let k = p.kroger, sold {
            Text([storeName, badge?.detail, k.size].compactMap { $0 }.joined(separator: " · "))
                .font(.footnote).foregroundStyle(Theme.textSecondary).padding(.top, Spacing.m)
        } else if let k = p.kroger {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text((storeName ?? "Your store").uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.4).foregroundStyle(Theme.textSecondary)
                StoreBadge(item: k)
            }
            .card()
            .padding(.top, Spacing.l)
        } else if store.store == nil && !store.noStores {
            Button {
                Haptics.tap()
                router.tab = .store
            } label: {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "storefront")
                    Text("Choose your store to see the price and aisle").font(.callout)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textTertiary)
                }
                .foregroundStyle(Theme.text)
                .card()
            }
            .buttonStyle(PressStyle())
            .padding(.top, Spacing.l)
        }
    }

    @ViewBuilder private func sections(_ p: Product) -> some View {
        if !Format.concerns(p).isEmpty || !Format.freeOf(p).isEmpty {
            SectionTitle("What’s inside")
            IngredientChips(product: p, goodLimit: 8)
        }

        let values = basis == .serving ? p.perServing : p.per100g
        if !values.isEmpty {
            SectionTitle(title: "Nutrition") {
                if !p.perServing.isEmpty && !p.per100g.isEmpty {
                    Picker("Basis", selection: $basis) {
                        Text("Serving").tag(Format.Basis.serving)
                        Text("100 g").tag(Format.Basis.per100g)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                } else {
                    Text(basis == .serving ? "Per serving" : "Per 100 g").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            VStack(spacing: 0) {
                let rows = Format.nutritionRows(values)
                if basis == .serving, let size = p.servingSize {
                    nutritionRow("Serving size", size, secondary: true, divider: !rows.isEmpty)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    nutritionRow(row.label, row.value, divider: i < rows.count - 1)
                }
            }
            .card(padded: false)
        }

        if !p.ingredients.isEmpty {
            SectionTitle("Ingredients\(p.ingredientCount.map { " · \($0)" } ?? "")")
            Text(Format.titleCase(p.ingredients))
                .font(.callout).foregroundStyle(Theme.textSecondary)
                .card()
        }

        if !p.allergens.isEmpty {
            SectionTitle("Allergens")
            FlowLayout {
                ForEach(p.allergens, id: \.self) { Chip(label: Format.tagLabel($0), icon: "exclamationmark", tint: Theme.bad) }
            }
        }

        if !p.labels.isEmpty {
            SectionTitle("Labels")
            FlowLayout {
                ForEach(p.labels.prefix(8), id: \.self) { Chip(label: Format.tagLabel($0), style: .outlined) }
            }
        }

        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Barcode \(p.code)\(p.groups.isEmpty ? "" : " · Checked for \(p.groups.count) ingredient groups")")
                .font(.footnote).foregroundStyle(Theme.textTertiary)
            if Links.webURL(p.url) != nil {
                AppButton(label: Format.sourceLinkLabel(p.origin), icon: "arrow.up.right", kind: .plain) {
                    router.open(p.url)
                }
            }
        }
        .padding(.top, Spacing.xl)
    }

    private func nutritionRow(_ label: String, _ value: String, secondary: Bool = false, divider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).foregroundStyle(secondary ? Theme.textSecondary : Theme.text)
                Spacer()
                Text(value).fontWeight(.semibold).foregroundStyle(Theme.text).monospacedDigit()
            }
            .font(secondary ? .footnote : .callout)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, 12)
            if divider {
                Rectangle().fill(Theme.border).frame(height: 0.5).padding(.leading, Spacing.l)
            }
        }
    }
}
