// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

enum ExpansionProcessor {
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

      if case .setOrList(.set(let values, _, _)) = expanded {
        result.append(contentsOf: values.map { .init($0) })
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
        return try .node(.init(from: .object(["@id": .string(expandedId)])))
      }
      if typeMapping == "@vocab" {
        var expandedId = try activeContext.expandIRI(value, asVocab: true)
        if !expandedId.contains(":") {
          expandedId = try activeContext.expandIRI(expandedId, asDocumentRelative: true)
        }
        return try .node(.init(from: .object(["@id": .string(expandedId)])))
      }
      return try .value(
        .init(from: .object(["@value": .string(value), "@type": .string(typeMapping)]))
      )
    }

    if let languageMapping = activeContext.languageMapping(for: property) {
      return try .value(
        .init(from: .object(["@value": .string(value), "@language": .string(languageMapping)]))
      )
    }

    if activeContext.hasLanguageMapping(for: property) {
      return try .value(.init(from: .object(["@value": .string(value)])))
    }

    if let defaultLanguage = activeContext.defaultLanguage {
      return try .value(
        .init(from: .object(["@value": .string(value), "@language": .string(defaultLanguage)]))
      )
    }

    return try .value(.init(from: .object(["@value": .string(value)])))
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
        return try .value(.init(from: .object(["@value": .integer(value)])))
      }
      return try .value(
        .init(from: .object(["@value": .integer(value), "@type": .string(typeMapping)]))
      )
    }

    return try .value(.init(from: .object(["@value": .integer(value)])))
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
        return try .value(.init(from: .object(["@value": .float(value)])))
      }
      return try .value(
        .init(from: .object(["@value": .float(value), "@type": .string(typeMapping)]))
      )
    }

    return try .value(.init(from: .object(["@value": .float(value)])))
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
        return try .value(.init(from: .object(["@value": .boolean(value)])))
      }
      return try .value(
        .init(from: .object(["@value": .boolean(value), "@type": .string(typeMapping)]))
      )
    }

    return try .value(.init(from: .object(["@value": .boolean(value)])))
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
      combinedProperties["@reverse"] = try .init(from: reverse.jsonValue)
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
    let object = try value.jsonObject.mapValuesWithTypedThrows(
      SingleOrMany<JSONLDValue<Unresolved>>.init(from:)
    )
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
    switch setOrList {
    case .set(let values, _, let index):
      let unresolvedItems = values.map { JSONLDValue<Unresolved>($0) }
      let expanded = try await self.expand(
        activeContext,
        value: .many(unresolvedItems),
        property: property,
        insideList: insideList,
        loader: loader
      )
      return try .setOrList(
        .set(.many(expanded.map { .init($0) }), context: nil, index: index)
      )
    case .list(let values, _, let index):
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
        if case .setOrList(.list) = item {
          throw .code(.listOfLists)
        }
      }

      return try .setOrList(
        .list(.many(expanded.map { .init($0) }), context: nil, index: index)
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
          try .value(
            .init(from: .object(["@value": .string(s), "@language": .string(lang.lowercased())]))
          )
        )
      }
    }
    return .setOrList(
      .set(.many(expandedItems.map { .init($0) }), context: nil, index: nil)
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
      .set(.many(expandedItems.map { .init($0) }), context: nil, index: nil)
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

    var expandedProperties: JSONObject = [:]

    for (key, val) in object.sorted(by: { $0.key < $1.key }) {
      let expandedProperty = try activeContext.expandIRI(key, asVocab: true)

      switch JSONLDKeyword(rawValue: expandedProperty) {
      case _? where property == "@reverse":
        throw .code(.invalidReversePropertyMap)

      case _? where expandedProperties.keys.contains(expandedProperty):
        throw .code(.collidingKeywords)

      case .id?:
        try self.expandIdKeyword(
          val,
          into: &expandedProperties,
          key: expandedProperty,
          activeContext: activeContext
        )

      case .type?:
        try self.expandTypeKeyword(
          val,
          into: &expandedProperties,
          key: expandedProperty,
          activeContext: activeContext
        )

      case .value?:
        try self.expandValueKeyword(val, into: &expandedProperties, key: expandedProperty)

      case .language?:
        try self.expandLanguageKeyword(val, into: &expandedProperties, key: expandedProperty)

      case .list?:
        try await self.expandListKeyword(
          val,
          into: &expandedProperties,
          key: expandedProperty,
          activeContext: activeContext,
          property: property,
          insideList: insideList,
          loader: loader
        )

      case .set?:
        try await self.expandSetKeyword(
          val,
          into: &expandedProperties,
          key: expandedProperty,
          activeContext: activeContext,
          property: property,
          insideList: insideList,
          loader: loader
        )

      case .graph?:
        try await self.expandGraphKeyword(
          val,
          into: &expandedProperties,
          key: expandedProperty,
          activeContext: activeContext,
          loader: loader
        )

      case .index?:
        try self.expandIndexKeyword(val, into: &expandedProperties, key: expandedProperty)

      case .reverse?:
        try await self.expandReverseKeyword(
          val,
          into: &expandedProperties,
          activeContext: activeContext,
          loader: loader
        )

      case nil:
        try await self.expandTermProperty(
          val,
          into: &expandedProperties,
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
      &expandedProperties,
      property: property,
      activeContext: activeContext
    )
  }

  private static func expandIdKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
    key: String,
    activeContext: ActiveContext
  ) throws(JSONLDError) {
    guard case .single(.iriOrTerm(let idStr)) = value else { throw .code(.invalidIdValue) }
    let expandedId =
      if self.shouldUseIRIExpansion(idStr, activeContext: activeContext) {
        try activeContext.expandIRI(idStr, asDocumentRelative: true)
      } else {
        self.resolveDocumentRelativeIRI(idStr, baseIRI: activeContext.baseIRI)
      }
    properties[key] = .string(expandedId)
  }

  private static func expandTypeKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
    key: String,
    activeContext: ActiveContext
  ) throws(JSONLDError) {
    var expandedTypes: [JSONValue] = []
    for item in value {
      guard case .iriOrTerm(let s) = item else { throw .code(.invalidTypeValue) }
      let expandedType = try activeContext.expandIRI(
        s,
        asVocab: true,
        asDocumentRelative: true
      )
      expandedTypes.append(.string(expandedType))
    }
    properties[key] = .array(expandedTypes)
  }

  private static func expandValueKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
    key: String
  ) throws(JSONLDError) {
    let jsonValue = value.jsonValue
    if case .object = jsonValue { throw .code(.invalidValueObjectValue) }
    if case .array = jsonValue { throw .code(.invalidValueObjectValue) }
    properties[key] = jsonValue
  }

  private static func expandLanguageKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
    key: String
  ) throws(JSONLDError) {
    guard case .single(.iriOrTerm(let langStr)) = value else {
      throw .code(.invalidLanguageTaggedString)
    }
    properties[key] = .string(langStr.lowercased())
  }

  private static func expandListKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
    key: String,
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
      if case .setOrList(.list) = item {
        throw .code(.listOfLists)
      }
    }
    properties[key] = .array(expandedList.map(\.jsonValue))
  }

  private static func expandSetKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
    key: String,
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
    properties[key] = .array(expandedSet.map(\.jsonValue))
  }

  private static func expandGraphKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
    key: String,
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
    properties[key] = .array(expandedGraph.map(\.jsonValue))
  }

  private static func expandIndexKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
    key: String
  ) throws(JSONLDError) {
    guard case .single(.iriOrTerm(let indexStr)) = value else { throw .code(.invalidIndexValue) }
    properties[key] = .string(indexStr)
  }

  private static func expandReverseKeyword(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
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
      for (reverseKey, reverseValue) in node.jsonObject {
        if reverseKey == JSONLDKeyword.reverse.rawValue {
          guard case .object(let reverseMap) = reverseValue else {
            throw .code(.invalidReversePropertyMap)
          }

          var mergedReverseMap: JSONObject =
            if let existingReverse = properties[.reverse] {
              if case .object(let existingMap) = existingReverse {
                existingMap
              } else {
                throw .internalError(.notObject)
              }
            } else {
              [:]
            }

          for (mapKey, mapValue) in reverseMap {
            if let existing = mergedReverseMap[mapKey] {
              if case .array(var existingArray) = existing {
                if case .array(let newArray) = mapValue {
                  existingArray.append(contentsOf: newArray)
                } else {
                  existingArray.append(mapValue)
                }
                mergedReverseMap[mapKey] = .array(existingArray)
              } else {
                throw .internalError(.notObject)
              }
            } else {
              mergedReverseMap[mapKey] = mapValue
            }
          }

          properties[.reverse] = .object(mergedReverseMap)
        } else {
          self.mergeProperty(&properties, key: reverseKey, value: reverseValue)
        }
      }
    } else {
      throw .code(.invalidReversePropertyMap)
    }
  }

  private static func expandTermProperty(
    _ value: SingleOrMany<JSONLDValue<Unresolved>>,
    into properties: inout JSONObject,
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
            try .value(
              .init(
                from: .object([
                  "@value": .string(s),
                  "@language": .string(lang.lowercased()),
                ])
              )
            )
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
          if case .object(var object) = item.jsonValue {
            if object[.index] == nil {
              object[.index] = .string(index)
            }
            values.append(try .init(from: .object(object)))
          } else {
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
          if case .setOrList(.list) = $0 { true } else { false }
        })
      {
        throw .code(.listOfLists)
      }

      if let termDef = activeContext.termDefinitions[term], termDef.reverse {
        for v in expandedValues {
          guard case .node = v else { throw .code(.invalidReversePropertyValue) }
        }

        if property != "@reverse" {
          let newValues = expandedValues.map(\.jsonValue)
          var reverseMap: JSONObject =
            if let existingReverse = properties[.reverse] {
              if case .object(let existingMap) = existingReverse {
                existingMap
              } else {
                throw .internalError(.notObject)
              }
            } else {
              [:]
            }

          if let existing = reverseMap[expandedProperty] {
            if case .array(var arr) = existing {
              arr.append(contentsOf: newValues)
              reverseMap[expandedProperty] = .array(arr)
            } else {
              throw .internalError(.notObject)
            }
          } else {
            reverseMap[expandedProperty] = .array(newValues)
          }

          properties[.reverse] = .object(reverseMap)
          return
        }
      } else if property == "@reverse" {
        let newValues = expandedValues.map(\.jsonValue)
        var reverseMap: JSONObject =
          if let existingReverse = properties[.reverse] {
            if case .object(let existingMap) = existingReverse {
              existingMap
            } else {
              throw .internalError(.notObject)
            }
          } else {
            [:]
          }

        if let existing = reverseMap[expandedProperty] {
          if case .array(var arr) = existing {
            arr.append(contentsOf: newValues)
            reverseMap[expandedProperty] = .array(arr)
          } else {
            throw .internalError(.notObject)
          }
        } else {
          reverseMap[expandedProperty] = .array(newValues)
        }

        properties[.reverse] = .object(reverseMap)
        return
      }

      let finalValue: JSONValue =
        if container == .list {
          .array([
            .object([
              "@list": .array(self.listItems(for: expandedValues))
            ])
          ])
        } else {
          .array(expandedValues.map(\.jsonValue))
        }

      if let existing = properties[expandedProperty] {
        if case .array(var arr) = existing {
          if case .array(let newArr) = finalValue {
            arr.append(contentsOf: newArr)
          } else {
            arr.append(finalValue)
          }
          properties[expandedProperty] = .array(arr)
        } else {
          properties[expandedProperty] = .array([existing, finalValue])
        }
      } else {
        properties[expandedProperty] = finalValue
      }
    }
  }

  private static func finalizeExpandedObject(
    _ expandedProperties: inout JSONObject,
    property: String?,
    activeContext: ActiveContext
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    if let typeVal = expandedProperties[.type], case .array(let types) = typeVal, types.isEmpty {
      _ = expandedProperties.removeValue(for: .type)
    }

    if let valueVal = expandedProperties[.value] {
      for key in expandedProperties.keys {
        guard let k = JSONLDKeyword(rawValue: key) else { throw .code(.invalidValueObject) }
        if k != .value && k != .type && k != .language && k != .index {
          throw .code(.invalidValueObject)
        }
      }
      if expandedProperties.keys.contains("@language") && expandedProperties.keys.contains("@type")
      {
        throw .code(.invalidValueObject)
      }
      if case .null = valueVal { return nil }
      if expandedProperties.keys.contains("@language") {
        if case .string = valueVal {} else { throw .code(.invalidLanguageTaggedValue) }
      }
      if let typeVal = expandedProperties[.type] {
        if case .array(let types) = typeVal {
          if types.count > 1 { throw .code(.invalidTypedValue) }
          if let first = types.first, case .string = first {
            expandedProperties[.type] = first
          } else {
            throw .code(.invalidTypedValue)
          }
        }
      }

      // If property is null or @graph, and it's a value object, it's dropped.
      if property == nil || property == "@graph" {
        return nil
      }

      return try .value(.init(from: .object(expandedProperties)))
    }

    if expandedProperties[.list] != nil {
      if expandedProperties.count > (expandedProperties.keys.contains("@index") ? 2 : 1) {
        throw .code(.invalidSetOrListObject)
      }
      // If property is null or @graph, and it's a list object, it's dropped.
      if property == nil || property == "@graph" {
        return nil
      }
      return try .setOrList(.init(from: .object(expandedProperties)))
    }

    if let setVal = expandedProperties[.set] {
      if expandedProperties.count > (expandedProperties.keys.contains("@index") ? 2 : 1) {
        throw .code(.invalidSetOrListObject)
      }
      // If property is null or @graph, and it's a set object, return its @set value.
      if property == nil || property == "@graph" {
        return try .setOrList(.set(.init(from: setVal), context: nil, index: nil))
      }
      return try .setOrList(.init(from: .object(expandedProperties)))
    }

    if property == nil || property == "@graph",
      expandedProperties.count == 1,
      let graph = expandedProperties[.graph],
      case .array(let graphValues) = graph,
      graphValues.isEmpty
    {
      return nil
    }

    if property == nil || property == "@graph", expandedProperties.isEmpty,
      expandedProperties[.id] == nil, expandedProperties[.graph] == nil
    {
      return nil
    }

    // If result contains only @language or only @index, it's dropped.
    if expandedProperties.count == 1,
      expandedProperties.keys.contains("@language") || expandedProperties.keys.contains("@index")
    {
      return nil
    }

    // If result is a node object and it is a free-floating node, result is set to null.
    // A node object is free-floating if it consists only of an @id entry.
    if property == nil || property == "@graph",
      expandedProperties.count == 1, expandedProperties.keys.contains("@id")
    {
      return nil
    }

    return try .node(.init(from: .object(expandedProperties)))
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

  private static func listItems(for values: [JSONLDValue<Expanded>]) -> [JSONValue] {
    if values.count == 1, case .setOrList(.list(let listValues, _, _)) = values[0] {
      listValues.map(\.jsonValue)
    } else {
      values.map(\.jsonValue)
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

extension JSONLDValue where P == Expanded {
  fileprivate init(_ value: SetOrListObject.Element) {
    self =
      switch value {
      case .string(let s): .iriOrTerm(s)
      case .integer(let i): .value(.init(value: .integer(i)))
      case .float(let f): .value(.init(value: .float(f)))
      case .boolean(let b): .value(.init(value: .boolean(b)))
      case .null: .invalid(.notJSONLDValue)
      case .nodeObject(let n): .node(n)
      case .valueObject(let v): .value(v)
      }
  }
}

extension JSONLDValue where P == Unresolved {
  fileprivate init(_ value: SetOrListObject.Element) {
    self =
      switch value {
      case .string(let s): .iriOrTerm(s)
      case .integer(let i): .value(.init(value: .integer(i)))
      case .float(let f): .value(.init(value: .float(f)))
      case .boolean(let b): .value(.init(value: .boolean(b)))
      case .null: .invalid(.notJSONLDValue)
      case .nodeObject(let n): .node(n)
      case .valueObject(let v): .value(v)
      }
  }
}

extension JSONLDValue.SetOrListObject.Element where P == Expanded {
  fileprivate init(_ value: JSONLDValue<Expanded>) {
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
