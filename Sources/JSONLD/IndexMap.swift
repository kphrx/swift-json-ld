// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum IndexedValue: Equatable {
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

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .string(let value): .string(value)
      case .integer(let value): .integer(value)
      case .float(let value): .float(value)
      case .boolean(let value): .boolean(value)
      case .null: .null
      case .object(let jsonObject):
        if jsonObject.keys.contains("@value") {
          try .valueObject(.init(from: jsonObject))
        } else if jsonObject.keys.contains("@list") {
          try .listObject(.init(from: jsonObject))
        } else if jsonObject.keys.contains("@set") {
          try .setObject(.init(from: jsonObject))
        } else {
          try .nodeObject(.init(from: jsonObject))
        }
      default: throw .invalidIndexedValue
      }
  }
}

struct IndexMap: Equatable {
  let map: [String: [IndexedValue]]

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    self.map = try jsonObject.mapValuesWithTypedThrows { jsonValue throws(JSONLDError) in
      if case .array(let array) = jsonValue {
        try IndexedValue.from(array)
      } else {
        [try .init(from: jsonValue)]
      }
    }
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    if case .object(let jsonObject) = jsonValue {
      try self.init(from: jsonObject)
    } else {
      throw .notObject
    }
  }
}
