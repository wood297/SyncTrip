// swift-tools-version: 6.0
import PackageDescription

// Tests the actual iOS model, client, and store on a Mac without a simulator.
let package = Package(
    name: "SyncTripCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "SyncTripCore", targets: ["SyncTripCore"])],
    targets: [
        .target(name: "SyncTripCore", path: "ios",
                exclude: ["App", "Views", "Resources", "SyncTrip.xcodeproj"],
                sources: ["Models/Activity.swift", "Services/ActivityAPI.swift", "ViewModels/TripStore.swift"]),
        .testTarget(name: "SyncTripCoreTests", dependencies: ["SyncTripCore"], path: "tests/swift")
    ],
    swiftLanguageModes: [.v5]
)
