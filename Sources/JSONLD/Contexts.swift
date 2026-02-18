// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import struct Foundation.URL

enum Contexts: JSONLDValueProtocol, Equatable {
  case null
  case single(Context)
  case array([Context])

  init(from jsonArray: JSONArray) throws(JSONLDError) {
    self = .array(try jsonArray.map(Context.init(from:)))
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      if case .null = jsonValue {
        .null
      } else {
        switch try SingleOrMany<Context>(from: jsonValue) {
        case .single(let context): .single(context)
        case .many(let contexts): .array(contexts)
        }
      }
  }
}

enum Context: JSONLDObjectProtocol, Equatable {
  case absolute(URL)
  case relative(URL)
  case contextDefinition(ContextDefinition)

  init(iri value: String) throws(JSONLDError) {
    guard let url = URL(string: value) else { throw .invalidIRI(value) }
    self = .absolute(url)
  }

  init(from jsonObject: JSONObject) {
    self = .contextDefinition(.init(from: jsonObject))
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .object(let jsonObject): .init(from: jsonObject)
      case .string(let value): try .init(iri: value)
      default: throw .invalidContextValue
      }
  }
}

struct ContextDefinition: JSONLDObjectProtocol, Equatable {
  private let rawValue: JSONObject

  init(from jsonObject: JSONObject) {
    self.rawValue = jsonObject
  }
}
