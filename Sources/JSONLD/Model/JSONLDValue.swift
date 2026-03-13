// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A JSON-LD value that is parameterized by processing phase.
public enum JSONLDValue<P: JSONLDPhase>: JSONLDValueProtocol, Equatable {
  case node(NodeObject)
  case value(ValueObject)
  case setOrList(SetOrListObject)
  case languageMap(LanguageMap)
  case indexMap(IndexMap)
  case iriOrTerm(String)
  case integer(Int)
  case float(Double)
  case boolean(Bool)
  case null
  case unknown(P.UnknownContent)
  case invalid(InvalidValue)

  /// A JSON-LD value that is structurally invalid in the current phase.
  public enum InvalidValue: Equatable {
    case listOfLists
    case notJSONLDValue
  }

  /// Returns this value as a JSON value.
  public var jsonValue: JSONValue {
    switch self {
    case .node(let nodeObject): nodeObject.jsonValue
    case .value(let valueObject): valueObject.jsonValue
    case .setOrList(let setOrListObject): setOrListObject.jsonValue
    case .languageMap(let languageMap): languageMap.jsonValue
    case .indexMap(let indexMap): indexMap.jsonValue
    case .iriOrTerm(let value): .string(value)
    case .integer(let value): .integer(value)
    case .float(let value): .float(value)
    case .boolean(let value): .boolean(value)
    case .null: .null
    case .unknown(let content):
      if let unresolvedObject = content as? [String: SingleOrMany<JSONLDValue<Unresolved>>] {
        .object(unresolvedObject.jsonObject)
      } else {
        .null
      }
    case .invalid: .null
    }
  }

  /// Creates a JSON-LD value from a JSON value.
  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let string):
      self = .iriOrTerm(string)
    case .integer(let integer):
      self = .integer(integer)
    case .float(let float):
      self = .float(float)
    case .boolean(let boolean):
      self = .boolean(boolean)
    case .null:
      self = .null
    case .array:
      self = .invalid(.notJSONLDValue)
    case .object(let jsonObject):
      if jsonObject.contains(.value) {
        self = .value(try .init(from: jsonObject))
      } else if jsonObject.contains(.list) || jsonObject.contains(.set) {
        do {
          self = .setOrList(try .init(from: jsonObject))
        } catch let error where error.kind == .code(.listOfLists) {
          self = .invalid(.listOfLists)
        }
      } else if !jsonObject.keys.contains(where: { $0.hasPrefix("@") })
        || jsonObject.contains(.id)
        || jsonObject.contains(.type)
        || jsonObject.contains(.graph)
        || jsonObject.contains(.reverse)
        || jsonObject.contains(.context)
        || jsonObject.contains(.index)
      {
        self = .node(try .init(from: jsonObject))
      } else if let content = try P.makeUnknown(from: jsonObject) {
        self = .unknown(content)
      } else {
        self = .invalid(.notJSONLDValue)
      }
    }
  }
}
