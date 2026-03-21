// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

enum ExpansionProcessor {
  private struct ExpandedObjectBuilder {
    var id: String?
    var types: [String] = []
    var value: JSONLDValue<Expanded>.ValueObject.Value?
    var type: JSONLDValue<Expanded>.ValueObject.ValueType?
    var language: String?
    var index: String?
    var list: [JSONLDValue<Expanded>]?
    var set: [JSONLDValue<Expanded>]?
    var graph: [JSONLDValue<Expanded>]?
    var reverse: [String: [JSONLDValue<Expanded>]] = [:]
    var properties: [String: [JSONLDValue<Expanded>]] = [:]

    var isEmpty: Bool {
      self.id == nil && self.types.isEmpty && self.value == nil && self.type == nil
        && self.language == nil && self.index == nil && self.list == nil && self.set == nil
        && self.graph == nil && self.reverse.isEmpty && self.properties.isEmpty
    }

    func hasKeyword(_ keyword: JSONLDKeyword) -> Bool {
      switch keyword {
      case .id: self.id != nil
      case .type: !self.types.isEmpty
      case .value: self.value != nil
      case .language: self.language != nil
      case .list: self.list != nil
      case .set: self.set != nil
      case .graph: self.graph != nil
      case .index: self.index != nil
      case .reverse: !self.reverse.isEmpty
      default: false
      }
    }
  }

  static func expand(
    _ activeContext: ActiveContext,
    value: SingleOrMany<JSONLDValue<Unresolved>>,
    property: String?,
    insideList: Bool = false,
    loader: (any JSONLDDocumentLoader)? = nil
  ) async throws(JSONLDError) -> [JSONLDValue<Expanded>] {
    var result: [JSONLDValue<Expanded>] = []
    for item in value {
      guard
        let expanded = try await self.expand(
          activeContext,
          value: item,
          property: property,
          insideList: insideList,
          loader: loader
        )
      else {
        continue
      }

      if case .setOrList(let setOrList) = expanded,
        case .set(let values) = setOrList.value
      {
        result.append(contentsOf: values.map { JSONLDValue<Expanded>($0) })
      } else {
        result.append(expanded)
      }
    }
    return result
  }

  private static func expand(
    _ activeContext: ActiveContext,
    value: JSONLDValue<Unresolved>,
    property: String?,
    insideList: Bool = false,
    loader: (any JSONLDDocumentLoader)? = nil
  ) async throws(JSONLDError) -> JSONLDValue<Expanded>? {
    switch value {
    case .unknown(let content):
      try await self.expandObject(
        activeContext,
        object: content,
        property: property,
        insideList: insideList,
        loader: loader
      )

    case .invalid(let invalid):
      try self.handleInvalidValue(invalid)

    case .iriOrTerm(let string):
      try self.expandScalar(activeContext, value: string, property: property)

    case .integer(let integer):
      try self.expandScalar(activeContext, value: integer, property: property)

    case .float(let float):
      try self.expandScalar(activeContext, value: float, property: property)

    case .boolean(let boolean):
      try self.expandScalar(activeContext, value: boolean, property: property)

    case .null:
      nil

    case .node(let nodeObject):
      try await self.expandNode(
        activeContext,
        node: nodeObject,
        property: property,
        insideList: insideList,
        loader: loader
      )

    case .value(let valueObject):
      try await self.expandValue(
        activeContext,
        value: valueObject,
        property: property,
        insideList: insideList,
        loader: loader
      )

    case .setOrList(let setOrListObject):
      try await self.expandSetOrList(
        activeContext,
        setOrList: setOrListObject,
        property: property,
        insideList: insideList,
        loader: loader
      )

    case .languageMap(let languageMap):
      try self.expandLanguageMap(activeContext, languageMap: languageMap)

    case .indexMap(let indexMap):
      try await self.expandIndexMap(
        activeContext,
        indexMap: indexMap,
        property: property,
        insideList: insideList,
        loader: loader
      )
    }
  }

  private static func handleInvalidValue(
    _ invalid: JSONLDValue<Unresolved>.InvalidValue
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    switch invalid {
    case .listOfLists: throw .code(.listOfLists)
    case .notJSONLDValue: nil
    }
  }

  private static func expandScalar(
    _ activeContext: ActiveContext,
    value: String,
    property: String?
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    if property == nil || property == "@graph" {
      return nil
    }

    guard let property else { return nil }

    if let typeMapping = activeContext.typeMapping(for: property) {
      if typeMapping == "@id" {
        let expandedId =
          if self.shouldUseIRIExpansion(value, activeContext: activeContext) {
            try activeContext.expandIRI(value, asDocumentRelative: true)
          } else {
            self.resolveDocumentRelativeIRI(value, baseIRI: activeContext.baseIRI)
          }
        return .node(.init(id: expandedId))
      }
      if typeMapping == "@vocab" {
        var expandedId = try activeContext.expandIRI(value, asVocab: true)
        if !expandedId.contains(":") {
          expandedId = try activeContext.expandIRI(expandedId, asDocumentRelative: true)
        }
        return .node(.init(id: expandedId))
      }
      return try .value(.init(value: .string(value), type: .init(from: .string(typeMapping))))
    }

    if let languageMapping = activeContext.languageMapping(for: property) {
      return .value(.init(value: .string(value), language: languageMapping))
    }

    if activeContext.hasLanguageMapping(for: property) {
      return .value(.init(value: .string(value)))
    }

    if let defaultLanguage = activeContext.defaultLanguage {
      return .value(.init(value: .string(value), language: defaultLanguage))
    }

    return .value(.init(value: .string(value)))
  }

  private static func expandScalar(
    _ activeContext: ActiveContext,
    value: Int,
    property: String?
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    if property == nil || property == "@graph" {
      return nil
    }

    guard let property else { return nil }

    if let typeMapping = activeContext.typeMapping(for: property) {
      if typeMapping == "@id" || typeMapping == "@vocab" {
        return .value(.init(value: .integer(value)))
      }
      return try .value(.init(value: .integer(value), type: .init(from: .string(typeMapping))))
    }

    return .value(.init(value: .integer(value)))
  }

  private static func expandScalar(
    _ activeContext: ActiveContext,
    value: Double,
    property: String?
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    if property == nil || property == "@graph" {
      return nil
    }

    guard let property else { return nil }

    if let typeMapping = activeContext.typeMapping(for: property) {
      if typeMapping == "@id" || typeMapping == "@vocab" {
        return .value(.init(value: .float(value)))
      }
      return try .value(.init(value: .float(value), type: .init(from: .string(typeMapping))))
    }

    return .value(.init(value: .float(value)))
  }

  private static func expandScalar(
    _ activeContext: ActiveContext,
    value: Bool,
    property: String?
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    if property == nil || property == "@graph" {
      return nil
    }

    guard let property else { return nil }

    if let typeMapping = activeContext.typeMapping(for: property) {
      if typeMapping == "@id" || typeMapping == "@vocab" {
        return .value(.init(value: .boolean(value)))
      }
      return try .value(.init(value: .boolean(value), type: .init(from: .string(typeMapping))))
    }

    return .value(.init(value: .boolean(value)))
  }

  private static func expandNode(
    _ activeContext: ActiveContext,
    node: JSONLDValue<Unresolved>.NodeObject,
    property: String?,
    insideList: Bool,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) -> JSONLDValue<Expanded>? {
    var activeContext = activeContext
    if let localContext = node.context {
      activeContext = try await activeContext.process(
        contexts: localContext,
        loader: loader
      )
    }

    var combinedProperties = node.properties
    if let id = node.id { combinedProperties["@id"] = .single(.iriOrTerm(id)) }
    if let types = node.type {
      combinedProperties["@type"] = .many(types.map { .iriOrTerm($0) })
    }
    if let graph = node.graph {
      combinedProperties["@graph"] = graph
    }
    if let index = node.index {
      combinedProperties["@index"] = .single(.iriOrTerm(index))
    }
    if let reverse = node.reverse {
      combinedProperties["@reverse"] = try .init(
        from: reverse.jsonValue,
        mapper: JSONLDValue<Unresolved>.init(from:)
      )
    }

    return try await self.expandObject(
      activeContext,
      object: combinedProperties,
      property: property,
      insideList: insideList,
      loader: loader
    )
  }

  private static func expandValue(
    _ activeContext: ActiveContext,
    value: JSONLDValue<Unresolved>.ValueObject,
    property: String?,
    insideList: Bool,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) -> JSONLDValue<Expanded>? {
    let object = try value.jsonObject.mapValuesWithTypedThrows {
      jsonValue throws(JSONLDError) -> SingleOrMany<JSONLDValue<Unresolved>> in
      try .init(from: jsonValue, mapper: JSONLDValue<Unresolved>.init(from:))
    }
    return try await self.expandObject(
      activeContext,
      object: object,
      property: property,
      insideList: insideList,
      loader: loader
    )
  }

  private static func expandSetOrList(
    _ activeContext: ActiveContext,
    setOrList: JSONLDValue<Unresolved>.SetOrListObject,
    property: String?,
    insideList: Bool,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) -> JSONLDValue<Expanded>? {
    let indexValue = setOrList.index
    switch setOrList.value {
    case .set(let values):
      let unresolvedItems = values.map { JSONLDValue<Unresolved>($0) }
      let expanded = try await self.expand(
        activeContext,
        value: .many(unresolvedItems),
        property: property,
        insideList: insideList,
        loader: loader
      )
      return .setOrList(
        .init(
          value: .set(.many(expanded.map { JSONLDValue<Expanded>.SetOrListObject.Element($0) })),
          context: nil,
          index: indexValue
        )
      )
    case .list(let values):
      if insideList { throw .code(.listOfLists) }
      let unresolvedItems = values.map { JSONLDValue<Unresolved>($0) }
      let expanded = try await self.expand(
        activeContext,
        value: .many(unresolvedItems),
        property: property,
        insideList: true,
        loader: loader
      )

      for item in expanded {
        if case .setOrList(let object) = item, case .list = object.value {
          throw .code(.listOfLists)
        }
      }

      return .setOrList(
        .init(
          value: .list(.many(expanded.map { JSONLDValue<Expanded>.SetOrListObject.Element($0) })),
          context: nil,
          index: indexValue
        )
      )
    }
  }

  private static func expandLanguageMap(
    _ activeContext: ActiveContext,
    languageMap: JSONLDValue<Unresolved>.LanguageMap
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    var expandedItems: [JSONLDValue<Expanded>] = []
    for (lang, values) in languageMap.map.sorted(by: { $0.key < $1.key }) {
      for val in values {
        guard case .string(let s) = val else { throw .code(.invalidLanguageMapValue) }
        expandedItems.append(
          .value(.init(value: .string(s), language: lang.lowercased()))
        )
      }
    }
    return .setOrList(
      .init(
        value: .set(.many(expandedItems.map { JSONLDValue<Expanded>.SetOrListObject.Element($0) })),
        context: nil,
        index: nil
      )
    )
  }

  private static func expandIndexMap(
    _ activeContext: ActiveContext,
    indexMap: JSONLDValue<Unresolved>.IndexMap,
    property: String?,
    insideList: Bool,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) -> JSONLDValue<Expanded>? {
    var expandedItems: [JSONLDValue<Expanded>] = []
    for (_, values) in indexMap.map.sorted(by: { $0.key < $1.key }) {
      let unresolvedItems = values.map { JSONLDValue<Unresolved>($0) }
      let expanded = try await self.expand(
        activeContext,
        value: .many(unresolvedItems),
        property: property,
        insideList: insideList,
        loader: loader
      )
      expandedItems.append(contentsOf: expanded)
    }
    return .setOrList(
      .init(
        value: .set(.many(expandedItems.map { JSONLDValue<Expanded>.SetOrListObject.Element($0) })),
        context: nil,
        index: nil
      )
    )
  }

  private static func expandObject(
    _ activeContext: ActiveContext,
    object: [String: SingleOrMany<JSONLDValue<Unresolved>>],
    property: String?,
    insideList: Bool,
    loader: (any JSONLDDocumentLoader)? = nil
  ) async throws(JSONLDError) -> JSONLDValue<Expanded>? {
    var object = object
    var activeContext = activeContext

    if let localContextValue = object.removeValue(forKey: JSONLDKeyword.context.rawValue) {
      activeContext = try await activeContext.process(
        contexts: try .init(from: localContextValue.jsonValue),
        loader: loader
      )
    }

    var builder = ExpandedObjectBuilder()

    for (key, val) in object.sorted(by: { $0.key < $1.key }) {
      let expandedProperty = try activeContext.expandIRI(key, asVocab: true)

      switch JSONLDKeyword(rawValue: expandedProperty) {
      case _? where property == "@reverse":
        throw .code(.invalidReversePropertyMap)

      case let keyword? where builder.hasKeyword(keyword):
        throw .code(.collidingKeywords)

      case .id?:
        try self.expandIdKeyword(val, into: &builder, activeContext: activeContext)

      case .type?:
        try self.expandTypeKeyword(val, into: &builder, activeContext: activeContext)

      case .value?:
        try self.expandValueKeyword(val, into: &builder)

      case .language?:
        try self.expandLanguageKeyword(val, into: &builder)

      case .list?:
        try await self.expandListKeyword(
          val,
          into: &builder,
          activeContext: activeContext,
          property: property,
          insideList: insideList,
          loader: loader
        )

      case .set?:
        try await self.expandSetKeyword(
          val,
          into: &builder,
          activeContext: activeContext,
          property: property,
          insideList: insideList,
          loader: loader
        )

      case .graph?:
        try await self.expandGraphKeyword(
          val,
          into: &builder,
          activeContext: activeContext,
          loader: loader
        )

      case .index?:
        try self.expandIndexKeyword(val, into: &builder)

      case .reverse?:
        try await self.expandReverseKeyword(
          val,
          into: &builder,
          activeContext: activeContext,
          loader: loader
        )

      case .context?:
        continue

      case nil:
        try await self.expandTermProperty(
          val,
          into: &builder,
          expandedProperty: expandedProperty,
          term: key,
          activeContext: activeContext,
          property: property,
          insideList: insideList,
          loader: loader
        )

      default:
        continue
      }
    }

    return try self.finalizeExpandedObject(
      &builder,
      property: property,
      activeContext: activeContext
    )
  }

  private static func arrayValue<T>(_ value: SingleOrMany<T>?) -> [T] {
    switch value {
    case .single(let single)?:
      [single]
    case .many(let values)?:
      values
    case .none:
      []
    }
  }

  private static func expandIdKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder,
    activeContext: ActiveContext
  ) throws(JSONLDError) {
    guard case .single(.iriOrTerm(let idStr)) = value else { throw .code(.invalidIdValue) }
    let expandedId =
      if self.shouldUseIRIExpansion(idStr, activeContext: activeContext) {
        try activeContext.expandIRI(idStr, asDocumentRelative: true)
      } else {
        self.resolveDocumentRelativeIRI(idStr, baseIRI: activeContext.baseIRI)
      }
    builder.id = expandedId
  }

  private static func expandTypeKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder,
    activeContext: ActiveContext
  ) throws(JSONLDError) {
    var expandedTypes: [String] = []
    for item in value {
      guard case .iriOrTerm(let s) = item else { throw .code(.invalidTypeValue) }
      let expandedType = try activeContext.expandIRI(
        s,
        asVocab: true,
        asDocumentRelative: true
      )
      expandedTypes.append(expandedType)
    }
    builder.types.append(contentsOf: expandedTypes)
  }

  private static func expandValueKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder
  ) throws(JSONLDError) {
    let jsonValue = value.jsonValue
    builder.value = try .init(from: jsonValue)
  }

  private static func expandLanguageKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder
  ) throws(JSONLDError) {
    guard case .single(.iriOrTerm(let langStr)) = value else {
      throw .code(.invalidLanguageTaggedString)
    }
    builder.language = langStr.lowercased()
  }

  private static func expandListKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder,
    activeContext: ActiveContext,
    property: String?,
    insideList: Bool,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) {
    if insideList { throw .code(.listOfLists) }
    let expandedList = try await self.expand(
      activeContext,
      value: value,
      property: property,
      insideList: true,
      loader: loader
    )

    for item in expandedList {
      if case .setOrList(let object) = item, case .list = object.value {
        throw .code(.listOfLists)
      }
    }
    builder.list = (builder.list ?? []) + expandedList
  }

  private static func expandSetKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder,
    activeContext: ActiveContext,
    property: String?,
    insideList: Bool,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) {
    let expandedSet = try await self.expand(
      activeContext,
      value: value,
      property: property,
      insideList: insideList,
      loader: loader
    )
    builder.set = (builder.set ?? []) + expandedSet
  }

  private static func expandGraphKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder,
    activeContext: ActiveContext,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) {
    let expandedGraph = try await self.expand(
      activeContext,
      value: value,
      property: "@graph",
      insideList: false,
      loader: loader
    )
    builder.graph = (builder.graph ?? []) + expandedGraph
  }

  private static func expandIndexKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder
  ) throws(JSONLDError) {
    guard case .single(.iriOrTerm(let indexStr)) = value else { throw .code(.invalidIndexValue) }
    builder.index = indexStr
  }

  private static func expandReverseKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder,
    activeContext: ActiveContext,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) {
    let reverseObject: [String: SingleOrMany<JSONLDValue<Unresolved>>] =
      switch value {
      case .single(.unknown(let content)):
        content
      case .single(.node(let node)):
        node.properties
      default:
        throw .code(.invalidReversePropertyMap)
      }

    if let expandedReverse = try await self.expandObject(
      activeContext,
      object: reverseObject,
      property: "@reverse",
      insideList: false,
      loader: loader
    ),
      case .node(let node) = expandedReverse
    {
      if let reverse = node.reverse {
        for (mapKey, mapValue) in reverse.map {
          let values = self.arrayValue(mapValue).map { value -> JSONLDValue<Expanded> in
            switch value {
            case .node(let node): .node(node)
            case .iri(let iri): .iriOrTerm(iri)
            }
          }
          builder.reverse[mapKey] = (builder.reverse[mapKey] ?? []) + values
        }
      }

      for (key, val) in node.properties {
        let values = self.arrayValue(val)
        builder.properties[key] = (builder.properties[key] ?? []) + values
      }
      if let id = node.id {
        builder.properties["@id"] = (builder.properties["@id"] ?? []) + [.iriOrTerm(id)]
      }
      if let types = node.type {
        builder.properties["@type"] =
          (builder.properties["@type"] ?? []) + types.map { .iriOrTerm($0) }
      }
      if let graph = node.graph {
        builder.properties["@graph"] = (builder.properties["@graph"] ?? []) + self.arrayValue(graph)
      }
      if let index = node.index {
        builder.properties["@index"] = (builder.properties["@index"] ?? []) + [.iriOrTerm(index)]
      }
    } else {
      throw .code(.invalidReversePropertyMap)
    }
  }

  private static func expandTermProperty(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into builder: inout ExpandedObjectBuilder,
    expandedProperty: String,
    term: String,
    activeContext: ActiveContext,
    property: String?,
    insideList: Bool,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) {
    if !expandedProperty.contains(":") && !expandedProperty.hasPrefix("_:") {
      return
    }

    let container = activeContext.containerMapping(for: term)
    let expandedValues: [JSONLDValue<Expanded>]

    let isLanguageMap =
      if container == .language {
        switch value {
        case .single(.unknown), .single(.node): true
        default: false
        }
      } else {
        false
      }

    let isIndexMap =
      if container == .index {
        switch value {
        case .single(.unknown), .single(.node): true
        default: false
        }
      } else {
        false
      }

    if isLanguageMap {
      let map: [String: SingleOrMany<JSONLDValue<Unresolved>>] =
        switch value {
        case .single(.unknown(let m)): m
        case .single(.node(let node)): node.properties
        default: [:]
        }

      var values: [JSONLDValue<Expanded>] = []
      for (lang, langVal) in map.sorted(by: { $0.key < $1.key }) {
        for item in langVal {
          let json = item.jsonValue
          guard case .string(let s) = json else {
            throw .code(.invalidLanguageMapValue)
          }
          values.append(
            .value(.init(value: .string(s), language: lang.lowercased()))
          )
        }
      }
      expandedValues = values
    } else if isIndexMap {
      let map: [String: SingleOrMany<JSONLDValue<Unresolved>>] =
        switch value {
        case .single(.unknown(let m)):
          m
        case .single(.node(let node)):
          node.properties
        default:
          [:]
        }

      var values: [JSONLDValue<Expanded>] = []
      for (index, indexVal) in map.sorted(by: { $0.key < $1.key }) {
        let expanded = try await self.expand(
          activeContext,
          value: indexVal,
          property: term,
          insideList: insideList,
          loader: loader
        )

        for item in expanded {
          switch item {
          case .node(let node):
            values.append(
              .node(
                .init(
                  context: node.context,
                  id: node.id,
                  graph: node.graph,
                  type: node.type,
                  reverse: node.reverse,
                  index: node.index ?? index,
                  properties: node.properties
                )
              )
            )
          case .value(let val):
            if let language = val.language {
              values.append(
                .value(
                  .init(
                    value: val.value,
                    language: language,
                    context: val.context,
                    index: val.index ?? index
                  )
                )
              )
            } else {
              values.append(
                .value(
                  .init(
                    value: val.value,
                    type: val.type,
                    context: val.context,
                    index: val.index ?? index
                  )
                )
              )
            }
          case .setOrList(let object):
            values.append(
              .setOrList(
                .init(
                  value: object.value,
                  context: object.context,
                  index: object.index ?? index
                )
              )
            )
          default:
            values.append(item)
          }
        }
      }
      expandedValues = values
    } else {
      expandedValues = try await self.expand(
        activeContext,
        value: value,
        property: term,
        insideList: insideList,
        loader: loader
      )
    }

    let shouldIncludeProperty =
      if expandedValues.isEmpty {
        switch value {
        case .many:
          true
        case .single(.setOrList):
          true
        default:
          false
        }
      } else {
        true
      }

    if shouldIncludeProperty {
      if container == .list, case .many = value,
        expandedValues.contains(where: {
          if case .setOrList(let object) = $0, case .list = object.value { true } else { false }
        })
      {
        throw .code(.listOfLists)
      }

      let isReverseProperty = activeContext.termDefinitions[term]?.reverse ?? false

      if isReverseProperty || property == "@reverse" {
        for v in expandedValues {
          guard case .node = v else { throw .code(.invalidReversePropertyValue) }
        }

        if isReverseProperty && property == "@reverse" {
          builder.properties[expandedProperty] =
            (builder.properties[expandedProperty] ?? []) + expandedValues
        } else {
          builder.reverse[expandedProperty] =
            (builder.reverse[expandedProperty] ?? []) + expandedValues
        }
        return
      }

      let finalValues: [JSONLDValue<Expanded>] =
        if container == .list {
          [
            .setOrList(
              .init(
                value: .list(.many(self.listItems(for: expandedValues))),
                context: nil,
                index: nil
              )
            )
          ]
        } else {
          expandedValues
        }

      builder.properties[expandedProperty] =
        (builder.properties[expandedProperty] ?? []) + finalValues
    }
  }

  private static func finalizeExpandedObject(
    _ builder: inout ExpandedObjectBuilder,
    property: String?,
    activeContext: ActiveContext
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    if let value = builder.value {
      if !builder.properties.isEmpty || builder.id != nil || builder.graph != nil
        || !builder.reverse.isEmpty || builder.list != nil || builder.set != nil
      {
        throw .code(.invalidValueObject)
      }
      if builder.language != nil && builder.types.count > 0 {
        throw .code(.invalidValueObject)
      }

      if case .null = value { return nil }
      if builder.language != nil {
        if case .string = value {} else { throw .code(.invalidLanguageTaggedValue) }
      }

      let type: JSONLDValue<Expanded>.ValueObject.ValueType?
      if builder.types.count > 0 {
        if builder.types.count > 1 { throw .code(.invalidTypedValue) }
        type = try JSONLDValue<Expanded>.ValueObject.ValueType(builder.types[0])
      } else {
        type = nil
      }

      // If property is null or @graph, and it's a value object, it's dropped.
      if property == nil || property == "@graph" {
        return nil
      }

      if let language = builder.language {
        return .value(
          .init(value: value, language: language, index: builder.index)
        )
      } else {
        return .value(
          .init(value: value, type: type, index: builder.index)
        )
      }
    }

    if let list = builder.list {
      if !builder.properties.isEmpty || builder.id != nil || builder.graph != nil
        || !builder.reverse.isEmpty || builder.set != nil || builder.types.count > 0
        || builder.language != nil || builder.value != nil
      {
        throw .code(.invalidSetOrListObject)
      }
      // If property is null or @graph, and it's a list object, it's dropped.
      if property == nil || property == "@graph" {
        return nil
      }
      return .setOrList(
        .init(value: .list(.many(self.listItems(for: list))), context: nil, index: builder.index)
      )
    }

    if let set = builder.set {
      if !builder.properties.isEmpty || builder.id != nil || builder.graph != nil
        || !builder.reverse.isEmpty || builder.list != nil || builder.types.count > 0
        || builder.language != nil || builder.value != nil
      {
        throw .code(.invalidSetOrListObject)
      }
      // If property is null or @graph, and it's a set object, return its @set value.
      if property == nil || property == "@graph" {
        return .setOrList(
          .init(
            value: .set(.many(self.listItems(for: set))),
            context: nil,
            index: nil
          )
        )
      }
      return .setOrList(
        .init(
          value: .set(.many(self.listItems(for: set))),
          context: nil,
          index: builder.index
        )
      )
    }

    // Step 13.4.12: if element contains only the @language keyword, the result is set to null.
    if builder.id == nil, builder.types.isEmpty, builder.value == nil, builder.type == nil,
      builder.list == nil, builder.set == nil, builder.graph == nil, builder.reverse.isEmpty,
      builder.properties.isEmpty, builder.language != nil
    {
      return nil
    }

    if property == nil || property == "@graph" {
      if builder.isEmpty {
        return nil
      }
      if builder.properties.isEmpty, builder.types.isEmpty, builder.graph == nil,
        builder.reverse.isEmpty, builder.id != nil
      {
        return nil
      }
    }

    let reverseEntry: JSONLDValue<Expanded>.NodeObject.ReversePropertyMap? =
      if !builder.reverse.isEmpty {
        .init(
          map: builder.reverse.mapValues {
            .many(
              $0.compactMap {
                if case .node(let node) = $0 { .node(node) } else { nil }
              }
            )
          }
        )
      } else {
        nil
      }

    return .node(
      .init(
        id: builder.id,
        graph: builder.graph.map { .many($0) },
        type: builder.types.isEmpty ? nil : .many(builder.types),
        reverse: reverseEntry,
        index: builder.index,
        properties: builder.properties.mapValues { .many($0) }
      )
    )
  }

  private static func validateIRI(
    _ iri: String,
    code: JSONLDError.Code
  ) throws(JSONLDError) -> String {
    if iri.contains(":") || JSONLDKeyword(rawValue: iri) != nil || iri.hasPrefix("_:") {
      return iri
    }
    throw .code(code)
  }

  private static func listItems(
    for values: [JSONLDValue<Expanded>]
  ) -> [JSONLDValue<Expanded>.SetOrListObject.Element] {
    if values.count == 1,
      case .setOrList(let object) = values[0],
      case .list(let listValues) = object.value
    {
      return self.arrayValue(listValues)
    }
    return values.compactMap { value in
      switch value {
      case .iriOrTerm(let s): .string(s)
      case .integer(let i): .integer(i)
      case .float(let f): .float(f)
      case .boolean(let b): .boolean(b)
      case .null: .null
      case .node(let n): .nodeObject(n)
      case .value(let v): .valueObject(v)
      case .setOrList, .indexMap, .languageMap, .unknown, .invalid: nil
      }
    }
  }

  private static func resolveDocumentRelativeIRI(_ value: String, baseIRI: String?) -> String {
    if value.isEmpty {
      if let baseIRI {
        return self.normalizeResolvedIRI(baseIRI)
      }
      return value
    }
    return
      if let baseIRI,
      let baseURL = URL(string: baseIRI),
      let resolvedURL = URL(string: value, relativeTo: baseURL)
    {
      self.normalizeResolvedIRI(resolvedURL.absoluteString)
    } else {
      value
    }
  }

  private static func normalizeResolvedIRI(_ iri: String) -> String {
    guard var components = URLComponents(string: iri) else { return iri }
    components.percentEncodedPath = self.removeDotSegments(components.percentEncodedPath)
    return components.string ?? iri
  }

  private static func removeDotSegments(_ path: String) -> String {
    let isAbsolute = path.hasPrefix("/")
    let hasTrailingSlash = path.hasSuffix("/")
    var output: [Substring] = []

    for segment in path.split(separator: "/", omittingEmptySubsequences: false) {
      if segment.isEmpty || segment == "." { continue }
      if segment == ".." {
        if !output.isEmpty { _ = output.removeLast() }
      } else {
        output.append(segment)
      }
    }

    var normalized = output.joined(separator: "/")
    if isAbsolute { normalized = "/" + normalized }
    if hasTrailingSlash && !normalized.hasSuffix("/") { normalized += "/" }
    if normalized.isEmpty { return isAbsolute ? "/" : "" }
    return normalized
  }

  private static func shouldUseIRIExpansion(_ value: String, activeContext: ActiveContext) -> Bool {
    if value.hasPrefix("_:") {
      return true
    }
    guard let colon = value.firstIndex(of: ":") else {
      return false
    }

    let prefix = String(value[..<colon])
    let suffix = String(value[value.index(after: colon)...])

    if activeContext.termDefinitions[prefix] != nil {
      return true
    }
    if suffix.hasPrefix("//") {
      return true
    }
    if let first = prefix.first, first.isLetter {
      return prefix.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
    }
    return false
  }

  private static func mergeProperty(_ properties: inout JSONObject, key: String, value: JSONValue) {
    if let existing = properties[key] {
      if case .array(var existingArray) = existing {
        if case .array(let newArray) = value {
          existingArray.append(contentsOf: newArray)
        } else {
          existingArray.append(value)
        }
        properties[key] = .array(existingArray)
      } else if case .array(let newArray) = value {
        properties[key] = .array([existing] + newArray)
      } else {
        properties[key] = .array([existing, value])
      }
    } else {
      properties[key] = value
    }
  }
}

extension JSONLDValue.SetOrListObject.Element {
  init(_ value: JSONLDValue<P>) {
    self =
      switch value {
      case .iriOrTerm(let s): .string(s)
      case .integer(let i): .integer(i)
      case .float(let f): .float(f)
      case .boolean(let b): .boolean(b)
      case .null: .null
      case .node(let n): .nodeObject(n)
      case .value(let v): .valueObject(v)
      case .setOrList, .languageMap, .indexMap, .unknown, .invalid:
        .null
      }
  }
}
