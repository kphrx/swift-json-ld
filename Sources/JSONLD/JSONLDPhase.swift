// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public protocol JSONLDPhase: Sendable {
  associatedtype UnknownContent: Equatable

  static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
}

public enum Unresolved: JSONLDPhase {
  public typealias UnknownContent = [String: SingleOrMany<JSONLDValue<Unresolved>>]

  public static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  {
    try jsonObject.mapValuesWithTypedThrows(SingleOrMany.init)
  }
}

public enum Expanded: JSONLDPhase {
  // Directly define the associated type as an uninhabited enum.
  public enum UnknownContent: Equatable, Sendable {}

  public static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  {
    nil
  }
}
