/// App-wide navigation: the selected tab, and links opened in the in-app browser.

import SafariServices
import SwiftUI
import FoodGenieKit

enum AppTab: Hashable {
    case ask, scan, store
}

/// Pushed onto a tab's navigation stack to show a product.
struct ProductRoute: Hashable {
    let code: String
}

struct WebPage: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .ask
    var webPage: WebPage?

    /// Opens a source link in the in-app browser; ignores links that aren't valid web URLs.
    func open(_ raw: String?) {
        guard let url = Links.webURL(raw) else { return }
        webPage = WebPage(url: url)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = .label
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
