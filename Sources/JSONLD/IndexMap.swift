// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public enum IndexValue<P: JSONLDPhase>: JSONLDValueProtocol, Equatable {
  case string(String)
  case integer(Int)
  case float(Double)
  case boolean(Bool)
  case null
  case nodeObject(NodeObject<P>)
  case valueObject(ValueObject<P>)
  case setOrListObject(SetOrListObject<P>)

  static func from(_ jsonArray: JSONArray) throws(JSONLDError) -> [IndexValue<P>] {
    try jsonArray.map(IndexValue.init(from:))
  }

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

public struct IndexMap<P: JSONLDPhase>: JSONLDObjectProtocol, Equatable {
  let map: [String: SingleOrMany<IndexValue<P>>]

  public var jsonObject: JSONObject {
    self.map.jsonObject
  }

  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    self.map = try jsonObject.mapValuesWithTypedThrows { jsonValue throws(JSONLDError) in
      try .init(from: jsonValue)
    }
  }
}
