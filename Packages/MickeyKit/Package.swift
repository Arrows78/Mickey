// swift-tools-version: 6.2
import PackageDescription

let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "MickeyKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MickeyKit", targets: ["MickeyDomain"]),
    ],
    targets: [
        .target(name: "MickeyDomain"),
        .testTarget(name: "MickeyDomainTests", dependencies: ["MickeyDomain"]),
    ]
)
