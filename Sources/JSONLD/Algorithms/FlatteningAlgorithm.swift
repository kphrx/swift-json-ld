// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct FlatteningAlgorithm {
  private struct FlattenedObjectBuilder {
    var id: String?
    var types: [String] = []
    var index: String?
    var graph: [JSONLDValue<Flattened>]?
    var properties: [String: [JSONLDValue<Flattened>]] = [:]

    init(id: String?) {
      self.id = id
    }

    var isReferenceOnly: Bool {
      self.types.isEmpty && self.index == nil && self.graph == nil && self.properties.isEmpty
    }

    mutating func addProperty(key: String, value: JSONLDValue<Flattened>, allowDuplicate: Bool) {
      if allowDuplicate {
        self.properties[key, default: []].append(value)
        return
      }
      var values = self.properties[key, default: []]
      if !values.contains(value) {
        values.append(value)
        self.properties[key] = values
      }
    }

    mutating func addType(_ type: String) {
      if !self.types.contains(type) {
        self.types.append(type)
      }
    }

    static func convert(
      _ valueObject: JSONLDValue<Expanded>.ValueObject
    ) -> JSONLDValue<Flattened>.ValueObject {
      if let type = valueObject.type {
        .init(
          value: Self.convertValue(valueObject.value),
          type: Self.convertValueType(type),
          index: valueObject.index
        )
      } else {
        .init(
          value: Self.convertValue(valueObject.value),
          language: valueObject.language,
          index: valueObject.index
        )
      }
    }

    static func convertValue(
      _ value: JSONLDValue<Expanded>.ValueObject.Value
    ) -> JSONLDValue<Flattened>.ValueObject.Value {
      switch value {
      case .string(let v): .string(v)
      case .integer(let v): .integer(v)
      case .float(let v): .float(v)
      case .boolean(let v): .boolean(v)
      case .null: .null
      }
    }

    static func convertValueType(
      _ valueType: JSONLDValue<Expanded>.ValueObject.ValueType
    ) -> JSONLDValue<Flattened>.ValueObject.ValueType {
      switch valueType {
      case .iriOrTerm(let v): .iriOrTerm(v)
      case .null: .null
      }
    }
  }

  private static let defaultGraph = "@default"

  private var blankNodeCounter = 0
  private var blankNodeMap: [String: String] = [:]
  private var nodeMap: [String: [String: FlattenedObjectBuilder]] = [Self.defaultGraph: [:]]

  static func run(
    _ document: JSONLDDocument<Expanded>
  ) throws(JSONLDError) -> JSONLDDocument<Flattened> {
    var algorithm = Self()
    for item in document.value {
      try _ = algorithm.flatten(
        .node(item),
        activeGraph: Self.defaultGraph,
        activeSubject: nil,
        activeProperty: nil
      )
    }

    var defaultGraph = algorithm.nodeMap[Self.defaultGraph] ?? [:]
    for (graphName, graph) in algorithm.nodeMap where graphName != Self.defaultGraph {
      var entry = defaultGraph[graphName] ?? .init(id: graphName)
      let flattenedGraph =
        graph
        .sorted(by: { $0.key < $1.key })
        .compactMap { _, builder -> JSONLDValue<Flattened>.NodeObject? in
          if builder.isReferenceOnly {
            return nil
          } else {
            return .init(
              id: builder.id,
              graph: builder.graph.map { .many($0) },
              type: builder.types.isEmpty ? nil : .many(builder.types),
              index: builder.index,
              properties: builder.properties.mapValues { .many($0) }
            )
          }
        }
      if !flattenedGraph.isEmpty {
        entry.graph = flattenedGraph.map { .node($0) }
        defaultGraph[graphName] = entry
      }
    }

    let nodes =
      defaultGraph
      .sorted(by: { $0.key < $1.key })
      .compactMap { _, builder -> JSONLDValue<Flattened>.NodeObject? in
        if builder.isReferenceOnly {
          return nil
        } else {
          return .init(
            id: builder.id,
            graph: builder.graph.map { .many($0) },
            type: builder.types.isEmpty ? nil : .many(builder.types),
            index: builder.index,
            properties: builder.properties.mapValues { .many($0) }
          )
        }
      }

    return .init(.many(nodes))
  }

  private mutating func flatten(
    _ element: JSONLDValue<Expanded>,
    activeGraph: String,
    activeSubject: String?,
    activeProperty: String?
  ) throws(JSONLDError) -> JSONLDValue<Flattened>? {
    switch element {
    case .node(let nodeObject):
      let id = try self.flattenNodeObject(
        nodeObject,
        activeGraph: activeGraph,
        activeSubject: activeSubject,
        activeProperty: activeProperty,
        idFromInput: true
      )
      return .node(.init(id: id))

    case .value(let valueObject):
      let flattenedValue: JSONLDValue<Flattened> = .value(
        FlattenedObjectBuilder.convert(valueObject)
      )
      try self.addResult(
        flattenedValue,
        activeGraph: activeGraph,
        activeSubject: activeSubject,
        activeProperty: activeProperty
      )
      return flattenedValue

    case .setOrList(let setOrListObject):
      switch setOrListObject.value {
      case .set(let values):
        for item in values {
          try _ = self.flatten(
            item,
            activeGraph: activeGraph,
            activeSubject: activeSubject,
            activeProperty: activeProperty
          )
        }
        return nil

      case .list(let values):
        var resultList: [JSONLDValue<Flattened>.SetOrListObject.Element] = []
        for item in values {
          if let flattenedItem = try self.flatten(
            item,
            activeGraph: activeGraph,
            activeSubject: nil,
            activeProperty: nil
          ) {
            resultList.append(flattenedItem)
          }
        }

        let listValue: JSONLDValue<Flattened> = .setOrList(
          .init(
            value: .list(
              .many(resultList)
            ),
            index: nil
          )
        )
        try self.addResult(
          listValue,
          activeGraph: activeGraph,
          activeSubject: activeSubject,
          activeProperty: activeProperty
        )
        return listValue
      }

    default:
      fatalError("Unexpected Expanded value in flatten: \(element)")
    }
  }

  private mutating func flatten(
    _ element: JSONLDValue<Expanded>.SetOrListObject.Element,
    activeGraph: String,
    activeSubject: String?,
    activeProperty: String?
  ) throws(JSONLDError) -> JSONLDValue<Flattened>.SetOrListObject.Element? {
    switch element {
    case .string(let s): return .string(s)
    case .integer(let i): return .integer(i)
    case .float(let f): return .float(f)
    case .boolean(let b): return .boolean(b)
    case .null: return .null
    case .nodeObject(let nodeObject):
      let id = try self.flattenNodeObject(
        nodeObject,
        activeGraph: activeGraph,
        activeSubject: activeSubject,
        activeProperty: activeProperty,
        idFromInput: true
      )
      return .nodeObject(.init(id: id))
    case .valueObject(let valueObject):
      let flattenedValue = FlattenedObjectBuilder.convert(valueObject)
      // Note: addResult is for JSONLDValue, but we might need to handle element-specific addResult if necessary.
      // For now, let's assume we don't need to addResult for bare value objects inside lists/sets here
      // as they will be collected by the parent map/compactMap.
      return .valueObject(flattenedValue)
    }
  }

  private mutating func flattenNodeObject(
    _ nodeObject: JSONLDValue<Expanded>.NodeObject,
    activeGraph: String,
    activeSubject: String?,
    activeProperty: String?,
    idFromInput: Bool
  ) throws(JSONLDError) -> String {
    let id =
      if let rawID = nodeObject.id {
        self.normalizeNodeID(rawID, fromInput: idFromInput)
      } else {
        self.issueBlankNode()
      }

    self.ensureNode(id, activeGraph: activeGraph)
    if let activeSubject, let activeProperty {
      try self.addValue(
        graph: activeGraph,
        subject: activeSubject,
        property: activeProperty,
        value: .node(.init(id: id)),
        allowDuplicate: false
      )
    }

    if let types = nodeObject.type {
      for type in types {
        let normalizedType = self.normalizeNodeID(type, fromInput: true)
        self.nodeMap[activeGraph]?[id]?.addType(normalizedType)
      }
    }

    if let index = nodeObject.index {
      if let existing = self.nodeMap[activeGraph]?[id]?.index, existing != index {
        throw .code(.conflictingIndexes)
      }
      self.nodeMap[activeGraph]?[id]?.index = index
    }

    if let reverse = nodeObject.reverse {
      for (property, values) in reverse.map {
        for item in values {
          guard case .node(let reverseNode) = item else {
            fatalError("Unexpected reverse value in Expanded phase: \(item)")
          }
          let reverseNodeID =
            if let rawID = reverseNode.id {
              self.normalizeNodeID(rawID, fromInput: true)
            } else {
              self.issueBlankNode()
            }

          let reverseNodeWithID = JSONLDValue<Expanded>.NodeObject(
            id: reverseNodeID,
            graph: reverseNode.graph,
            type: reverseNode.type,
            index: reverseNode.index,
            properties: reverseNode.properties
          )

          try _ = self.flattenNodeObject(
            reverseNodeWithID,
            activeGraph: activeGraph,
            activeSubject: nil,
            activeProperty: nil,
            idFromInput: false
          )
          try self.addValue(
            graph: activeGraph,
            subject: reverseNodeID,
            property: property,
            value: .node(.init(id: id)),
            allowDuplicate: false
          )
        }
      }
    }

    if let graph = nodeObject.graph {
      self.ensureGraph(id)
      for value in graph {
        try _ = self.flatten(
          value,
          activeGraph: id,
          activeSubject: nil,
          activeProperty: nil
        )
      }
    }

    for (property, values) in nodeObject.properties {
      let mappedProperty = self.normalizeProperty(property)
      self.ensurePropertyArray(graph: activeGraph, subject: id, property: mappedProperty)

      for item in values {
        try _ = self.flatten(
          item,
          activeGraph: activeGraph,
          activeSubject: id,
          activeProperty: mappedProperty
        )
      }
    }

    return id
  }

  private mutating func addResult(
    _ value: JSONLDValue<Flattened>,
    activeGraph: String,
    activeSubject: String?,
    activeProperty: String?
  ) throws(JSONLDError) {
    guard let activeSubject, let activeProperty else { return }
    let allowDuplicate =
      if case .setOrList(let object) = value, case .list = object.value {
        true
      } else {
        false
      }
    try self.addValue(
      graph: activeGraph,
      subject: activeSubject,
      property: activeProperty,
      value: value,
      allowDuplicate: allowDuplicate
    )
  }

  private mutating func addValue(
    graph: String,
    subject: String,
    property: String,
    value: JSONLDValue<Flattened>,
    allowDuplicate: Bool
  ) throws(JSONLDError) {
    self.ensureNode(subject, activeGraph: graph)
    self.nodeMap[graph]?[subject]?.addProperty(
      key: property,
      value: value,
      allowDuplicate: allowDuplicate
    )
  }

  private mutating func ensureGraph(_ graph: String) {
    if self.nodeMap[graph] == nil {
      self.nodeMap[graph] = [:]
    }
  }

  private mutating func ensureNode(_ id: String, activeGraph: String) {
    self.ensureGraph(activeGraph)
    if self.nodeMap[activeGraph]?[id] == nil {
      self.nodeMap[activeGraph]?[id] = .init(id: id)
    }
  }

  private mutating func ensurePropertyArray(graph: String, subject: String, property: String) {
    self.ensureNode(subject, activeGraph: graph)
    if self.nodeMap[graph]?[subject]?.properties[property] == nil {
      self.nodeMap[graph]?[subject]?.properties[property] = []
    }
  }

  private mutating func normalizeNodeID(_ id: String, fromInput: Bool) -> String {
    if id.hasPrefix("_:") {
      if !fromInput {
        return id
      }
      return self.issueBlankNode(for: id)
    }
    return id
  }

  private mutating func normalizeProperty(_ property: String) -> String {
    if property.hasPrefix("_:") {
      return self.issueBlankNode(for: property)
    }
    return property
  }

  private mutating func issueBlankNode(for id: String) -> String {
    if let mapped = self.blankNodeMap[id] {
      return mapped
    }
    let issued = self.issueBlankNode()
    self.blankNodeMap[id] = issued
    return issued
  }

  private mutating func issueBlankNode() -> String {
    defer { self.blankNodeCounter += 1 }
    return "_:b\(self.blankNodeCounter)"
  }
}
