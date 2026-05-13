// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

import class Foundation.ProcessInfo

var swiftSettings: [SwiftSetting] {
  [
    .unsafeFlags([
      "-Xfrontend", "-define-availability",
      "-Xfrontend", "SwiftStdlib 5.9:macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0",
    ]),

    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),

    .strictMemorySafety(),
  ]
}

var package = Package(
  name: "swift-json-ld",
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
      targets: ["JSONCodable"]
    ),
    .library(
      name: "JSONLD",
      targets: ["JSONLD"]
    ),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "JSONCodable",
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "JSONCodableTests",
      dependencies: ["JSONCodable"]
    ),
    .target(
      name: "JSONLD",
      dependencies: ["JSONCodable"],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "JSONLDTests",
      dependencies: ["JSONLD"]
    ),
    .testTarget(
      name: "JSONLDTestSuiteTests",
      dependencies: ["JSONLD"],
      resources: [
        .copy("Resources/Fixtures/")
      ]
    ),
  ]
)

if ProcessInfo.processInfo.environment["ENABLE_SWIFT_PLUGIN"] != nil
  || ProcessInfo.processInfo.environment["ADDITIONAL_DOCC_ARGUMENTS"] != nil
{
  package.dependencies += [
    .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.6")
  ]
}
