// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum ValueType: JSONLDValueProtocol, Equatable {
  case term(String)
  case compactIRI(String)
  case absoluteIRI(String)
  case relativeIRI(String)
  case null

  var jsonValue: JSONValue {
    switch self {
    case .term(let value): .string(value)
    case .compactIRI(let value): .string(value)
    case .absoluteIRI(let value): .string(value)
    case .relativeIRI(let value): .string(value)
    case .null: .null
    }
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .string(let value): .term(value)
      case .null: .null
      default: throw .invalidTypedValue
      }
  }
}

struct ValueObject: JSONLDObjectProtocol, Equatable {
  enum Value: JSONLDValueProtocol, Equatable {
    case string(String)
    case integer(Int)
    case float(Double)
    case boolean(Bool)
    case null

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
        default: throw .invalidValueObjectValue
        }
    }
  }
  let value: Value?
  let context: Contexts?
  let type: ValueType?
  let language: String?
  let index: String?

  var jsonObject: JSONObject {
    var jsonObject: JSONObject = [:]

    if let value = self.value {
      jsonObject["@value"] = value.jsonValue
    }

    if let type = self.type {
      jsonObject["@type"] = type.jsonValue
    }

    if let language = self.language {
      jsonObject["@language"] = .string(language)
    }

    if let index = self.index {
      jsonObject["@index"] = .string(index)
    }

    return jsonObject
  }

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    self.value =
      if let value = properties.removeValue(forKey: "@value") {
        try .init(from: value)
      } else { nil }

    self.context = try properties.extractContext()

    switch (properties.removeValue(forKey: "@type"), properties.removeValue(forKey: "@language")) {
    case (.some(_), .some(_)): throw .invalidValueObject
    case (.none, .none):
      self.type = nil
      self.language = nil
    case (.some(let type), .none):
      self.type = try .init(from: type)
      self.language = nil
    case (.none, .some(.string(let language))):
      self.type = nil
      self.language = language
    default:
      throw .invalidValueObject
    }

    self.index = try properties.extractIndex()

    if !properties.isEmpty {
      throw .invalidValueObject
    }
  }
}
