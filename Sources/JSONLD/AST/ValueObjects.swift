// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONLDValue {
  /// A *value object* in JSON-LD.
  public struct ValueObject: JSONLDObjectProtocol, Equatable {
    let value: Value
    let context: Contexts?
    let type: ValueType?
    let language: String?
    let index: String?
  }
}

extension JSONLDValue.ValueObject {
  /// The `@type` value for a value object.
  enum ValueType: JSONLDValueProtocol, Equatable {
    case iriOrTerm(String)
    case null
  }

  /// The `@value` payload of a value object.
  enum Value: JSONLDValueProtocol, Equatable {
    case string(String)
    case integer(Int)
    case float(Double)
    case boolean(Bool)
    case null
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
  /// Returns this value object as a JSON object.
  public var jsonObject: JSONObject {
    var jsonObject: JSONObject = [:]

    jsonObject[.value] = self.value.jsonValue

    if let type = self.type {
      jsonObject[.type] = type.jsonValue
    }

    if let language = self.language {
      jsonObject[.language] = .string(language)
    }

    if let index = self.index {
      jsonObject[.index] = .string(index)
    }

    return jsonObject
  }

  init(value: Value, language: String? = nil, context: Contexts? = nil, index: String? = nil) {
    self.value = value
    self.context = context
    self.index = index
    self.language = language
    self.type = nil
  }

  init(
    value: Value,
    type: String?,
    context: Contexts? = nil,
    index: String? = nil
  ) throws(JSONLDError) {
    self.value = value
    self.context = context
    self.index = index
    self.type =
      if let type {
        try .init(type)
      } else {
        .null
      }
    self.language = nil
  }

  /// Creates a value object from a JSON object.
  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    guard let value = properties.removeValue(for: .value) else {
      throw .internalError(.notValueObject)
    }
    self.value = try .init(from: value)

    self.context = try properties.extractContext()

    let typeValue = properties.removeValue(for: .type)
    let languageValue = properties.removeValue(for: .language)

    if let languageValue {
      guard case .string(let language) = languageValue else {
        throw .code(.invalidLanguageTaggedString)
      }
      self.language = language
    } else {
      self.language = nil
    }

    if let typeValue {
      if languageValue != nil {
        throw .code(.invalidValueObject)
      }
      self.type = try .init(from: typeValue)
    } else {
      self.type = nil
    }

    self.index = try properties.extractIndex()

    if !properties.isEmpty {
      throw .code(.invalidValueObject)
    }

    if self.language != nil {
      switch self.value {
      case .string: break
      default: throw .code(.invalidLanguageTaggedValue)
      }
    }
  }
}
