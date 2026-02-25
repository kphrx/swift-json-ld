// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public enum LanguageMapValue: JSONLDValueProtocol, Equatable {
  case string(String)
  case null

  public var jsonValue: JSONValue {
    switch self {
    case .string(let value): .string(value)
    case .null: .null
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let value): self = .string(value)
    case .null: self = .null
    default: throw .code(.invalidLanguageMapValue)
    }
  }
}

public struct LanguageMap<P: JSONLDPhase>: JSONLDObjectProtocol, Equatable {
  let map: [String: SingleOrMany<LanguageMapValue>]

  public var jsonObject: JSONObject {
    self.map.jsonObject
  }

  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    self.map = try jsonObject.mapValuesWithTypedThrows { jsonValue throws(JSONLDError) in
      try .init(from: jsonValue)
    }
  }
}
