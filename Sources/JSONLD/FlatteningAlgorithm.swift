// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct FlatteningAlgorithm {
  private var blankNodeCounter = 0
  private var graphs: [String: [String: JSONObject]]
  private var references: Set<String> = []
  private static let defaultGraphName = "@default"

  init() {
    self.graphs = [Self.defaultGraphName: [:]]
  }

  static func run(_ document: JSONLDDocument<Expanded>) -> JSONLDDocument<Unresolved> {
    var algorithm = Self()
    let objects = document.value.map(\.jsonObject)
    for object in objects {
      let _ = algorithm.processNodeObject(object, activeGraph: Self.defaultGraphName)
    }

    var defaultGraph = algorithm.graphs[Self.defaultGraphName] ?? [:]
    for (graphName, namedGraph) in algorithm.graphs where graphName != Self.defaultGraphName {
      var graphNode = defaultGraph[graphName] ?? [JSONLDKeyword.id.rawValue: .string(graphName)]
      let flattenedNamedGraph =
        namedGraph
        .sorted(by: { $0.key < $1.key })
        .compactMap { _, node in algorithm.shouldInclude(node: node) ? node : nil }
      if !flattenedNamedGraph.isEmpty {
        graphNode[.graph] = .array(flattenedNamedGraph.map(JSONValue.object))
        defaultGraph[graphName] = graphNode
      }
    }

    let flattened =
      defaultGraph
      .sorted(by: { $0.key < $1.key })
      .compactMap { _, node -> JSONObject? in algorithm.shouldInclude(node: node) ? node : nil }

    let json: JSONValue = .array(flattened.map(JSONValue.object))
    return (try? .init(from: json)) ?? .init(.many([]))
  }

  private mutating func processNodeObject(_ object: JSONObject, activeGraph: String) -> String {
    let id = object[.id]?.stringValue ?? self.nextBlankNodeID()
    var graph = self.graphs[activeGraph] ?? [:]
    var current = graph[id] ?? [JSONLDKeyword.id.rawValue: .string(id)]

    for (key, value) in object {
      if key == JSONLDKeyword.id.rawValue { continue }
      if key == JSONLDKeyword.graph.rawValue, case .array(let graphValues) = value {
        let namedGraph = self.graphs[id] ?? [:]
        self.graphs[id] = namedGraph
        for graphValue in graphValues {
          if case .object(let graphObject) = graphValue {
            let _ = self.processNodeObject(graphObject, activeGraph: id)
          }
        }
        continue
      }

      let processed = self.processValue(value, activeGraph: activeGraph)
      self.mergeProperty(&current, key: key, value: processed)
    }
    graph[id] = current
    self.graphs[activeGraph] = graph
    return id
  }

  private mutating func processValue(_ value: JSONValue, activeGraph: String) -> JSONValue {
    switch value {
    case .array(let values):
      return .array(values.map { self.processValue($0, activeGraph: activeGraph) })
    case .object(let object):
      if object[.list] != nil {
        var list = object
        if let listValue = object[.list], case .array(let listItems) = listValue {
          list[.list] = .array(listItems.map { self.processValue($0, activeGraph: activeGraph) })
        }
        return .object(list)
      }

      if object[.value] != nil {
        return .object(object)
      }

      let id = self.processNodeObject(object, activeGraph: activeGraph)
      self.references.insert(id)
      return .object([JSONLDKeyword.id.rawValue: .string(id)])
    default:
      return value
    }
  }

  private mutating func mergeProperty(_ node: inout JSONObject, key: String, value: JSONValue) {
    if let existing = node[key] {
      if case .array(var existingArray) = existing {
        if case .array(let newArray) = value {
          existingArray.append(contentsOf: newArray)
        } else {
          existingArray.append(value)
        }
        node[key] = .array(existingArray)
      } else if case .array(let newArray) = value {
        node[key] = .array([existing] + newArray)
      } else {
        node[key] = .array([existing, value])
      }
    } else {
      node[key] = value
    }
  }

  private mutating func nextBlankNodeID() -> String {
    defer { self.blankNodeCounter += 1 }
    return "_:b\(self.blankNodeCounter)"
  }

  private func shouldInclude(node: JSONObject) -> Bool {
    if node.count == 1, let id = node[.id]?.stringValue, !self.references.contains(id) {
      return false
    }
    return true
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
