// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum LanguageMapValue: JSONLDValueProtocol, Equatable {
  case string(String)
  case null

  var jsonValue: JSONValue {
    switch self {
    case .string(let value): .string(value)
    case .null: .null
    }
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let value): self = .string(value)
    case .null: self = .null
    default: throw .code(.invalidLanguageMapValue)
    }
  }
}

struct LanguageMap: JSONLDObjectProtocol, Equatable {
  let map: [String: SingleOrMany<LanguageMapValue>]

  var jsonObject: JSONObject {
    self.map.jsonObject
  }

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    self.map = try jsonObject.mapValuesWithTypedThrows { jsonValue throws(JSONLDError) in
      try .init(from: jsonValue)
    }
  }
}
