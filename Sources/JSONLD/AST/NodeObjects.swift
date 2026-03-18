// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONLDValue {
  /// A *node object* in JSON-LD.
  public struct NodeObject: JSONLDObjectProtocol, Equatable {
    typealias ContextEntry = (term: String?, value: Contexts)
    typealias IdEntry = (term: String?, value: String)
    typealias GraphEntry = (term: String?, value: SingleOrMany<JSONLDValue<P>>)
    typealias TypeEntry = (term: String?, value: SingleOrMany<String>)
    typealias ReverseEntry = (term: String?, value: ReversePropertyMap<P>)
    typealias IndexEntry = (term: String?, value: String)

    let contextEntry: ContextEntry?
    let idEntry: IdEntry?
    let graphEntry: GraphEntry?
    let typeEntry: TypeEntry?
    let reverseEntry: ReverseEntry?
    let indexEntry: IndexEntry?
    let properties: [String: SingleOrMany<JSONLDValue<P>>]
  }
}

extension JSONLDValue.NodeObject {
  var context: Contexts? {
    self.contextEntry?.value
  }

  var id: String? {
    self.idEntry?.value
  }

  var graph: SingleOrMany<JSONLDValue<P>>? {
    self.graphEntry?.value
  }

  var type: SingleOrMany<String>? {
    self.typeEntry?.value
  }

  var reverse: ReversePropertyMap<P>? {
    self.reverseEntry?.value
  }

  var index: String? {
    self.indexEntry?.value
  }

  /// Returns this node object as a JSON object.
  public var jsonObject: JSONObject {
    var jsonObject = self.properties.jsonObject

    if let contextEntry = self.contextEntry {
      jsonObject.set(contextEntry.value, for: .context, term: contextEntry.term)
    }

    if let idEntry = self.idEntry {
      jsonObject.set(idEntry.value, for: .id, term: idEntry.term)
    }

    if let graphEntry = self.graphEntry {
      jsonObject.set(graphEntry.value, for: .graph, term: graphEntry.term)
    }

    if let typeEntry = self.typeEntry {
      jsonObject.set(typeEntry.value, for: .type, term: typeEntry.term)
    }

    if let reverseEntry = self.reverseEntry {
      jsonObject.set(reverseEntry.value, for: .reverse, term: reverseEntry.term)
    }

    if let indexEntry = self.indexEntry {
      jsonObject.set(indexEntry.value, for: .index, term: indexEntry.term)
    }

    return jsonObject
  }

  init(
    context: ContextEntry? = nil,
    id: IdEntry? = nil,
    graph: GraphEntry? = nil,
    type: TypeEntry? = nil,
    reverse: ReverseEntry? = nil,
    index: IndexEntry? = nil,
    properties: [String: SingleOrMany<JSONLDValue<P>>] = [:]
  ) {
    self.contextEntry = context
    self.idEntry = id
    self.graphEntry = graph
    self.typeEntry = type
    self.reverseEntry = reverse
    self.indexEntry = index
    self.properties = properties
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

    self.contextEntry = try properties.extractContext().map { (term: nil, value: $0) }

    self.idEntry =
      switch properties.removeValue(for: .id) {
      case .string(let value)?: (term: nil, value: value)
      case nil: nil
      case _?: throw .code(.invalidIdValue)
      }

    self.graphEntry = try properties.removeValue(for: .graph).map {
      graphValue throws(JSONLDError) -> GraphEntry? in
      let graph: SingleOrMany<JSONLDValue<P>>?
      switch graphValue {
      case .object(let obj):
        graph = .single(try .init(from: .object(obj)))
      case .array(let arr):
        let values = try arr.map(JSONLDValue.init(from:))
        graph = values.isEmpty ? nil : .many(values)
      case .null:
        graph = nil
      default:
        throw .internalError(.notObject)
      }
      return graph.map { (term: nil, value: $0) }
    }.flatMap { $0 }

    self.typeEntry =
      switch properties.removeValue(for: .type) {
      case let typeValue?:
        (
          term: nil,
          value: try .init(from: typeValue) { jsonValue throws(JSONLDError) in
            if case .string(let value) = jsonValue {
              value
            } else {
              throw .code(.invalidTypeValue)
            }
          }
        )
      case nil:
        nil
      }

    self.reverseEntry =
      switch properties.removeValue(for: .reverse) {
      case .object(let value)?: (term: nil, value: try .init(from: value))
      case nil: nil
      case _?: throw .code(.invalidReverseValue)
      }

    self.indexEntry = try properties.extractIndex().map { (term: nil, value: $0) }

    self.properties = try properties.mapValuesWithTypedThrows(SingleOrMany.init(from:))
  }
}

extension JSONLDValue.NodeObject {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.contextEntry?.term == rhs.contextEntry?.term
      && lhs.contextEntry?.value == rhs.contextEntry?.value
      && lhs.idEntry?.term == rhs.idEntry?.term
      && lhs.idEntry?.value == rhs.idEntry?.value
      && lhs.graphEntry?.term == rhs.graphEntry?.term
      && lhs.graphEntry?.value == rhs.graphEntry?.value
      && lhs.typeEntry?.term == rhs.typeEntry?.term
      && lhs.typeEntry?.value == rhs.typeEntry?.value
      && lhs.reverseEntry?.term == rhs.reverseEntry?.term
      && lhs.reverseEntry?.value == rhs.reverseEntry?.value
      && lhs.indexEntry?.term == rhs.indexEntry?.term
      && lhs.indexEntry?.value == rhs.indexEntry?.value
      && lhs.properties == rhs.properties
  }
}
