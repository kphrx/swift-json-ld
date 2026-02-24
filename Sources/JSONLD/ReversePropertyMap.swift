// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

struct ReversePropertyMap: JSONLDObjectProtocol, Equatable {
  let map: [String: SingleOrMany<NodeObject>]

  var jsonObject: JSONObject {
    self.map.jsonObject
  }

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var map: [String: SingleOrMany<NodeObject>] = [:]

    for (key, value) in jsonObject {
      if key.hasPrefix("@") {
        throw .code(.invalidReversePropertyMap)
      }

      switch value {
      case .object(let object):
        if object.contains(.value)
          || object.contains(.list)
        {
          throw .code(.invalidReversePropertyValue)
        }
        map[key] = try .init(from: value)
      case .array(let array):
        var nodes: [NodeObject] = []
        nodes.reserveCapacity(array.count)
        for element in array {
          if case .object(let object) = element {
            if object.contains(.value)
              || object.contains(.list)
            {
              throw .code(.invalidReversePropertyValue)
            }
            nodes.append(try .init(from: element))
          } else {
            throw .code(.invalidReversePropertyValue)
          }
        }
        map[key] = .many(nodes)
      default:
        throw .code(.invalidReversePropertyValue)
      }
    }

    self.map = map
  }
}
