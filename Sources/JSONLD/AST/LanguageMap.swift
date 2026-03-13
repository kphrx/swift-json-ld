// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONLDValue {
  /// A *language map* object in JSON-LD.
  public struct LanguageMap: JSONLDObjectProtocol, Equatable {
    let map: [String: SingleOrMany<Value>]
  }
}

extension JSONLDValue.LanguageMap {
  /// A value inside a *language map*.
  public enum Value: JSONLDValueProtocol, Equatable {
    case string(String)
    case null
  }
}

extension JSONLDValue.LanguageMap.Value {
  /// Returns this language map value as a JSON value.
  public var jsonValue: JSONValue {
    switch self {
    case .string(let value): .string(value)
    case .null: .null
    }
  }

  /// Creates a language map value from a JSON value.
  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let value): self = .string(value)
    case .null: self = .null
    default: throw .code(.invalidLanguageMapValue)
    }
  }
}

extension JSONLDValue.LanguageMap {
  /// Returns this language map as a JSON object.
  public var jsonObject: JSONObject {
    self.map.jsonObject
  }

  /// Creates a language map from a JSON object.
  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    self.map = try jsonObject.mapValuesWithTypedThrows { jsonValue throws(JSONLDError) in
      try .init(from: jsonValue)
    }
  }
}
