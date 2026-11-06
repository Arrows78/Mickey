// swift-tools-version: 6.2
import PackageDescription

let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "MickeyKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MickeyKit", targets: ["MickeyDomain", "MickeyPersistence", "MickeySystem",
                                               "MickeyEffects", "MickeyAnnotations", "MickeyStudio", "MickeyUI"]),
    ],
    targets: [
        .target(name: "MickeyDomain"),
        .target(name: "MickeyPersistence", dependencies: ["MickeyDomain"]),
        .target(name: "MickeySystem", dependencies: ["MickeyDomain"], swiftSettings: mainActorByDefault),
        .target(name: "MickeyEffects", dependencies: ["MickeyDomain"], swiftSettings: mainActorByDefault),
        .target(name: "MickeyStudio", dependencies: ["MickeyDomain", "MickeySystem", "MickeyEffects"], swiftSettings: mainActorByDefault),
        .target(name: "MickeyAnnotations", dependencies: ["MickeyDomain", "MickeyEffects"], swiftSettings: mainActorByDefault),
        .target(name: "MickeyUI", dependencies: ["MickeyDomain", "MickeyPersistence", "MickeyEffects"], swiftSettings: mainActorByDefault),
        .testTarget(name: "MickeyDomainTests", dependencies: ["MickeyDomain"]),
        .testTarget(name: "MickeyAnnotationsTests", dependencies: ["MickeyAnnotations", "MickeyDomain"]),
        .testTarget(name: "MickeyPersistenceTests", dependencies: ["MickeyPersistence"]),
        .testTarget(name: "MickeyEffectsTests", dependencies: ["MickeyEffects", "MickeyDomain"]),
        .testTarget(name: "MickeyUITests", dependencies: ["MickeyUI", "MickeyDomain", "MickeyPersistence"]),
    ]
)
