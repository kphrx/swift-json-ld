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

  var jsonValue: JSONValue {
    switch self {
    case .string(let value): .string(value)
    case .integer(let value): .integer(value)
    case .float(let value): .float(value)
    case .boolean(let value): .boolean(value)
    case .null: .null
    case .nodeObject(let nodeObject): nodeObject.jsonValue
    case .valueObject(let valueObject): valueObject.jsonValue
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
        if jsonObject.contains(.list) {
          // NOTE: JSON-LD 1.1 allows lists of lists; keep this for json-ld-1.0 only.
          throw .code(.listOfLists)
        } else if jsonObject.contains(.value) {
          try .valueObject(.init(from: jsonObject))
        } else {
          try .nodeObject(.init(from: jsonObject))
        }
      default:
        // NOTE: JSON-LD 1.1 allows lists of lists; keep this for json-ld-1.0 only.
        throw .code(.listOfLists)
      }
  }
}

struct ListObject: JSONLDObjectProtocol, Equatable {
  let list: SingleOrMany<SetValue>
  let context: Contexts?
  let index: String?

  var jsonObject: JSONObject {
    var jsonObject: JSONObject = [:]
    jsonObject[.list] = self.list.jsonValue

    if let context = self.context {
      jsonObject[.context] = context.jsonValue
    }

    if let index = self.index {
      jsonObject[.index] = .string(index)
    }

    return jsonObject
  }

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    guard let listValue = properties.removeValue(for: .list) else {
      throw .code(.invalidSetOrListObject)
    }

    self.list = try .init(from: listValue)

    self.context = try properties.extractContext()
    self.index = try properties.extractIndex()

    if !properties.isEmpty {
      throw .code(.invalidSetOrListObject)
    }
  }
}

struct SetObject: JSONLDObjectProtocol, JSONLDValueProtocol, Equatable {
  let set: SingleOrMany<SetValue>
  let context: Contexts?
  let index: String?

  var jsonObject: JSONObject {
    var jsonObject: JSONObject = [:]
    jsonObject[.set] = self.set.jsonValue

    if let context = self.context {
      jsonObject[.context] = context.jsonValue
    }

    if let index = self.index {
      jsonObject[.index] = .string(index)
    }

    return jsonObject
  }

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    guard let setValue = properties.removeValue(for: .set) else {
      throw .code(.invalidSetOrListObject)
    }

    self.set = try .init(from: setValue)

    self.context = try properties.extractContext()
    self.index = try properties.extractIndex()

    if !properties.isEmpty {
      throw .code(.invalidSetOrListObject)
    }
  }
}
