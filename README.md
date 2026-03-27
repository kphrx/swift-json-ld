# swift-json-codable

<!-- docc_landing_abstract_start -->
swift-json-codable is a Swift 6 library for JSON value handling and JSON-LD 1.0 processing.
<!-- docc_landing_abstract_end -->

For usage examples and API references, see the [documentation](https://kpherox.dev/swift-json-codable/documentation/).

## Requirements

- Swift 6.0+

## Installation

Add `swift-json-codable` to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/kphrx/swift-json-codable.git", branch: "master")
],
targets: [
  .target(
    name: "YourTarget",
    dependencies: [
      // JSONLD depends on JSONCodable and `@_exported` it, so you don't need to explicitly depend on JSONCodable.
      .product(name: "JSONLD", package: "swift-json-codable")
    ]
  )
]
```

Alternatively, you can use SwiftPM commands:

```bash
swift package add-dependency https://github.com/kphrx/swift-json-codable.git --branch master
# swift package add-target-dependency JSONCodable YourTarget --package swift-json-codable
swift package add-target-dependency JSONLD YourTarget --package swift-json-codable
```

## Modules

- **JSONCodable**: Type-safe polymorphic `Codable` JSON values for Swift.
- **JSONLD**: Swift-native JSON-LD processor focused on JSON-LD 1.0, with phase-typed APIs to prevent illegal states.

## Unsupported Features

- The `processingMode` option is fixed to `json-ld-1.0` (switching is not implemented yet).
- JSON-LD Framing and RDF dataset conversion are out of scope for now.

## Development

### Clone

```bash
git clone https://github.com/kphrx/swift-json-codable.git
cd swift-json-codable
```

### Build

This repository tracks a Swift toolchain version via `.swift-version`. If you use `swiftly`, the following will automatically select that version:

```bash
swiftly run -- swift build
```

### Test

```bash
swiftly run -- swift test --disable-xctest
```

### JSON-LD Test Suite

To run the W3C JSON-LD Test Suite, prepare the test fixtures and set `JSONLD_TEST_FIXTURES`:

```bash
tmpdir="$(mktemp -d)"
git clone https://github.com/w3c/json-ld-api.git "$tmpdir/json-ld-api"

# Specify the fixture path via an environment variable (recommended)
export JSONLD_TEST_FIXTURES="$tmpdir/json-ld-api/tests"
swiftly run -- swift test --disable-xctest
```

Note for compaction expectations:
- JSON-LD test results that include `context` assume the context is provided locally.
- Expected outputs therefore include the context content, not a remote URL reference.

Alternatively, you can use a symlink instead of `JSONLD_TEST_FIXTURES`:

```bash
rm -f Tests/JSONLDTestSuiteTests/Resources/Fixtures/json-ld-api-tests
ln -s "$tmpdir/json-ld-api/tests" Tests/JSONLDTestSuiteTests/Resources/Fixtures/json-ld-api-tests
```

Test fixtures are resolved from the built test bundle location (e.g., `.build/.../swift-json-codable_JSONLDTestSuiteTests.bundle/...`) rather than from the source tree path. Therefore, a relative symlink to `json-ld-api/tests` under `Tests/JSONLDTestSuiteTests/Resources/Fixtures/` fails to resolve.

## License

This project is licensed under the Apache License 2.0.  
See `LICENSE` and `NOTICE` for details.
