// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public indirect enum JSONLDValue<P: JSONLDPhase>: JSONLDValueProtocol, Equatable {
  case iriOrTerm(String)
  case node(NodeObject<P>)
  case value(ValueObject<P>)
  case setOrList(SetOrListObject<P>)
  case languageMap(LanguageMap<P>)
  case indexMap(IndexMap<P>)
  case unknown(P.UnknownContent)
  case invalid(InvalidValue)

  public enum InvalidValue: Equatable {
    case notJSONLDValue
    case listOfLists

    public var jsonValue: JSONValue {
      .null
    }
  }

  public var jsonValue: JSONValue {
    switch self {
    case .iriOrTerm(let value): .string(value)
    case .node(let node): node.jsonValue
    case .value(let value): value.jsonValue
    case .setOrList(let object): object.jsonValue
    case .languageMap(let languageMap): languageMap.jsonValue
    case .indexMap(let indexMap): indexMap.jsonValue
    case .unknown(let content):
      if let jsonObject = content as? [String: SingleOrMany<JSONLDValue<Unresolved>>] {
        .object(jsonObject.mapValues(\.jsonValue))
      } else {
        .null
      }
    case .invalid(let invalid): invalid.jsonValue
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let string):
      self = .iriOrTerm(string)
    case .object(let jsonObject):
      if jsonObject[.value] != nil {
        self = .value(try .init(from: jsonObject))
      } else if jsonObject[.set] != nil || jsonObject[.list] != nil {
        do {
          self = .setOrList(try .init(from: jsonObject))
        } catch let jsonldError {
          if case .code(.listOfLists) = jsonldError {
            self = .invalid(.listOfLists)
          } else {
            throw jsonldError
          }
        }
      } else if jsonObject[.id] != nil
        || jsonObject[.type] != nil
        || jsonObject[.graph] != nil
        || jsonObject[.reverse] != nil
        || jsonObject[.context] != nil
        || jsonObject[.index] != nil
      {
        self = .node(try .init(from: jsonObject))
      } else if !jsonObject.keys.contains(where: { $0.hasPrefix("@") }) {
        self = .node(try .init(from: jsonObject))
      } else if P.self == Unresolved.self {
        let content = try jsonObject.mapValuesWithTypedThrows(
          SingleOrMany<JSONLDValue<Unresolved>>.init(from:))
        if let content = content as? P.UnknownContent {
          self = .unknown(content)
        } else {
          self = .invalid(.notJSONLDValue)
        }
      } else {
        self = .invalid(.notJSONLDValue)
      }
    default: self = .invalid(.notJSONLDValue)
    }
  }
}
