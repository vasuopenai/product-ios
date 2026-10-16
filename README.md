# Food Genie (iOS)

Native iPhone and iPad app (SwiftUI, iOS 17+) for the food product backend in
[product-langflow](https://github.com/vasuopenai/product-langflow). It replaces the Expo app in
`product-mobile` and talks only to the **mobile gateway** (`mobile_api`, port 8003).

- **Ask**: a question, typed or spoken (Apple speech recognition, on device when supported).
  The answer comes back as a grid of products with the price, aisle and stock at your store;
  "From the web" is searched at the same time. Filters: At my store · All · Web. The home
  shows recent questions and recently scanned products (kept on the phone; long-press to
  remove, or Clear).
- **Scan**: camera barcode scanner (UPC-A/E, EAN-13/8) with torch and haptics, or type a
  barcode. Known products open right away. Unknown ones are researched on the server while
  the app polls, and it shows what was found. After "Scan another", the same barcode is
  ignored for a few seconds so the item still in frame doesn't reopen.
- **Store**: finds the Kroger-family store you're in (within ~200 m) or near you, and lets you
  pick any nearby store. Location is used only for this.
- **Product**: photo, price and aisle, Nutri-Score, what's inside, nutrition per serving or
  per 100 g, ingredients, allergens, labels, and a link to the source.

Design: black and white with quiet greys, SF Pro, native tab bar, navigation and controls,
light and dark mode. The colors are in `FoodGenie/Design/Theme.swift`.

## Layout

```
FoodGenie.xcodeproj      app target (the FoodGenie/ folder is synced: new files are picked up)
FoodGenie/
  App/                   entry point, tabs, navigation, gateway config
  Core/                  StoreModel (location + store), VoiceInput (speech), History (recents)
  Design/                Theme, shared components
  Features/              Ask, Scan, Store, Product screens
FoodGenieKit/            Swift package with no UI: APIClient, models, formatting, plus tests
Config/                  App.xcconfig, Info.plist, Local.xcconfig.example
```

## Run

1. Install Xcode 16 or later. Open `FoodGenie.xcodeproj` and pick an iPhone simulator.
2. Start the backend in product-langflow: `docker compose up -d db api kroger mobile`.
3. Run (⌘R). The Simulator reaches the gateway at `http://127.0.0.1:8003`.

**On your iPhone:** copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`, set
`DEVELOPMENT_TEAM` and set `FG_API_URL` to this Mac's Wi-Fi address (for example
`http:/$()/192.168.1.20:8003`; `//` starts a comment in xcconfig files, so `$()` splits it).
Then start the gateway on the network with `MOBILE_BIND=0.0.0.0 docker compose up -d mobile`.
For release builds, use the hosted HTTPS gateway and set `FG_APP_KEY` to `MOBILE_APP_KEY`.

## Checks

```
cd FoodGenieKit && swift test          # models, formatting, links, request building
xcodebuild -scheme FoodGenie -destination 'generic/platform=iOS Simulator' build
```

## App Store

The bundle id is `com.foodgenie.app`, the same app as the Expo builds (App Store Connect app
6822504916), so this ships as an update. Version 2.0. Before the first upload, set
`CURRENT_PROJECT_VERSION` higher than the last EAS build number (EAS numbered builds remotely).
Archive in Xcode (Product → Archive), then Distribute App → App Store Connect.
