// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

struct ReversePropertyMap<P: JSONLDPhase>: CustomJSONObjectConvertible, Equatable {
  let map: [String: SingleOrMany<P.ReversePropertyValue>]

  var jsonObject: JSONObject {
    self.map.jsonObject
  }

  init(map: [String: SingleOrMany<P.ReversePropertyValue>]) {
    self.map = map
  }

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var map: [String: SingleOrMany<P.ReversePropertyValue>] = [:]

    for (key, value) in jsonObject {
      if key.hasPrefix("@") {
        throw .code(.invalidReversePropertyMap)
      }
      map[key] = try .init(from: value, mapper: P.reversePropertyValue(from:))
    }

    self.map = map
  }
}
