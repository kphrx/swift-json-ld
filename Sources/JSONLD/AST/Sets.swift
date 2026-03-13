// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONLDValue {
  /// A *set object* or *list object* in JSON-LD.
  public enum SetOrListObject: JSONLDObjectProtocol, JSONLDValueProtocol, Equatable {
    case set(SingleOrMany<Element>, context: Contexts?, index: String?)
    case list(SingleOrMany<Element>, context: Contexts?, index: String?)
  }
}

extension JSONLDValue.SetOrListObject {
  /// An element contained in a `@set` or `@list`.
  public enum Element: JSONLDValueProtocol, Equatable {
    case string(String)
    case integer(Int)
    case float(Double)
    case boolean(Bool)
    case null
    case nodeObject(JSONLDValue.NodeObject)
    case valueObject(JSONLDValue.ValueObject)
  }
}

extension JSONLDValue.SetOrListObject.Element {
  static func from(_ jsonArray: JSONArray) throws(JSONLDError) -> [Self] {
    try jsonArray.map(Self.init(from:))
  }

  /// Returns this element as a JSON value.
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

  /// Creates an element from a JSON value.
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

extension JSONLDValue.SetOrListObject {
  private var values: SingleOrMany<Element> {
    switch self {
    case .set(let values, _, _), .list(let values, _, _):
      values
    }
  }

  var setOrListValues: SingleOrMany<Element> {
    self.values
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

  /// Returns this set or list as a JSON object.
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

  /// Creates a set or list object from a JSON object.
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
