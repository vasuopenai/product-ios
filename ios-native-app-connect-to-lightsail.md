# Connecting a native iOS app (Xcode) to the Food Genie server

The server is the AWS Lightsail instance `food-genie-16gb`. A native app needs the same few
things the Expo app uses: the base URL, two headers, and the endpoints below.

## 1. Base URL

```
https://32-193-51-152.sslip.io
```

It is HTTPS with a real Let's Encrypt certificate, so **App Transport Security needs no
exceptions**. Don't add `NSAllowsArbitraryLoads`.

This is a temporary name tied to the static IP 32.193.51.152. If a domain is bought later, only
`FOOD_API_URL` in the xcconfig (section 3) changes.

## 2. Headers on every `/api` request

| Header | Value | Why |
|---|---|---|
| `X-App-Key` | the server's **app key** | Required; without it every request gets a 401. |
| `X-Client-Id` | a random ID per install, generated once and saved in `UserDefaults` (e.g. `"ios-" + UUID().uuidString`) | The hourly rate limit (60 paid calls per hour) and anonymous usage counts work per install. |
| `Content-Type` | `application/json` | For POST requests. |

Get the app key in Git Bash, from the `product-langflow` folder:

```
deploy/lightsail/lightsail.sh keys
```

Use the **app key**, never the admin key, in the app.

## 3. Keep the key out of git (xcconfig)

1. Create `Secrets.xcconfig`:
   ```
   FOOD_APP_KEY = your-app-key
   FOOD_API_URL = https:/$()/32-193-51-152.sslip.io
   ```
   The `$()` is needed because `//` starts a comment in xcconfig files.
2. Add `Secrets.xcconfig` to `.gitignore`.
3. In **Project → Info → Configurations**, set it as the base configuration for Debug and Release.
4. In **Info.plist**, add `FoodAppKey` = `$(FOOD_APP_KEY)` and `FoodApiURL` = `$(FOOD_API_URL)`.

Read them in code:

```swift
let apiURL = Bundle.main.object(forInfoDictionaryKey: "FoodApiURL") as! String
let appKey = Bundle.main.object(forInfoDictionaryKey: "FoodAppKey") as! String
```

## 4. A minimal request

```swift
func ask(_ question: String, locationId: String? = nil) async throws -> Data {
    var req = URLRequest(url: URL(string: apiURL + "/api/ask")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(appKey, forHTTPHeaderField: "X-App-Key")
    req.setValue(clientId, forHTTPHeaderField: "X-Client-Id")
    req.httpBody = try JSONSerialization.data(withJSONObject: ["question": question, "location_id": locationId as Any])
    req.timeoutInterval = 120   // asks take 2–8 s, web search up to ~15 s
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    return data
}
```

Start with `GET /api/health`. It needs no key and returns `{"ok":true,...}`, which confirms the
app can reach the server.

## 5. Endpoints

| Method and path | What it does |
|---|---|
| `GET /api/health` | Server check (no key needed) |
| `POST /api/ask` `{question, location_id?}` | Product cards for a question |
| `POST /api/web` `{query}` | Products from the web (slow; run it in parallel with ask) |
| `POST /api/scan` `{barcode, lat?, lng?, location_id?}` | Scan a barcode; then poll `GET /api/scan/{barcode}` while the status is `researching` |
| `GET /api/scan/{barcode}?location_id=` | Status of a scanned barcode being researched |
| `GET /api/products/{barcode}?location_id=` | Product details |
| `GET /api/nearby?lat=&lng=` | Kroger-family stores near a location |

For the JSON response shapes, copy the types from `product-mobile/src/lib/types.ts` (`Product`,
`AskResult`, `ScanResult`, `Nearby`). Those are exactly what the server returns, including
`nutriscore`, `nutriscore_source`, `nutriscore_note` and `preview`.

Every response also carries a `Server-Timing` header with the time each step took.

## 6. Info.plist permission messages

Only for the features the app uses:

| Key | For |
|---|---|
| `NSCameraUsageDescription` | Barcode scanning |
| `NSLocationWhenInUseUsageDescription` | Finding nearby stores |
| `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` | Voice questions |

The wording can be reused from the Expo app's `app.json`. If App Store Connect rejects an
upload with ITMS-90683 (missing purpose string), add the key it names, as the Expo app did for
`NSPhotoLibraryUsageDescription`.
