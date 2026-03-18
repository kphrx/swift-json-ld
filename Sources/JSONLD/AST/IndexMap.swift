// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONLDValue {
  /// An *index map* object in JSON-LD.
  public struct IndexMap: CustomJSONObjectConvertible, Equatable {
    let map: [String: SingleOrMany<Value>]
  }
}

extension JSONLDValue.IndexMap {
  /// A value inside an *index map*.
  public enum Value: CustomJSONValueConvertible, Equatable {
    case string(String)
    case integer(Int)
    case float(Double)
    case boolean(Bool)
    case null
    case nodeObject(JSONLDValue.NodeObject)
    case valueObject(JSONLDValue.ValueObject)
    case setOrListObject(JSONLDValue.SetOrListObject)
  }
}

extension JSONLDValue.IndexMap.Value {
  static func from(_ jsonArray: JSONArray) throws(JSONLDError) -> [Self] {
    try jsonArray.map(Self.init(from:))
  }

  /// Returns this index map value as a JSON value.
  public var jsonValue: JSONValue {
    switch self {
    case .string(let value): .string(value)
    case .integer(let value): .integer(value)
    case .float(let value): .float(value)
    case .boolean(let value): .boolean(value)
    case .null: .null
    case .nodeObject(let nodeObject): nodeObject.jsonValue
    case .valueObject(let valueObject): valueObject.jsonValue
    case .setOrListObject(let object): object.jsonValue
    }
  }

  /// Creates an index map value from a JSON value.
  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .string(let value): .string(value)
      case .integer(let value): .integer(value)
      case .float(let value): .float(value)
      case .boolean(let value): .boolean(value)
      case .null: .null
      case .object(let jsonObject):
        if jsonObject.contains(.value) {
          try .valueObject(.init(from: jsonObject))
        } else if jsonObject.contains(.list) || jsonObject.contains(.set) {
          try .setOrListObject(.init(from: jsonObject))
        } else {
          try .nodeObject(.init(from: jsonObject))
        }
      default: throw .code(.invalidIndexValue)
      }
  }
}

extension JSONLDValue.IndexMap {
  /// Returns this index map as a JSON object.
  public var jsonObject: JSONObject {
    self.map.jsonObject
  }

  /// Creates an index map from a JSON object.
  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    self.map = try jsonObject.mapValuesWithTypedThrows { jsonValue throws(JSONLDError) in
      try .init(from: jsonValue, mapper: Value.init(from:))
    }
  }
}
