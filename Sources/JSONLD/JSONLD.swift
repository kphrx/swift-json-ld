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

  public func expand(
    expandContext: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    normative: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument<Expanded> {
    let unresolvedValues = try self.value.map { node throws(JSONLDError) in
      try JSONLDValue<Unresolved>(from: .object(node.jsonObject))
    }

    return try JSONLDValues<Unresolved>(.many(unresolvedValues)).expand(
      expandContext: expandContext,
      baseIRI: baseIRI,
      normative: normative
    )
  }

  public func flatten(
    context: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument<P> {
    _ = (context, baseIRI, compactArrays)
    return self
  }

  public func compact(
    context: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument<P> {
    _ = (context, baseIRI, compactArrays, compactToRelative)
    return self
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
    var activeContext = ActiveContext.empty
    if let baseIRI {
      activeContext.baseIRI = baseIRI
    }

    if let expandContext {
      activeContext = try activeContext.process(
        localContext: try .init(from: expandContext.jsonValue))
    }

    let unresolvedValues = try self.value.map { val throws(JSONLDError) in
      try JSONLDValue<Unresolved>(from: val.jsonValue)
    }

    let expanded = try ExpansionProcessor.expand(
      activeContext,
      value: .many(unresolvedValues),
      property: nil
    )

    let nodes = expanded.compactMap { item in
      if case .node(let node) = item {
        node
      } else {
        nil
      }
    }

    return .init(.init(nodes))
  }

  public func flatten(
    context: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) throws(JSONLDError) -> JSONLDValues<P> {
    _ = (context, baseIRI, compactArrays)
    return self
  }

  public func compact(
    context: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) throws(JSONLDError) -> JSONLDValues<P> {
    _ = (context, baseIRI, compactArrays, compactToRelative)
    return self
  }
}

extension JSONLDValue {
  init(_ value: SetValue<P>) {
    self =
      switch value {
      case .string(let s): .iriOrTerm(s)
      case .integer(let i): .value(try! .init(from: .object(["@value": .integer(i)])))
      case .float(let f): .value(try! .init(from: .object(["@value": .float(f)])))
      case .boolean(let b): .value(try! .init(from: .object(["@value": .boolean(b)])))
      case .null: .invalid(.notJSONLDValue)
      case .nodeObject(let n): .node(n)
      case .valueObject(let v): .value(v)
      }
  }

  init(_ value: IndexValue<P>) {
    self =
      switch value {
      case .string(let s): .iriOrTerm(s)
      case .integer(let i): .value(try! .init(from: .object(["@value": .integer(i)])))
      case .float(let f): .value(try! .init(from: .object(["@value": .float(f)])))
      case .boolean(let b): .value(try! .init(from: .object(["@value": .boolean(b)])))
      case .null: .invalid(.notJSONLDValue)
      case .nodeObject(let n): .node(n)
      case .valueObject(let v): .value(v)
      case .setOrListObject(let s): .setOrList(s)
      }
  }
}
