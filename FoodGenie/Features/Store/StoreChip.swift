/// The store pill at the top of Ask and Scan: tap to manage the store.

import SwiftUI
import FoodGenieKit

struct StoreChip: View {
    var onCamera = false
    @Environment(StoreModel.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let selected = store.store != nil
        Button {
            Haptics.tap()
            router.tab = .store
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.inStore ? "location.fill" : "storefront")
                    .font(.caption.weight(.semibold))
                Text(label).font(.footnote.weight(.semibold)).lineLimit(1)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).opacity(0.6)
            }
            .foregroundStyle(onCamera ? .white : selected ? Theme.inverse : Theme.text)
            .padding(.vertical, 7)
            .padding(.horizontal, Spacing.m)
            .background {
                if onCamera {
                    Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                } else {
                    Capsule().fill(selected ? Theme.text : Theme.surface)
                }
            }
        }
        .buttonStyle(PressStyle())
        .frame(maxWidth: 280, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var label: String {
        if store.loading { return "Finding your store…" }
        if let s = store.store { return "\(store.inStore ? "At " : "")\(Format.storeShortName(s.name))" }
        return store.noStores ? "No store nearby" : "Choose a store"
    }
}
