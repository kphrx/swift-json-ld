// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public enum JSONLDValue<P: JSONLDPhase>: JSONLDValueProtocol, Equatable {
  case node(NodeObject<P>)
  case value(ValueObject<P>)
  case setOrList(SetOrListObject<P>)
  case languageMap(LanguageMap<P>)
  case indexMap(IndexMap<P>)
  case iriOrTerm(String)
  case unknown(P.UnknownContent)
  case invalid(InvalidValue)

  public enum InvalidValue: Equatable {
    case listOfLists
    case notJSONLDValue
  }

  public var jsonValue: JSONValue {
    switch self {
    case .node(let nodeObject): nodeObject.jsonValue
    case .value(let valueObject): valueObject.jsonValue
    case .setOrList(let setOrListObject): setOrListObject.jsonValue
    case .languageMap(let languageMap): languageMap.jsonValue
    case .indexMap(let indexMap): indexMap.jsonValue
    case .iriOrTerm(let value): .string(value)
    case .unknown(let content):
      if let rawObject = content as? JSONObject {
        .object(rawObject)
      } else if let unresolvedObject = content as? [String: SingleOrMany<JSONLDValue<Unresolved>>] {
        .object(unresolvedObject.jsonObject)
      } else {
        .null
      }
    case .invalid: .null
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let string):
      self = .iriOrTerm(string)
    case .object(let jsonObject):
      if jsonObject.contains(.value) {
        self = .value(try .init(from: jsonObject))
      } else if jsonObject.contains(.list) || jsonObject.contains(.set) {
        do {
          self = .setOrList(try .init(from: jsonObject))
        } catch .code(.listOfLists) {
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
    default: self = .invalid(.notJSONLDValue)
    }
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
