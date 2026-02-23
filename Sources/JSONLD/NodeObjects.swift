// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public struct NodeObject: JSONLDObjectProtocol, Equatable {
  let context: Contexts?
  let id: String?
  let graph: SingleOrMany<NodeObject>?
  let type: SingleOrMany<String>?
  let reverse: ReversePropertyMap?
  let index: String?
  let properties: JSONObject

  public var jsonObject: JSONObject {
    var jsonObject: JSONObject = self.properties

    if let id = self.id {
      jsonObject["@id"] = .string(id)
    }

    switch self.graph {
    case .some(.single(let graph)): jsonObject["@graph"] = graph.jsonValue
    case .some(.many(let graph)): jsonObject["@graph"] = .array(graph.map { $0.jsonValue })
    case .none: break
    }

    switch self.type {
    case .some(.single(let type)): jsonObject["@type"] = .string(type)
    case .some(.many(let type)): jsonObject["@type"] = .array(type.map { .string($0) })
    case .none: break
    }

    if let reverse = self.reverse {
      jsonObject["@reverse"] = reverse.jsonValue
    }

    if let index = self.index {
      jsonObject["@index"] = .string(index)
    }

    return jsonObject
  }

  init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject

    self.context = try properties.extractContext()

    self.id = try properties.removeValue(forKey: "@id").map { idValue throws(JSONLDError) in
      if case .string(let value) = idValue {
        value
      } else {
        throw .code(.invalidIdValue)
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
            throw .code(.invalidTypeValue)
          }
        })
    }

    self.reverse = try properties.removeValue(forKey: "@reverse").map {
      reverseValue throws(JSONLDError) in
      if case .object(let value) = reverseValue {
        try .init(from: value)
      } else {
        throw .code(.invalidReverseValue)
      }
    }

    self.index = try properties.extractIndex()

    if properties.keys.contains("@value") || properties.keys.contains("@language") {
      throw .internalError(.notNodeObject)
    }

    if properties.keys.contains("@list") || properties.keys.contains("@set") {
      throw .internalError(.notNodeObject)
    }

    self.properties = properties
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    if case .object(let jsonObject) = jsonValue {
      try self.init(from: jsonObject)
    } else {
      throw .internalError(.notObject)
    }
  }
}
