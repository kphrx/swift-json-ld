// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public enum Contexts: JSONLDValueProtocol, Equatable, Sendable {
  case null
  case single(Context)
  case array([Context])

  public var jsonValue: JSONValue {
    switch self {
    case .null: .null
    case .single(let context): context.jsonValue
    case .array(let contexts): contexts.jsonValue
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
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

extension Contexts: Decodable {
  public init(from decoder: Decoder) throws {
    let jsonValue = try JSONValue(from: decoder)
    try self.init(from: jsonValue)
  }
}

public enum Context: JSONLDValueProtocol, Equatable, Sendable {
  case absoluteIRI(String)
  case relativeIRI(String)
  case contextDefinition(ContextDefinition)

  public var jsonValue: JSONValue {
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

  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    self = .contextDefinition(try .init(from: jsonObject))
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .object(let jsonObject): try .init(from: jsonObject)
      case .string(let value): try .init(iri: value)
      default: throw .code(.invalidLocalContext)
      }
  }
}
