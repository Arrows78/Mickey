// swift-tools-version: 6.2
import PackageDescription

let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "MickeyKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MickeyKit", targets: ["MickeyDomain", "MickeyPersistence", "MickeySystem"]),
    ],
    targets: [
        .target(name: "MickeyDomain"),
        .target(name: "MickeyPersistence", dependencies: ["MickeyDomain"]),
        .target(name: "MickeySystem", dependencies: ["MickeyDomain"], swiftSettings: mainActorByDefault),
        .testTarget(name: "MickeyDomainTests", dependencies: ["MickeyDomain"]),
        .testTarget(name: "MickeyPersistenceTests", dependencies: ["MickeyPersistence"]),
    ]
)
