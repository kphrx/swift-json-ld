// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

@_exported import JSONCodable

public struct JSONLDDocument<P: JSONLDPhase>: JSONLDValueProtocol, Equatable, Decodable {
  let value: SingleOrMany<NodeObject<P>>

  public init(_ value: SingleOrMany<NodeObject<P>>) {
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
}

public struct JSONLDValues<P: JSONLDPhase>: JSONLDValueProtocol, Equatable, Decodable {
  let value: SingleOrMany<JSONLDValue<P>>

  init(_ value: SingleOrMany<JSONLDValue<P>>) {
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
    expandContext: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    normative: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument<Expanded> {
    _ = (expandContext, baseIRI, normative)
    return try .init(from: self.jsonValue)
  }

  public func flatten(
    context: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument<Unresolved> {
    _ = (context, baseIRI, compactArrays)
    return try .init(from: self.jsonValue)
  }

  public func compact(
    context: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) throws(JSONLDError) -> JSONLDValues<Unresolved> {
    _ = (context, baseIRI, compactArrays, compactToRelative)
    // Stub implementation returning self (cast needed if P != Unresolved)
    // For now assume P == Unresolved for stub
    if let selfUnresolved = self as? JSONLDValues<Unresolved> {
      return selfUnresolved
    }
    return try .init(from: self.jsonValue)
  }
}
