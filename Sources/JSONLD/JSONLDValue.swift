// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

indirect enum JSONLDValue: JSONLDValueProtocol, Equatable {
  case term(String)
  case compactIRI(String)
  case absoluteIRI(String)
  case relativeIRI(String)
  case node(NodeObject)
  case value(ValueObject)
  case set(SetObject)
  case list(ListObject)
  case languageMap(LanguageMap)
  case indexMap(IndexMap)

  var jsonValue: JSONValue {
    switch self {
    case .term(let term): .string(term)
    case .compactIRI(let iri), .absoluteIRI(let iri), .relativeIRI(let iri): .string(iri)
    case .node(let node): node.jsonValue
    case .value(let value): value.jsonValue
    case .set(let set): set.jsonValue
    case .list(let list): list.jsonValue
    case .languageMap(let languageMap): languageMap.jsonValue
    case .indexMap(let indexMap): indexMap.jsonValue
    }
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let string):
      if string.contains(":") {
        self = .compactIRI(string)
      } else if string.hasPrefix("/") || string.hasPrefix("./") || string.hasPrefix("../") {
        self = .relativeIRI(string)
      } else if string.contains("://") {
        self = .absoluteIRI(string)
      } else {
        self = .term(string)
      }
    case .object(let jsonObject):
      if jsonObject["@value"] != nil {
        self = .value(try .init(from: jsonObject))
      } else if jsonObject["@set"] != nil {
        self = .set(try .init(from: jsonObject))
      } else if jsonObject["@list"] != nil {
        self = .list(try .init(from: jsonObject))
      } else if jsonObject["@id"] != nil
        || jsonObject["@type"] != nil
        || jsonObject["@graph"] != nil
        || jsonObject["@reverse"] != nil
        || jsonObject["@context"] != nil
      {
        self = .node(try .init(from: jsonObject))
      } else if jsonObject["@language"] != nil {
        throw .internalError(.notJSONLDValue)
      } else if !jsonObject.keys.contains(where: { $0.hasPrefix("@") }) {
        if let languageMap = try? LanguageMap(from: jsonValue) {
          self = .languageMap(languageMap)
        } else if let indexMap = try? IndexMap(from: jsonValue) {
          self = .indexMap(indexMap)
        } else {
          self = .value(try .init(from: jsonObject))
        }
      } else {
        self = .value(try .init(from: jsonObject))
      }
    default: throw .internalError(.notJSONLDValue)
    }
  }
}
