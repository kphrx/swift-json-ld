// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A structure representing a collection of JSON-LD values.
public struct JSONLDValues<P: JSONLDPhase>: JSONLDValueProtocol, Equatable {
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
}

extension JSONLDValues: Decodable where P == Unresolved {
  /// Initializes values from a decoder.
  ///
  /// This initializer is only available for the `Unresolved` phase.
  public init(from decoder: Decoder) throws {
    let jsonValue = try JSONValue(from: decoder)
    try self.init(from: jsonValue)
  }
}
