import SwiftUI

@main
struct FoodGenieApp: App {
    @State private var router = AppRouter()
    @State private var store = StoreModel(api: AppConfig.api)
    @State private var history = History()

    init() {
        // Product photos repeat across Ask, Scan and Product pages.
        URLCache.shared = URLCache(memoryCapacity: 32 << 20, diskCapacity: 200 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(store)
                .environment(history)
                .tint(Theme.text)
                .task { await store.start() }
        }
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            NavigationStack { AskView().productDestination() }
                .tabItem { Label("Ask", systemImage: "sparkles") }
                .tag(AppTab.ask)
            NavigationStack { ScanView().productDestination() }
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }
                .tag(AppTab.scan)
            NavigationStack { StoreView() }
                .tabItem { Label("Store", systemImage: "storefront") }
                .tag(AppTab.store)
        }
        .sheet(item: $router.webPage) { page in
            SafariView(url: page.url).ignoresSafeArea()
        }
    }
}

extension View {
    func productDestination() -> some View {
        navigationDestination(for: ProductRoute.self) { route in
            ProductView(code: route.code)
        }
    }
}
