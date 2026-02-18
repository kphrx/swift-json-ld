// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum SetValue: JSONLDValueProtocol, Equatable {
  case string(String)
  case integer(Int)
  case float(Double)
  case boolean(Bool)
  case null
  case nodeObject(NodeObject)
  case valueObject(ValueObject)

  static func from(_ jsonArray: JSONArray) throws(JSONLDError) -> [SetValue] {
    try jsonArray.map(SetValue.init(from:))
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
        } else {
          try .nodeObject(.init(from: jsonObject))
        }
      default: throw .invalidSetValue
      }
  }
}

struct ListObject: JSONLDObjectProtocol, Equatable {
  let list: [SetValue]
  let context: Contexts?
  let index: String?

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    guard let listValue = properties.removeValue(forKey: "@list") else {
      throw .missingValue
    }

    self.list =
      if case .array(let array) = listValue {
        try SetValue.from(array)
      } else {
        [try .init(from: listValue)]
      }

    self.context =
      if let context = properties.removeValue(forKey: "@context") {
        try .init(from: context)
      } else { nil }

    self.index =
      if let indexValue = properties.removeValue(forKey: "@index") {
        if case .string(let value) = indexValue {
          value
        } else {
          throw .invalidIndex
        }
      } else { nil }

    if !properties.isEmpty {
      throw .mustNotContainAnyOtherKeys
    }
  }
}

struct SetObject: JSONLDObjectProtocol, JSONLDValueProtocol, Equatable {
  let set: [SetValue]
  let context: Contexts?
  let index: String?

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    guard let setValue = properties.removeValue(forKey: "@set") else {
      throw .missingValue
    }

    self.set =
      if case .array(let array) = setValue {
        try SetValue.from(array)
      } else {
        [try .init(from: setValue)]
      }

    self.context =
      if let context = properties.removeValue(forKey: "@context") {
        try .init(from: context)
      } else { nil }

    self.index =
      if let indexValue = properties.removeValue(forKey: "@index") {
        if case .string(let value) = indexValue {
          value
        } else {
          throw .invalidIndex
        }
      } else { nil }

    if !properties.isEmpty {
      throw .mustNotContainAnyOtherKeys
    }
  }
}
