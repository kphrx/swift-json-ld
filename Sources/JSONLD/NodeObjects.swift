// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public indirect enum NodeObjects: JSONLDObjectProtocol, JSONLDArrayProtocol, Equatable {
  case single(NodeObject)
  case array([NodeObject])

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    self = .single(try .init(from: jsonObject))
  }

  init(from jsonArray: JSONArray) throws(JSONLDError) {
    self = .array(try jsonArray.map(NodeObject.init(from:)))
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .object(let jsonObject): try self.init(from: jsonObject)
    case .array(let jsonArray): try self.init(from: jsonArray)
    default: throw .notObject
    }
  }
}

enum NodeTypes: JSONLDValueProtocol, JSONLDArrayProtocol, Equatable {
  case single(String)
  case array([String])

  init(from jsonArray: JSONArray) throws(JSONLDError) {
    self = .array(
      try jsonArray.map { jsonValue throws(JSONLDError) in
        if case .string(let value) = jsonValue {
          value
        } else {
          throw .invalidNodeType
        }
      })
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let value): self = .single(value)
    case .array(let jsonArray): self = try .init(from: jsonArray)
    default: throw .invalidNodeType
    }
  }
}

public struct NodeObject: JSONLDObjectProtocol, Equatable {
  let context: Contexts?
  let id: String?
  let graph: NodeObjects?
  let type: NodeTypes?
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
      try .init(from: typeValue)
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
