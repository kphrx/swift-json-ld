// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

struct LanguageMap: JSONLDObjectProtocol, Equatable {
  let map: [String: [String]]

  var jsonObject: JSONObject {
    self.map.jsonObject
  }

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    self.map = try jsonObject.mapValuesWithTypedThrows { jsonValue throws(JSONLDError) in
      switch jsonValue {
      case .string(let string): [string]
      case .array(let array):
        try array.map { value throws(JSONLDError) in
          if case .string(let string) = value {
            string
          } else {
            throw .invalidLanguageMapValue
          }
        }
      default: throw .invalidLanguageMapValue
      }
    }
  }
}
