// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum Contexts: JSONLDValueProtocol, Equatable {
  case null
  case single(Context)
  case array([Context])

  var jsonValue: JSONValue {
    switch self {
    case .null: .null
    case .single(let context): context.jsonValue
    case .array(let contexts): contexts.jsonValue
    }
  }

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

enum Context: JSONLDValueProtocol, Equatable {
  case absoluteIRI(String)
  case relativeIRI(String)
  case contextDefinition(ContextDefinition)

  var jsonValue: JSONValue {
    switch self {
    case .absoluteIRI(let value), .relativeIRI(let value): .string(value)
    case .contextDefinition(let contextDefinition): contextDefinition.jsonValue
    }
  }

  init(iri value: String) throws(JSONLDError) {
    self =
      if value.contains(":") {
        .absoluteIRI(value)
      } else {
        .relativeIRI(value)
      }
  }

  init(from jsonObject: JSONObject) {
    self = .contextDefinition(.init(from: jsonObject))
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .object(let jsonObject): .init(from: jsonObject)
      case .string(let value): try .init(iri: value)
      default: throw .code(.invalidLocalContext)
      }
  }
}

struct ContextDefinition: JSONLDObjectProtocol, Equatable {
  let jsonObject: JSONObject

  init(from jsonObject: JSONObject) {
    self.jsonObject = jsonObject
  }
}
