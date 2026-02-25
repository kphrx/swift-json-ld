// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public enum SetValue<P: JSONLDPhase>: JSONLDValueProtocol, Equatable {
  case string(String)
  case integer(Int)
  case float(Double)
  case boolean(Bool)
  case null
  case nodeObject(NodeObject<P>)
  case valueObject(ValueObject<P>)

  static func from(_ jsonArray: JSONArray) throws(JSONLDError) -> [SetValue<P>] {
    try jsonArray.map(SetValue.init(from:))
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

public enum SetOrListObject<P: JSONLDPhase>: JSONLDObjectProtocol, JSONLDValueProtocol, Equatable {
  case set(SingleOrMany<SetValue<P>>, context: Contexts?, index: String?)
  case list(SingleOrMany<SetValue<P>>, context: Contexts?, index: String?)

  private var values: SingleOrMany<SetValue<P>> {
    switch self {
    case .set(let values, _, _), .list(let values, _, _):
      values
    }
  }

  private var context: Contexts? {
    switch self {
    case .set(_, let context, _), .list(_, let context, _):
      context
    }
  }

  private var index: String? {
    switch self {
    case .set(_, _, let index), .list(_, _, let index):
      index
    }
  }

  private var keyword: JSONLDKeyword {
    switch self {
    case .set:
      .set
    case .list:
      .list
    }
  }

  public var jsonObject: JSONObject {
    var jsonObject: JSONObject = [:]
    jsonObject[self.keyword] = self.values.jsonValue

    if let context = self.context {
      jsonObject[.context] = context.jsonValue
    }

    if let index = self.index {
      jsonObject[.index] = .string(index)
    }

    return jsonObject
  }

  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    let context = try properties.extractContext()
    let index = try properties.extractIndex()

    self =
      switch (
        properties.removeValue(for: .set), properties.removeValue(for: .list), properties.isEmpty
      ) {
      case (.none, .none, _): throw .internalError(.notSetOrListObject)
      case (.some(let setValue), .none, true):
        .set(try .init(from: setValue), context: context, index: index)
      case (.none, .some(let listValue), true):
        .list(try .init(from: listValue), context: context, index: index)
      default: throw .code(.invalidSetOrListObject)
      }
  }
}
