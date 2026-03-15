// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct FlatteningAlgorithm {
  private static let defaultGraph = "@default"

  private var blankNodeCounter = 0
  private var blankNodeMap: [String: String] = [:]
  private var nodeMap: [String: [String: JSONObject]] = [Self.defaultGraph: [:]]

  static func run(
    _ document: JSONLDDocument<Expanded>
  ) throws(JSONLDError) -> JSONLDDocument<Flattened> {
    var algorithm = Self()
    var list: [JSONValue]? = nil
    try algorithm.generate(
      .array(document.value.map(\.jsonValue)),
      activeGraph: Self.defaultGraph,
      activeSubject: nil,
      activeProperty: nil,
      list: &list
    )

    var defaultGraph = algorithm.nodeMap[Self.defaultGraph] ?? [:]
    for (graphName, graph) in algorithm.nodeMap where graphName != Self.defaultGraph {
      var entry = defaultGraph[graphName] ?? [JSONLDKeyword.id.rawValue: .string(graphName)]
      let flattenedGraph =
        graph
        .sorted(by: { $0.key < $1.key })
        .compactMap { _, node -> JSONObject? in
          algorithm.shouldInclude(node)
        }
      if !flattenedGraph.isEmpty {
        entry[.graph] = .array(flattenedGraph.map(JSONValue.object))
        defaultGraph[graphName] = entry
      }
    }

    let flattened =
      defaultGraph
      .sorted(by: { $0.key < $1.key })
      .compactMap { _, node -> JSONObject? in
        algorithm.shouldInclude(node)
      }

    return try .init(validating: .array(flattened.map(JSONValue.object)))
  }

  private mutating func generate(
    _ element: JSONValue,
    activeGraph: String,
    activeSubject: String?,
    activeProperty: String?,
    list: inout [JSONValue]?
  ) throws(JSONLDError) {
    switch element {
    case .array(let array):
      for item in array {
        try self.generate(
          item,
          activeGraph: activeGraph,
          activeSubject: activeSubject,
          activeProperty: activeProperty,
          list: &list
        )
      }

    case .object(let object):
      if object[.value] != nil {
        try self.addResult(
          .object(object),
          activeGraph: activeGraph,
          activeSubject: activeSubject,
          activeProperty: activeProperty,
          list: &list
        )
        return
      }

      if let listObject = object[.list], case .array(let listValues) = listObject {
        var resultList: [JSONValue]? = []
        for item in listValues {
          try self.generate(
            item,
            activeGraph: activeGraph,
            activeSubject: nil,
            activeProperty: nil,
            list: &resultList
          )
        }
        let listValue: JSONValue = .object([JSONLDKeyword.list.rawValue: .array(resultList ?? [])])
        try self.addResult(
          listValue,
          activeGraph: activeGraph,
          activeSubject: activeSubject,
          activeProperty: activeProperty,
          list: &list
        )
        return
      }

      try self.generateNodeObject(
        object,
        activeGraph: activeGraph,
        activeSubject: activeSubject,
        activeProperty: activeProperty,
        list: &list,
        idFromInput: true
      )

    default:
      break
    }
  }

  private mutating func generateNodeObject(
    _ object: JSONObject,
    activeGraph: String,
    activeSubject: String?,
    activeProperty: String?,
    list: inout [JSONValue]?,
    idFromInput: Bool
  ) throws(JSONLDError) {
    var object = object
    let id =
      if let rawID = object.removeValue(for: .id)?.stringValue {
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
        value: .object([JSONLDKeyword.id.rawValue: .string(id)]),
        allowDuplicate: false
      )
    }
    if list != nil {
      list?.append(.object([JSONLDKeyword.id.rawValue: .string(id)]))
    }

    if let types = object.removeValue(for: .type), case .array(let typeValues) = types {
      for typeValue in typeValues {
        guard case .string(let rawType) = typeValue else { continue }
        let type = self.normalizeNodeID(rawType, fromInput: true)
        try self.addValue(
          graph: activeGraph,
          subject: id,
          property: JSONLDKeyword.type.rawValue,
          value: .string(type),
          allowDuplicate: false
        )
      }
    }

    if let index = object.removeValue(for: .index) {
      if let existing = self.nodeMap[activeGraph]?[id]?[.index], existing != index {
        throw .code(.conflictingIndexes)
      }
      self.nodeMap[activeGraph]?[id]?[.index] = index
    }

    if let reverse = object.removeValue(for: .reverse), case .object(let reverseMap) = reverse {
      for (property, value) in reverseMap {
        guard case .array(let values) = value else { continue }
        for item in values {
          guard case .object(let reverseNode) = item else { continue }
          let reverseNodeID =
            if let rawID = reverseNode[.id]?.stringValue {
              self.normalizeNodeID(rawID, fromInput: true)
            } else {
              self.issueBlankNode()
            }
          var reverseNodeWithID = reverseNode
          reverseNodeWithID[.id] = .string(reverseNodeID)

          var noList: [JSONValue]? = nil
          try self.generateNodeObject(
            reverseNodeWithID,
            activeGraph: activeGraph,
            activeSubject: nil,
            activeProperty: nil,
            list: &noList,
            idFromInput: false
          )
          try self.addValue(
            graph: activeGraph,
            subject: reverseNodeID,
            property: property,
            value: .object([JSONLDKeyword.id.rawValue: .string(id)]),
            allowDuplicate: false
          )
        }
      }
    }

    if let graph = object.removeValue(for: .graph), case .array(let values) = graph {
      self.ensureGraph(id)
      for value in values {
        var noList: [JSONValue]? = nil
        try self.generate(
          value,
          activeGraph: id,
          activeSubject: nil,
          activeProperty: nil,
          list: &noList
        )
      }
    }

    for (property, value) in object {
      let mappedProperty = self.normalizeProperty(property)
      self.ensurePropertyArray(graph: activeGraph, subject: id, property: mappedProperty)

      guard case .array(let values) = value else { continue }
      for item in values {
        var noList: [JSONValue]? = nil
        try self.generate(
          item,
          activeGraph: activeGraph,
          activeSubject: id,
          activeProperty: mappedProperty,
          list: &noList
        )
      }
    }
  }

  private mutating func addResult(
    _ value: JSONValue,
    activeGraph: String,
    activeSubject: String?,
    activeProperty: String?,
    list: inout [JSONValue]?
  ) throws(JSONLDError) {
    if list != nil {
      list?.append(value)
      return
    }

    guard let activeSubject, let activeProperty else { return }
    let allowDuplicate =
      if case .object(let object) = value, object[.list] != nil {
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
    value: JSONValue,
    allowDuplicate: Bool
  ) throws(JSONLDError) {
    self.ensurePropertyArray(graph: graph, subject: subject, property: property)
    guard case .array(var existing) = self.nodeMap[graph]?[subject]?[property] else {
      throw .internalError(.notObject)
    }

    if allowDuplicate || !existing.contains(value) {
      existing.append(value)
    }

    self.nodeMap[graph]?[subject]?[property] = .array(existing)
  }

  private func shouldInclude(_ node: JSONObject) -> JSONObject? {
    if node.count == 1, node[.id] != nil { return nil }
    return node
  }

  private mutating func ensureGraph(_ graph: String) {
    if self.nodeMap[graph] == nil {
      self.nodeMap[graph] = [:]
    }
  }

  private mutating func ensureNode(_ id: String, activeGraph: String) {
    self.ensureGraph(activeGraph)
    if self.nodeMap[activeGraph]?[id] == nil {
      self.nodeMap[activeGraph]?[id] = [JSONLDKeyword.id.rawValue: .string(id)]
    }
  }

  private mutating func ensurePropertyArray(graph: String, subject: String, property: String) {
    self.ensureNode(subject, activeGraph: graph)
    if self.nodeMap[graph]?[subject]?[property] == nil {
      self.nodeMap[graph]?[subject]?[property] = .array([])
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

extension JSONValue {
  fileprivate var stringValue: String? {
    if case .string(let value) = self {
      return value
    }
    return nil
  }
}
