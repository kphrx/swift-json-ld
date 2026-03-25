// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A marker protocol for JSON-LD processing phases.
public protocol JSONLDPhase: Sendable {
  /// The placeholder type used for unknown content in this phase.
  associatedtype UnknownContent: Equatable
}

/// The phase representing raw, unresolved JSON-LD input.
public enum Unresolved: JSONLDPhase {
  /// The unknown content type used by unresolved JSON-LD.
  public typealias UnknownContent = [String: SingleOrMany<JSONLDValue<Unresolved>>]

  /// Creates unknown content from a JSON object.
  public static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  {
    try jsonObject.mapValuesWithTypedThrows { jsonValue throws(JSONLDError) in
      try .init(from: jsonValue, mapper: JSONLDValue<Unresolved>.init(from:))
    }
  }
}

/// The phase representing expanded JSON-LD values.
public enum Expanded: JSONLDPhase {
  /// A placeholder type indicating expanded JSON-LD does not allow unknown content.
  public enum UnknownContent: Equatable, Sendable {}
}

/// The phase representing flattened JSON-LD values.
public enum Flattened: JSONLDPhase {
  /// A placeholder type indicating flattened JSON-LD does not allow unknown content.
  public enum UnknownContent: Equatable, Sendable {}
}

/// The phase representing compacted JSON-LD values.
public enum Compacted: JSONLDPhase {
  /// A placeholder type indicating compacted JSON-LD does not allow unknown content.
  public enum UnknownContent: Equatable, Sendable {}
}
