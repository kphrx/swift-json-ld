// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A marker protocol for JSON-LD processing phases.
public protocol JSONLDPhase: Sendable {
  /// The placeholder type used for unknown content in this phase.
  associatedtype UnknownContent: Equatable
  /// The allowed value type for `@reverse` in this phase.
  associatedtype ReversePropertyValue: JSONLDValueProtocol & Equatable

  /// Creates unknown content from a JSON object if the phase allows it.
  static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  /// Creates a reverse property value from a JSON value.
  static func reversePropertyValue(
    from jsonValue: JSONValue
  ) throws(JSONLDError) -> ReversePropertyValue
}

/// The phase representing raw, unresolved JSON-LD input.
public enum Unresolved: JSONLDPhase {
  /// The unknown content type used by unresolved JSON-LD.
  public typealias UnknownContent = [String: SingleOrMany<JSONLDValue<Unresolved>>]
  /// The reverse property value type for unresolved JSON-LD.
  public typealias ReversePropertyValue = JSONLDValue<Unresolved>

  /// Creates unknown content from a JSON object.
  public static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  {
    try jsonObject.mapValuesWithTypedThrows(SingleOrMany.init)
  }

  /// Creates a reverse property value from a JSON value.
  public static func reversePropertyValue(
    from jsonValue: JSONValue
  ) throws(JSONLDError) -> ReversePropertyValue {
    try .init(from: jsonValue)
  }
}

/// The phase representing expanded JSON-LD values.
public enum Expanded: JSONLDPhase {
  /// A placeholder type indicating expanded JSON-LD does not allow unknown content.
  public enum UnknownContent: Equatable, Sendable {}
  /// The reverse property value type for expanded JSON-LD.
  public typealias ReversePropertyValue = JSONLDValue<Expanded>.NodeObject

  /// Returns `nil` because expanded JSON-LD does not allow unknown content.
  public static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  {
    nil
  }

  /// Creates a reverse property value from a JSON value.
  public static func reversePropertyValue(
    from jsonValue: JSONValue
  ) throws(JSONLDError) -> ReversePropertyValue {
    if case .object(let object) = jsonValue {
      if object.contains(.value) || object.contains(.list) {
        throw .code(.invalidReversePropertyValue)
      }
      return try .init(from: object)
    } else {
      throw .code(.invalidReversePropertyValue)
    }
  }
}

/// The phase representing flattened JSON-LD values.
public enum Flattened: JSONLDPhase {
  /// A placeholder type indicating flattened JSON-LD does not allow unknown content.
  public enum UnknownContent: Equatable, Sendable {}
  /// The reverse property value type for flattened JSON-LD.
  public typealias ReversePropertyValue = JSONLDValue<Flattened>

  /// Returns `nil` because flattened JSON-LD does not allow unknown content.
  public static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  {
    nil
  }

  /// Creates a reverse property value from a JSON value.
  public static func reversePropertyValue(
    from jsonValue: JSONValue
  ) throws(JSONLDError) -> ReversePropertyValue {
    try .init(from: jsonValue)
  }
}

/// The phase representing compacted JSON-LD values.
public enum Compacted: JSONLDPhase {
  /// A placeholder type indicating compacted JSON-LD does not allow unknown content.
  public enum UnknownContent: Equatable, Sendable {}
  /// The reverse property value type for compacted JSON-LD.
  public typealias ReversePropertyValue = JSONLDValue<Compacted>

  /// Returns `nil` because compacted JSON-LD does not allow unknown content.
  public static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  {
    nil
  }

  /// Creates a reverse property value from a JSON value.
  public static func reversePropertyValue(
    from jsonValue: JSONValue
  ) throws(JSONLDError) -> ReversePropertyValue {
    try .init(from: jsonValue)
  }
}
