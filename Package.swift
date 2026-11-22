// swift-tools-version:5.9
import Foundation
import PackageDescription

// Embedding Info.plist in the executable lets a bare `swift run PeatsMac` use Bluetooth too;
// without the usage string macOS kills the process on first access.
let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("Resources/Info.plist").path

let package = Package(
    name: "PeatsMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PeatsMac", targets: ["PeatsMac"]),
    ],
    targets: [
        // SoundPEATS protocol: framing, command codecs, T3 Pro EQ. No UI, no Bluetooth, builds anywhere.
        .target(name: "PeatsKit"),
        // The menu bar app: IOBluetooth RFCOMM transport, device state and the SwiftUI panel.
        .executableTarget(
            name: "PeatsMac",
            dependencies: ["PeatsKit"],
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", infoPlist]),
            ]
        ),
        // `swift run PeatsKitChecks`: protocol self-checks (XCTest isn't available without Xcode).
        .executableTarget(name: "PeatsKitChecks", dependencies: ["PeatsKit"]),
    ]
)
