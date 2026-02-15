// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public indirect enum NodeObjects {
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

enum NodeTypes {
  case single(String)
  case array([String])

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let value): self = .single(value)
    case .array(let jsonArray):
      self = .array(
        try jsonArray.map { jsonValue throws(JSONLDError) in
          if case .string(let value) = jsonValue {
            value
          } else {
            throw .invalidNodeType
          }
        })
    default: throw .invalidNodeType
    }
  }
}

public struct NodeObject {
  private let rawValue: JSONObject
  let context: Contexts?
  let id: String?
  let graph: NodeObjects?
  let type: NodeTypes?
  let reverse: JSONObject?
  let index: String?
  let properties: JSONObject

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    self.rawValue = jsonObject
    var properties = jsonObject
    self.context =
      if let context = properties.removeValue(forKey: "@context") {
        try .init(from: context)
      } else { nil }
    self.id =
      if let id = properties.removeValue(forKey: "@id") {
        if case .string(let value) = id {
          value
        } else {
          throw .invalidNodeID
        }
      } else { nil }
    self.graph =
      if let graph = properties.removeValue(forKey: "@graph") {
        try .init(from: graph)
      } else { nil }
    self.type =
      if let type = properties.removeValue(forKey: "@type") {
        try .init(from: type)
      } else { nil }
    self.reverse =
      if let reverse = properties.removeValue(forKey: "@reverse") {
        if case .object(let value) = reverse {
          value
        } else {
          throw .invalidReverse
        }
      } else { nil }
    self.index =
      if let index = properties.removeValue(forKey: "@index") {
        if case .string(let value) = index {
          value
        } else {
          throw .invalidNodeIndex
        }
      } else { nil }
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
