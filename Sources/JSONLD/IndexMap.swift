// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum IndexedValue: JSONLDValueProtocol, Equatable {
  case string(String)
  case integer(Int)
  case float(Double)
  case boolean(Bool)
  case null
  case nodeObject(NodeObject)
  case valueObject(ValueObject)
  case listObject(ListObject)
  case setObject(SetObject)

  static func from(_ jsonArray: JSONArray) throws(JSONLDError) -> [IndexedValue] {
    try jsonArray.map(IndexedValue.init(from:))
  }

  var jsonValue: JSONValue {
    switch self {
    case .string(let value): .string(value)
    case .integer(let value): .integer(value)
    case .float(let value): .float(value)
    case .boolean(let value): .boolean(value)
    case .null: .null
    case .nodeObject(let nodeObject): nodeObject.jsonValue
    case .valueObject(let valueObject): valueObject.jsonValue
    case .listObject(let listObject): listObject.jsonValue
    case .setObject(let setObject): setObject.jsonValue
    }
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
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
        } else if jsonObject.contains(.list) {
          try .listObject(.init(from: jsonObject))
        } else if jsonObject.contains(.set) {
          try .setObject(.init(from: jsonObject))
        } else {
          try .nodeObject(.init(from: jsonObject))
        }
      default: throw .code(.invalidIndexValue)
      }
  }
}

struct IndexMap: JSONLDObjectProtocol, Equatable {
  let map: [String: SingleOrMany<IndexedValue>]

  var jsonObject: JSONObject {
    self.map.jsonObject
  }

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    self.map = try jsonObject.mapValuesWithTypedThrows { jsonValue throws(JSONLDError) in
      try .init(from: jsonValue)
    }
  }
}
