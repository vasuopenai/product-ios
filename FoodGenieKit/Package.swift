// swift-tools-version:5.9
// Food Genie's app logic with no UI: gateway client, response models and display formatting.
// macOS is listed only so `swift test` runs on a Mac without a simulator.

import PackageDescription

let package = Package(
    name: "FoodGenieKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "FoodGenieKit", targets: ["FoodGenieKit"])],
    targets: [
        .target(name: "FoodGenieKit"),
        .testTarget(name: "FoodGenieKitTests", dependencies: ["FoodGenieKit"]),
    ]
)
