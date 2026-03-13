// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONLDValue {
  /// A *node object* in JSON-LD.
  public struct NodeObject: JSONLDObjectProtocol, Equatable {
    let context: Contexts?
    let id: String?
    let graph: SingleOrMany<JSONLDValue<P>>?
    let type: SingleOrMany<String>?
    let reverse: ReversePropertyMap<P>?
    let index: String?
    let properties: [String: SingleOrMany<JSONLDValue<P>>]
  }
}

extension JSONLDValue.NodeObject {
  /// Returns this node object as a JSON object.
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

  /// Creates a node object from a JSON object.
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

    self.id =
      switch properties.removeValue(for: .id) {
      case .string(let value)?: value
      case nil: nil
      case _?: throw .code(.invalidIdValue)
      }

    self.graph = try properties.removeValue(for: .graph).map { graphValue throws(JSONLDError) in
      switch graphValue {
      case .object(let obj):
        return .single(try .init(from: .object(obj)))
      case .array(let arr):
        let values = try arr.map(JSONLDValue.init(from:))
        return values.isEmpty ? nil : .many(values)
      case .null:
        return nil
      default:
        throw .internalError(.notObject)
      }
    }.flatMap { $0 }

    self.type =
      switch properties.removeValue(for: .type) {
      case let typeValue?:
        try .init(from: typeValue) { jsonValue throws(JSONLDError) in
          if case .string(let value) = jsonValue {
            value
          } else {
            throw .code(.invalidTypeValue)
          }
        }
      case nil:
        nil
      }

    self.reverse =
      switch properties.removeValue(for: .reverse) {
      case .object(let value)?: try .init(from: value)
      case nil: nil
      case _?: throw .code(.invalidReverseValue)
      }

    self.index = try properties.extractIndex()

    self.properties = try properties.mapValuesWithTypedThrows(SingleOrMany.init(from:))
  }
}
