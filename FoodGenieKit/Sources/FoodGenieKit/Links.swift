/// Safe outbound links: sources (USDA, web search) sometimes give URLs without a scheme or with spaces.

import Foundation

public enum Links {
    private static let allowed: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        set.insert(charactersIn: ";,/?:@&=+$-_.!~*'()#%[]")
        return set
    }()

    /// A valid http(s) URL for `raw`, or nil when it can't be made into one.
    public static func webURL(_ raw: String?) -> URL? {
        var s = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.range(of: #"^[a-zA-Z][a-zA-Z0-9+.-]*:"#, options: .regularExpression) == nil {
            s = "https://" + s.replacingOccurrences(of: #"^/+"#, with: "", options: .regularExpression)
        }
        let decoded = s.removingPercentEncoding ?? s
        guard let encoded = decoded.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: encoded),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// "https://www.wholefoods.com/x" -> "wholefoods.com".
    public static func displayHost(_ url: URL) -> String? {
        url.host.map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 }
    }
}
