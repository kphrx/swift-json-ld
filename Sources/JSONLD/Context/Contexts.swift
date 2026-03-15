// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A JSON-LD `@context` value.
public enum Contexts: JSONLDValueProtocol, Equatable, Sendable {
  case null
  case single(Element)
  case array([Element])
}

extension Contexts {
  /// Returns this context as a JSON value.
  public var jsonValue: JSONValue {
    switch self {
    case .null: .null
    case .single(let context): context.jsonValue
    case .array(let contexts): contexts.jsonValue
    }
  }

  /// Creates a context from a JSON value.
  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      if case .null = jsonValue {
        .null
      } else {
        switch try SingleOrMany<Element>(from: jsonValue) {
        case .single(let context): .single(context)
        case .many(let contexts): .array(contexts)
        }
      }
  }
}

extension Contexts: Decodable {
  /// Creates a context from a decoder.
  public init(from decoder: Decoder) throws {
    let jsonValue = try JSONValue(from: decoder)
    try self.init(from: jsonValue)
  }
}

extension Contexts: ExpressibleByNilLiteral {
  /// Creates a `null` context literal.
  public init(nilLiteral: ()) {
    self = .null
  }
}

extension Contexts: ExpressibleByStringLiteral {
  /// Creates a context literal from an IRI string.
  public init(stringLiteral value: String) {
    do {
      self = .single(try .init(iri: value))
    } catch {
      preconditionFailure("Invalid @context literal: \(error)")
    }
  }
}

extension Contexts: ExpressibleByArrayLiteral {
  /// Creates a context literal from an array of context elements.
  public init(arrayLiteral elements: Contexts.Element...) {
    self = .array(elements)
  }
}

extension Contexts: ExpressibleByDictionaryLiteral {
  /// Creates a context literal from a context definition object.
  public init(dictionaryLiteral elements: (String, Contexts.ContextDefinition.Value)...) {
    self = .single(.fromLiteral(elements))
  }
}

extension Contexts {
  /// A single `@context` element.
  public enum Element: JSONLDValueProtocol, Equatable, Sendable {
    case absoluteIRI(String)
    case relativeIRI(String)
    case contextDefinition(ContextDefinition)
  }
}

extension Contexts.Element: ExpressibleByStringLiteral {
  /// Creates a context element literal from an IRI string.
  public init(stringLiteral value: String) {
    do {
      try self.init(iri: value)
    } catch {
      preconditionFailure("Invalid @context literal: \(error)")
    }
  }
}

extension Contexts.Element: ExpressibleByDictionaryLiteral {
  /// Creates a context element literal from a context definition object.
  public init(dictionaryLiteral elements: (String, Contexts.ContextDefinition.Value)...) {
    self = .fromLiteral(elements)
  }
}

extension Contexts.Element {
  /// Returns this context element as a JSON value.
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

  /// Creates a context element from a JSON object.
  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    self = .contextDefinition(try .init(from: jsonObject))
  }

  /// Creates a context element from a JSON value.
  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .object(let jsonObject): try .init(from: jsonObject)
      case .string(let value): try .init(iri: value)
      default: throw .code(.invalidLocalContext)
      }
  }

  fileprivate static func fromLiteral(
    _ elements: [(String, Contexts.ContextDefinition.Value)]
  ) -> Self {
    var jsonObject: JSONObject = [:]
    for (key, value) in elements {
      jsonObject[key] = value.jsonValue
    }
    do {
      return .contextDefinition(try .init(from: jsonObject))
    } catch {
      preconditionFailure("Invalid @context literal: \\(error)")
    }
  }
}
