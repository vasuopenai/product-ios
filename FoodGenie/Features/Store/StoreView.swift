import SwiftUI
import FoodGenieKit

struct StoreView: View {
    @Environment(StoreModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        Page {
            PageHeader(eyebrow: "Prices, aisles and stock", title: "Your store")
                .padding(.bottom, Spacing.xl)

            if let s = model.store {
                current(s)
            }

            switch model.permission {
            case .denied:
                EmptyState(icon: "location.slash", title: "Location is off",
                           message: "Turn on location for Food Genie in Settings to find the store you’re in.") {
                    AppButton(label: "Open Settings", kind: .secondary) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            case .unknown:
                EmptyState(icon: "location", title: "Find your store",
                           message: "Food Genie uses your location only to find nearby Kroger-family stores for prices and aisles.") {
                    AppButton(label: "Use my location", icon: "location.fill", loading: model.loading) {
                        Task { await model.locate() }
                    }
                }
            case .granted:
                nearbyList
            }

            if let error = model.error {
                Text(error).font(.footnote).foregroundStyle(Theme.textSecondary).padding(.top, Spacing.m)
            }
        }
        .refreshable {
            if model.permission == .granted { await model.locate() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func current(_ s: Store) -> some View {
        let here = model.inStore
        return HStack(spacing: Spacing.m) {
            Image(systemName: here ? "location.fill" : "storefront")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(here ? Theme.inverse.opacity(0.15) : Theme.surfaceStrong, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(here ? "You’re at" : "Prices from").font(.footnote).opacity(0.75)
                Text(Format.storeShortName(s.name)).font(.headline)
                if !s.address.isEmpty { Text(s.address).font(.footnote).opacity(0.75) }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(here ? Theme.inverse : Theme.text)
        .padding(Spacing.l)
        .background(here ? Theme.text : Theme.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    @ViewBuilder private var nearbyList: some View {
        SectionTitle(title: "Stores near you") {
            Button {
                Haptics.tap()
                Task { await model.locate() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise").font(.footnote.weight(.semibold))
            }
            .disabled(model.loading)
        }

        if model.loading && model.nearby == nil {
            VStack(spacing: Spacing.s) {
                ForEach(0..<3, id: \.self) { _ in Skeleton(height: 64, radius: Radius.l) }
            }
        } else if let stores = model.nearby?.stores, !stores.isEmpty {
            VStack(spacing: Spacing.s) {
                ForEach(stores) { s in row(s) }
            }
        } else {
            Text("\(model.nearby?.note ?? "No Kroger-family stores within 10 miles.") You can still ask about and scan any product: you’ll see ingredients and nutrition, just without store prices and aisles.")
                .font(.callout).foregroundStyle(Theme.textSecondary)
        }

        Text("Prices come from Kroger-family stores: Kroger, Harris Teeter, Ralphs, Fred Meyer, King Soopers and more.")
            .font(.footnote).foregroundStyle(Theme.textTertiary).padding(.top, Spacing.l)
    }

    private func row(_ s: Store) -> some View {
        let selected = model.store?.locationId == s.locationId
        return Button {
            Haptics.tap()
            model.choose(s)
        } label: {
            HStack(spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Format.storeShortName(s.name)).font(.headline).foregroundStyle(Theme.text).lineLimit(1)
                    Text(s.address).font(.footnote).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                Spacer(minLength: Spacing.s)
                VStack(alignment: .trailing, spacing: 4) {
                    if let d = Format.distance(s.distanceM) {
                        Text(d).font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    if selected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.text)
                    }
                }
            }
            .card()
            .overlay {
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .strokeBorder(selected ? Theme.text : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
