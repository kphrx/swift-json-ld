# ``JSONCodable``

Provides type-safe polymorphic `Codable` JSON values for Swift.

## Overview

The module centers on ``JSONValue``, an enum that models JSON primitives and containers as a tagged union.
You can build values with enum cases or Swift literals, access nested arrays and objects with subscripts, bridge Swift types with ``CustomJSONValueConvertible`` and ``LosslessJSONValueConvertible``, and serialize values via `Codable`.

```swift
import JSONCodable

let payload: JSONValue = [
  "name": "apple",
  "count": 3,
  "active": true,
  "tags": ["fruit", "food"],
]

let count = Int(payload["count"] ?? .null) // Optional(3)
```
