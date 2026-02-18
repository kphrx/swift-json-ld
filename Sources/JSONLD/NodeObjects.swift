// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public struct NodeObject: JSONLDObjectProtocol, Equatable {
  let context: Contexts?
  let id: String?
  let graph: SingleOrMany<NodeObject>?
  let type: SingleOrMany<String>?
  let reverse: JSONObject?
  let index: String?
  let properties: JSONObject

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject

    self.context = try properties.extractContext()

    self.id = try properties.removeValue(forKey: "@id").map { idValue throws(JSONLDError) in
      if case .string(let value) = idValue {
        value
      } else {
        throw .invalidNodeID
      }
    }

    self.graph = try properties.removeValue(forKey: "@graph").map {
      graphValue throws(JSONLDError) in
      try .init(from: graphValue)
    }

    self.type = try properties.removeValue(forKey: "@type").map { typeValue throws(JSONLDError) in
      try .init(
        from: typeValue,
        mapper: { jsonValue throws(JSONLDError) in
          if case .string(let value) = jsonValue {
            value
          } else {
            throw .invalidNodeType
          }
        })
    }

    self.reverse = try properties.removeValue(forKey: "@reverse").map {
      reverseValue throws(JSONLDError) in
      if case .object(let value) = reverseValue {
        value
      } else {
        throw .invalidReverse
      }
    }

    self.index = try properties.extractIndex()

    self.properties = properties
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    if case .object(let jsonObject) = jsonValue {
      try self.init(from: jsonObject)
    } else {
      throw .notObject
    }
  }
}
