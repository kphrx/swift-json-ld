// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public protocol JSONLDPhase: Sendable {
  associatedtype UnknownContent: Equatable
  associatedtype ReversePropertyValue: JSONLDValueProtocol & Equatable

  static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  static func reversePropertyValue(from jsonValue: JSONValue) throws(JSONLDError)
    -> ReversePropertyValue
}

public enum Unresolved: JSONLDPhase {
  public typealias UnknownContent = [String: SingleOrMany<JSONLDValue<Unresolved>>]
  public typealias ReversePropertyValue = JSONLDValue<Unresolved>

  public static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  {
    try jsonObject.mapValuesWithTypedThrows(SingleOrMany.init)
  }

  public static func reversePropertyValue(from jsonValue: JSONValue) throws(JSONLDError)
    -> ReversePropertyValue
  {
    try .init(from: jsonValue)
  }
}

public enum Expanded: JSONLDPhase {
  // Directly define the associated type as an uninhabited enum.
  public enum UnknownContent: Equatable, Sendable {}
  public typealias ReversePropertyValue = NodeObject<Expanded>

  public static func makeUnknown(from jsonObject: JSONObject) throws(JSONLDError) -> UnknownContent?
  {
    nil
  }

  public static func reversePropertyValue(from jsonValue: JSONValue) throws(JSONLDError)
    -> ReversePropertyValue
  {
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
