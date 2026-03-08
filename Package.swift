// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-json-codable",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "JSONCodable",
      targets: ["JSONCodable"])
  ],
  dependencies: [
      .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.6"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "JSONCodable"),
    .testTarget(
      name: "JSONCodableTests",
      dependencies: ["JSONCodable"]),
    .target(
      name: "JSONLD",
      dependencies: ["JSONCodable"]),
    .testTarget(
      name: "JSONLDTests",
      dependencies: ["JSONLD"],
      resources: [
        .copy("Resources/Fixtures/")
      ]),
  ]
)
