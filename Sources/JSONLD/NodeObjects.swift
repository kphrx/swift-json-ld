// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public struct NodeObject<P: JSONLDPhase>: JSONLDObjectProtocol, Equatable {
  let context: Contexts?
  let id: String?
  let graph: SingleOrMany<NodeObject<P>>?
  let type: SingleOrMany<String>?
  let reverse: ReversePropertyMap<P>?
  let index: String?
  let properties: [String: SingleOrMany<JSONLDValue<P>>]

  public var jsonObject: JSONObject {
    var jsonObject = self.properties.jsonObject

    if let context = self.context {
      jsonObject[.context] = context.jsonValue
    }

    if let id = self.id {
      jsonObject[.id] = .string(id)
    }

    if let graph = self.graph {
      jsonObject[.graph] = graph.jsonValue
    }

    if let type = self.type {
      jsonObject[.type] = type.jsonValue
    }

    if let reverse = self.reverse {
      jsonObject[.reverse] = reverse.jsonValue
    }

    if let index = self.index {
      jsonObject[.index] = .string(index)
    }

    return jsonObject
  }

  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    guard !jsonObject.contains(.value),
      !jsonObject.contains(.language),
      !jsonObject.contains(.list),
      !jsonObject.contains(.set)
    else {
      throw .internalError(.notNodeObject)
    }

    var properties = jsonObject

    self.context = try properties.extractContext()

    self.id = try properties.removeValue(for: .id).map { idValue throws(JSONLDError) in
      if case .string(let value) = idValue {
        value
      } else {
        throw .code(.invalidIdValue)
      }
    }

    self.graph = try properties.removeValue(for: .graph).map(SingleOrMany.init(from:))

    self.type = try properties.removeValue(for: .type).map { typeValue throws(JSONLDError) in
      try .init(from: typeValue) { jsonValue throws(JSONLDError) in
        if case .string(let value) = jsonValue {
          value
        } else {
          throw .code(.invalidTypeValue)
        }
      }
    }

    self.reverse = try properties.removeValue(for: .reverse).map {
      reverseValue throws(JSONLDError) in
      if case .object(let value) = reverseValue {
        try .init(from: value)
      } else {
        throw .code(.invalidReverseValue)
      }
    }

    self.index = try properties.extractIndex()

    self.properties = try properties.mapValuesWithTypedThrows(SingleOrMany.init(from:))
  }
}
