// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum ValueType {
  case term(String)
  case compactIRI(String)
  case absoluteIRI(String)
  case relativeIRI(String)
  case null

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .string(let value): .term(value)
      case .null: .null
      default: throw .invalidValue
      }
  }
}

struct ValueObject {
  enum Value {
    case string(String)
    case integer(Int)
    case float(Double)
    case boolean(Bool)
    case null

    init(from jsonValue: JSONValue) throws(JSONLDError) {
      self =
        switch jsonValue {
        case .string(let value): .string(value)
        case .integer(let value): .integer(value)
        case .float(let value): .float(value)
        case .boolean(let value): .boolean(value)
        case .null: .null
        default: throw .invalidValue
        }
    }
  }
  let value: Value
  let context: Contexts?
  let type: ValueType?
  let language: String?
  let index: String?

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    guard let value = properties.removeValue(forKey: "@value") else {
      throw .missingValue
    }
    self.value = try .init(from: value)

    self.context =
      if let context = properties.removeValue(forKey: "@context") {
        try .init(from: context)
      } else { nil }

    switch (properties.removeValue(forKey: "@type"), properties.removeValue(forKey: "@language")) {
    case (.some(_), .some(_)): throw .mustNotContainBothTypeAndLanguage
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
      throw .invalidLanguage
    }

    self.index =
      if let index = properties.removeValue(forKey: "@index") {
        if case .string(let value) = index {
          value
        } else {
          throw .invalidIndex
        }
      } else { nil }

    if !properties.isEmpty {
      throw .mustNotContainAnyOtherKeys
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
