/// Where the mobile gateway is, and this install's anonymous id.
///
/// FGApiURL and FGAppKey come from Info.plist, which takes them from the build settings
/// FG_API_URL and FG_APP_KEY (Config/App.xcconfig, overridden by the untracked
/// Config/Local.xcconfig). The default, http://127.0.0.1:8003, reaches a gateway on this
/// Mac from the Simulator.

import Foundation
import FoodGenieKit

enum AppConfig {
    static let apiURL: URL = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "FGApiURL") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let trimmed = raw.hasSuffix("/") ? String(raw.dropLast()) : raw
        return URL(string: trimmed).flatMap { $0.host == nil ? nil : $0 } ?? URL(string: "http://127.0.0.1:8003")!
    }()

    static let appKey: String? = {
        let key = (Bundle.main.object(forInfoDictionaryKey: "FGAppKey") as? String) ?? ""
        return key.isEmpty ? nil : key
    }()

    /// An anonymous id for this install: rate limits and scan history on the server.
    static let clientId: String = {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "client-id") { return id }
        let id = "ios-\(UUID().uuidString.lowercased())"
        defaults.set(id, forKey: "client-id")
        return id
    }()

    static let api = APIClient(baseURL: apiURL, appKey: appKey, clientId: clientId)
}
