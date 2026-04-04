// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A structure representing a collection of JSON-LD values.
public struct JSONLDValues<P: JSONLDPhase>: Equatable, CustomJSONValueConvertible {
  let value: SingleOrMany<JSONLDValue<P>>

  init(_ value: SingleOrMany<JSONLDValue<P>>) {
    self.value = value
  }

  /// Returns these values as a JSON value.
  public var jsonValue: JSONValue {
    self.value.jsonValue
  }
}

extension JSONLDValues where P == Unresolved {
  init(validating jsonValue: JSONValue) throws(JSONLDError) {
    self.init(
      try .init(from: jsonValue, mapper: JSONLDValue<P>.init(from:))
    )
  }
}

extension JSONLDValues: Decodable where P == Unresolved {
  /// Initializes values from a decoder.
  ///
  /// This initializer is only available for the `Unresolved` phase.
  public init(from decoder: any Decoder) throws {
    let jsonValue = try JSONValue(from: decoder)
    try self.init(validating: jsonValue)
  }
}

extension JSONLDValues where P == Unresolved {
  /// Creates unresolved values from a JSON value.
  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    try self.init(validating: jsonValue)
  }
}

extension JSONLDValues where P == Expanded {
  /// Normalizes expanded values into a JSON-LD document.
  public func asDocument(documentURL: String? = nil) -> JSONLDDocument<Expanded> {
    let nodes = self.value.compactMap { value -> [JSONLDValue<Expanded>.NodeObject]? in
      guard case .node(let node) = value else { return nil }

      if let graph = node.graph,
        node.context == nil,
        node.id == nil,
        node.type == nil,
        node.reverse == nil,
        node.index == nil,
        node.properties.isEmpty
      {
        return graph.compactMap {
          if case .node(let node) = $0 { node } else { nil }
        }
      }

      return [node]
    }.flatMap { $0 }

    return .init(.many(nodes), documentURL: documentURL)
  }
}
