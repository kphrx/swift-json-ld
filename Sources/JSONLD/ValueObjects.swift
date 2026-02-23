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
    if case .term(let value) = self, value.hasPrefix("_:") {
      throw .invalidTypedValue
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
    guard let value = properties.removeValue(forKey: "@value") else {
      throw .invalidValueObject
    }
    self.value = try .init(from: value)

    self.context = try properties.extractContext()

    let typeValue = properties.removeValue(forKey: "@type")
    let languageValue = properties.removeValue(forKey: "@language")

    if let languageValue {
      guard case .string(let language) = languageValue else {
        throw .invalidLanguageTaggedString
      }
      self.language = language
    } else {
      self.language = nil
    }

    if let typeValue {
      if languageValue != nil {
        throw .invalidValueObject
      }
      self.type = try .init(from: typeValue)
    } else {
      self.type = nil
    }

    self.index = try properties.extractIndex()

    if !properties.isEmpty {
      throw .invalidValueObject
    }

    if self.language != nil {
      switch self.value {
      case .string: break
      default: throw .invalidLanguageTaggedValue
      }
    }
  }
}
