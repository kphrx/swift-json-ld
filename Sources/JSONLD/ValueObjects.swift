// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum ValueType: JSONLDValueProtocol, Equatable {
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

struct ValueObject: JSONLDObjectProtocol, Equatable {
  enum Value: JSONLDValueProtocol, Equatable {
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

    self.context = try properties.extractContext()

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

    self.index = try properties.extractIndex()

    if !properties.isEmpty {
      throw .mustNotContainAnyOtherKeys
    }
  }
}
