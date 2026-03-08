# ``JSONCodable``

Provides type-safe polymorphic `Codable` JSON values for Swift.

## Overview

The module centers on ``JSONValue``, an enum that models JSON primitives and containers as a tagged union.
You can decode any JSON data into a ``JSONValue``, access its content with subscripts, and extract values safely using type initializers.

```swift
import JSONCodable

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

// Decode from JSON data
let jsonString = #"{"name": "apple", "count": 3, "tags": ["fruit", "food"]}"#
let jsonData = Data(jsonString.utf8)
let payload = try JSONDecoder().decode(JSONValue.self, from: jsonData)

// Access and extract values safely
let name = String(payload["name"] ?? .null)   // Optional("apple")
let count = Int(payload["count"] ?? .null)    // Optional(3)
let tags = [String](payload["tags"] ?? .null) // Optional(["fruit", "food"])

// Encode back to JSON
let encoder = JSONEncoder()
encoder.outputFormatting = .sortedKeys
let encodedData = try encoder.encode(payload)
print(String(data: encodedData, encoding: .utf8)!)
// {"count":3,"name":"apple","tags":["fruit","food"]}
```

You can also bridge your own types with ``CustomJSONValueConvertible`` and ``LosslessJSONValueConvertible``, or build values directly with Swift literals.
