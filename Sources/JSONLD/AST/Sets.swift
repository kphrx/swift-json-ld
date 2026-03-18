// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONLDValue {
  /// A *set object* or *list object* in JSON-LD.
  public struct SetOrListObject: CustomJSONObjectConvertible, Equatable {
    private typealias ValueEntry = (term: String?, value: Value)
    private typealias ContextEntry = (term: String?, value: Contexts)
    private typealias IndexEntry = (term: String?, value: String)

    private let valueEntry: ValueEntry
    private let contextEntry: ContextEntry?
    private let indexEntry: IndexEntry?

    init(
      term: String? = nil,
      value: Value,
      context: Contexts? = nil,
      contextTerm: String? = nil,
      index: String? = nil,
      indexTerm: String? = nil
    ) {
      self.valueEntry = (term: term, value: value)
      self.contextEntry = context.map { (term: contextTerm, value: $0) }
      self.indexEntry = index.map { (term: indexTerm, value: $0) }
    }
  }
}

extension JSONLDValue.SetOrListObject {
  enum Value: Equatable {
    case set(SingleOrMany<Element>)
    case list(SingleOrMany<Element>)
  }

  /// An element contained in a `@set` or `@list`.
  public enum Element: CustomJSONValueConvertible, Equatable {
    case string(String)
    case integer(Int)
    case float(Double)
    case boolean(Bool)
    case null
    case nodeObject(JSONLDValue.NodeObject)
    case valueObject(JSONLDValue.ValueObject)
  }
}

extension JSONLDValue.SetOrListObject.Value: Sequence {
  func makeIterator() -> AnyIterator<JSONLDValue.SetOrListObject.Element> {
    switch self {
    case .set(let values), .list(let values): values.makeIterator()
    }
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
  var value: Value {
    self.valueEntry.value
  }

  var valueTerm: String? {
    self.valueEntry.term
  }

  var context: Contexts? {
    self.contextEntry?.value
  }

  var contextTerm: String? {
    self.contextEntry?.term
  }

  var index: String? {
    self.indexEntry?.value
  }

  var indexTerm: String? {
    self.indexEntry?.term
  }

  /// Returns this set or list as a JSON object.
  public var jsonObject: JSONObject {
    var jsonObject: JSONObject = [:]
    switch self.value {
    case .set(let values): jsonObject.set(values, for: .set, term: self.valueTerm)
    case .list(let values): jsonObject.set(values, for: .list, term: self.valueTerm)
    }

    if let context = self.context {
      jsonObject.set(context, for: .context, term: self.contextTerm)
    }

    if let index = self.index {
      jsonObject.set(index, for: .index, term: self.indexTerm)
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
        .init(
          value: .set(try .init(from: setValue, mapper: Element.init(from:))),
          context: context,
          index: index,
        )
      case (.none, .some(let listValue), true):
        .init(
          value: .list(try .init(from: listValue, mapper: Element.init(from:))),
          context: context,
          index: index,
        )
      default: throw .code(.invalidSetOrListObject)
      }
  }
}

extension JSONLDValue.SetOrListObject {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.valueEntry.term == rhs.valueEntry.term
      && lhs.valueEntry.value == rhs.valueEntry.value
      && lhs.contextEntry?.term == rhs.contextEntry?.term
      && lhs.contextEntry?.value == rhs.contextEntry?.value
      && lhs.indexEntry?.term == rhs.indexEntry?.term
      && lhs.indexEntry?.value == rhs.indexEntry?.value
  }
}
