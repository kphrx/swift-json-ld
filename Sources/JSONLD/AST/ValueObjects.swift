// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONLDValue {
  /// A *value object* in JSON-LD.
  public struct ValueObject: CustomJSONObjectConvertible {
    typealias ValueEntry = (term: String?, value: Value)
    typealias ContextEntry = (term: String?, value: Contexts)
    typealias TypeEntry = (term: String?, value: ValueType)
    typealias LanguageEntry = (term: String?, value: String)
    typealias IndexEntry = (term: String?, value: String)

    let valueEntry: ValueEntry
    let contextEntry: ContextEntry?
    let typeEntry: TypeEntry?
    let languageEntry: LanguageEntry?
    let indexEntry: IndexEntry?
  }
}

extension JSONLDValue.ValueObject {
  /// The `@type` value for a value object.
  enum ValueType: CustomJSONValueConvertible, Equatable {
    case iriOrTerm(String)
    case null
  }

  /// The `@value` payload of a value object.
  enum Value: CustomJSONValueConvertible, Equatable {
    case string(String)
    case integer(Int)
    case float(Double)
    case boolean(Bool)
    case null
  }
}

extension JSONLDValue.ValueObject: Equatable {
  /// Returns a Boolean value indicating whether two values are equal.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.valueEntry.term == rhs.valueEntry.term
      && lhs.valueEntry.value == rhs.valueEntry.value
      && lhs.contextEntry?.term == rhs.contextEntry?.term
      && lhs.contextEntry?.value == rhs.contextEntry?.value
      && lhs.typeEntry?.term == rhs.typeEntry?.term
      && lhs.typeEntry?.value == rhs.typeEntry?.value
      && lhs.languageEntry?.term == rhs.languageEntry?.term
      && lhs.languageEntry?.value == rhs.languageEntry?.value
      && lhs.indexEntry?.term == rhs.indexEntry?.term
      && lhs.indexEntry?.value == rhs.indexEntry?.value
  }
}

extension JSONLDValue.ValueObject.ValueType {
  var jsonValue: JSONValue {
    switch self {
    case .iriOrTerm(let value): .string(value)
    case .null: .null
    }
  }

  init(_ value: String) throws(JSONLDError) {
    guard !value.hasPrefix("_:") else {
      throw .code(.invalidTypedValue)
    }
    self = .iriOrTerm(value)
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .string(let value) where !value.hasPrefix("_:"): .iriOrTerm(value)
      case .null: .null
      default: throw .code(.invalidTypedValue)
      }
  }
}

extension JSONLDValue.ValueObject.Value {
  var jsonValue: JSONValue {
    switch self {
    case .string(let value): .string(value)
    case .integer(let value): .integer(value)
    case .float(let value): .float(value)
    case .boolean(let value): .boolean(value)
    case .null: .null
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
      default: throw .code(.invalidValueObjectValue)
      }
  }
}

extension JSONLDValue.ValueObject {
  var value: Value {
    self.valueEntry.value
  }

  var context: Contexts? {
    self.contextEntry?.value
  }

  var type: ValueType? {
    self.typeEntry?.value
  }

  var language: String? {
    self.languageEntry?.value
  }

  var index: String? {
    self.indexEntry?.value
  }

  /// Returns this value object as a JSON object.
  public var jsonObject: JSONObject {
    var jsonObject: JSONObject = [:]

    jsonObject.set(self.valueEntry.value, for: .value, term: self.valueEntry.term)

    if let typeEntry = self.typeEntry {
      jsonObject.set(typeEntry.value, for: .type, term: typeEntry.term)
    }

    if let languageEntry = self.languageEntry {
      jsonObject.set(languageEntry.value, for: .language, term: languageEntry.term)
    }

    if let contextEntry = self.contextEntry {
      jsonObject.set(contextEntry.value, for: .context, term: contextEntry.term)
    }

    if let indexEntry = self.indexEntry {
      jsonObject.set(indexEntry.value, for: .index, term: indexEntry.term)
    }

    return jsonObject
  }
}

extension JSONLDValue.ValueObject where P == Expanded {
  init(value: Value, language: String? = nil, context: Contexts? = nil, index: String? = nil) {
    self.valueEntry = (term: nil, value: value)
    self.contextEntry = context.map { (term: nil, value: $0) }
    self.indexEntry = index.map { (term: nil, value: $0) }
    self.typeEntry = nil
    self.languageEntry = language.map { (term: nil, value: $0) }
  }

  init(value: Value, type: ValueType?, context: Contexts? = nil, index: String? = nil) {
    self.valueEntry = (term: nil, value: value)
    self.contextEntry = context.map { (term: nil, value: $0) }
    self.indexEntry = index.map { (term: nil, value: $0) }
    self.typeEntry = type.map { (term: nil, value: $0) }
    self.languageEntry = nil
  }
}

extension JSONLDValue.ValueObject where P == Compacted {
  init(
    value: ValueEntry,
    type: TypeEntry? = nil,
    language: LanguageEntry? = nil,
    context: ContextEntry? = nil,
    index: IndexEntry? = nil
  ) {
    self.valueEntry = value
    self.typeEntry = type
    self.languageEntry = language
    self.contextEntry = context
    self.indexEntry = index
  }
}

extension JSONLDValue.ValueObject where P == Flattened {
  init(
    value: Value,
    language: String? = nil,
    index: String? = nil
  ) {
    self.valueEntry = (term: nil, value: value)
    self.contextEntry = nil
    self.indexEntry = index.map { (term: nil, value: $0) }
    self.typeEntry = nil
    self.languageEntry = language.map { (term: nil, value: $0) }
  }

  init(
    value: Value,
    type: ValueType?,
    index: String? = nil
  ) {
    self.valueEntry = (term: nil, value: value)
    self.contextEntry = nil
    self.indexEntry = index.map { (term: nil, value: $0) }
    self.typeEntry = type.map { (term: nil, value: $0) }
    self.languageEntry = nil
  }
}

extension JSONLDValue.ValueObject where P == Unresolved {
  init(value: Value) {
    self.valueEntry = (term: nil, value: value)
    self.contextEntry = nil
    self.typeEntry = nil
    self.languageEntry = nil
    self.indexEntry = nil
  }

  /// Creates a value object from a JSON object.
  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    guard let value = properties.removeValue(for: .value) else {
      throw .internalError(.notValueObject)
    }
    self.valueEntry = (term: nil, value: try .init(from: value))

    self.contextEntry = try properties.extractContext().map { (term: nil, value: $0) }

    let typeValue = properties.removeValue(for: .type)
    let languageValue = properties.removeValue(for: .language)

    if let languageValue {
      guard case .string(let language) = languageValue else {
        throw .code(.invalidLanguageTaggedString)
      }
      self.languageEntry = (term: nil, value: language)
    } else {
      self.languageEntry = nil
    }

    if let typeValue {
      if languageValue != nil {
        throw .code(.invalidValueObject)
      }
      self.typeEntry = (term: nil, value: try .init(from: typeValue))
    } else {
      self.typeEntry = nil
    }

    self.indexEntry = try properties.extractIndex().map { (term: nil, value: $0) }

    if !properties.isEmpty {
      throw .code(.invalidValueObject)
    }

    if self.languageEntry != nil {
      switch self.valueEntry.value {
      case .string: break
      default: throw .code(.invalidLanguageTaggedValue)
      }
    }
  }
}
