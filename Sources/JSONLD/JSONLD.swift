// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

@_exported import JSONCodable

public struct JSONLDDocument: JSONLDValueProtocol, Equatable, Decodable {
  public let value: SingleOrMany<NodeObject>

  public init(_ value: SingleOrMany<NodeObject>) {
    self.value = value
  }

  public var jsonValue: JSONValue {
    self.value.jsonValue
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self.init(try .init(from: jsonValue))
  }

  public init(from decoder: Decoder) throws {
    try self.init(from: JSONValue(from: decoder))
  }

  public func expand(
    expandContext: JSONLDDocument? = nil,
    baseIRI: String? = nil,
    normative: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument {
    _ = (expandContext, baseIRI, normative)
    return self
  }

  public func compact(
    context: JSONLDDocument,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument {
    _ = (context, baseIRI, compactArrays, compactToRelative)
    return self
  }

  public func flatten(
    context: JSONLDDocument? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument {
    _ = (context, baseIRI, compactArrays)
    return self
  }
}

public struct JSONLDValues: JSONLDValueProtocol, Equatable, Decodable {
  let value: SingleOrMany<JSONLDValue>

  init(_ value: SingleOrMany<JSONLDValue>) {
    self.value = value
  }

  public var jsonValue: JSONValue {
    self.value.jsonValue
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self.init(try .init(from: jsonValue))
  }

  public init(from decoder: Decoder) throws {
    try self.init(from: JSONValue(from: decoder))
  }

  public func expand(
    expandContext: JSONLDDocument? = nil,
    baseIRI: String? = nil,
    normative: Bool = true
  ) throws(JSONLDError) -> JSONLDValues {
    _ = (expandContext, baseIRI, normative)
    return self
  }

  public func compact(
    context: JSONLDDocument,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) throws(JSONLDError) -> JSONLDValues {
    _ = (context, baseIRI, compactArrays, compactToRelative)
    return self
  }

  public func flatten(
    context: JSONLDDocument? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) throws(JSONLDError) -> JSONLDValues {
    _ = (context, baseIRI, compactArrays)
    return self
  }
}
