// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum ExpansionProcessor {
  static func expand(
    _ activeContext: ActiveContext,
    value: SingleOrMany<JSONLDValue<Unresolved>>,
    property: String?,
    insideList: Bool = false,
    loader: (any JSONLDDocumentLoader)? = nil,
    logger: (any JSONLDLogger)? = nil
  ) async throws(JSONLDError) -> [JSONLDValue<Expanded>] {
    var result: [JSONLDValue<Expanded>] = []
    for item in value {
      guard
        let expanded = try await self.expand(
          activeContext, value: item, property: property, insideList: insideList, loader: loader,
          logger: logger)
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
    loader: (any JSONLDDocumentLoader)? = nil,
    logger: (any JSONLDLogger)? = nil
  ) async throws(JSONLDError) -> JSONLDValue<Expanded>? {
    switch value {
    case .unknown(let content):
      return try await self.expandObject(
        activeContext, object: content, property: property, insideList: insideList, loader: loader,
        logger: logger)

    case .invalid(let invalid):
      switch invalid {
      case .listOfLists: throw .code(.listOfLists)
      case .notJSONLDValue: return nil
      }

    case .iriOrTerm(let string):
      if let property {
        var mutableContext = activeContext
        if let typeMapping = mutableContext.typeMapping(for: property) {
          if typeMapping == "@id" {
            let expandedId = try mutableContext.expandIRI(string, asDocumentRelative: true)
            return try .node(.init(from: .object(["@id": .string(expandedId)])))
          }
          if typeMapping == "@vocab" {
            let expandedId = try mutableContext.expandIRI(string, asVocab: true)
            return try .node(.init(from: .object(["@id": .string(expandedId)])))
          }
          return try .value(
            .init(from: .object(["@value": .string(string), "@type": .string(typeMapping)])))
        } else if let languageMapping = mutableContext.languageMapping(for: property) {
          return try .value(
            .init(
              from: .object(["@value": .string(string), "@language": .string(languageMapping)])))
        }
      }
      return try .value(.init(from: .object(["@value": .string(string)])))

    case .node(let nodeObject):
      var activeContext = activeContext
      if let localContext = nodeObject.context {
        activeContext = try await activeContext.process(
          localContext: localContext, loader: loader, logger: logger)
      }

      var combinedProperties = nodeObject.properties
      if let id = nodeObject.id { combinedProperties["@id"] = .single(.iriOrTerm(id)) }
      if let types = nodeObject.type {
        combinedProperties["@type"] = .many(types.map { .iriOrTerm($0) })
      }
      if let graph = nodeObject.graph {
        combinedProperties["@graph"] = .many(graph.map { .node($0) })
      }

      return try await self.expandObject(
        activeContext, object: combinedProperties, property: property, insideList: insideList,
        loader: loader, logger: logger)

    case .value(let valueObject):
      return .value(try .init(from: valueObject.jsonObject))

    case .setOrList(let setOrListObject):
      switch setOrListObject {
      case .set(let values, _, _):
        let unresolvedItems = values.map { JSONLDValue<Unresolved>($0) }
        let expanded = try await self.expand(
          activeContext, value: .many(unresolvedItems), property: property, insideList: insideList,
          loader: loader, logger: logger)
        return try .setOrList(
          .set(.many(expanded.map { .init($0) }), context: nil, index: nil))
      case .list(let values, _, _):
        if insideList { throw .code(.listOfLists) }
        let unresolvedItems = values.map { JSONLDValue<Unresolved>($0) }
        let expanded = try await self.expand(
          activeContext, value: .many(unresolvedItems), property: property, insideList: true,
          loader: loader, logger: logger)

        for item in expanded {
          if case .setOrList(.list) = item {
            throw .code(.listOfLists)
          }
        }

        return try .setOrList(
          .list(.many(expanded.map { .init($0) }), context: nil, index: nil))
      }

    case .languageMap(let languageMap):
      var expandedItems: [JSONLDValue<Expanded>] = []
      for (lang, values) in languageMap.map.sorted(by: { $0.key < $1.key }) {
        for val in values {
          guard case .string(let s) = val else { throw .code(.invalidLanguageMapValue) }
          expandedItems.append(
            try .value(
              .init(from: .object(["@value": .string(s), "@language": .string(lang.lowercased())])))
          )
        }
      }
      return .setOrList(
        .set(.many(expandedItems.map { .init($0) }), context: nil, index: nil))

    case .indexMap(let indexMap):
      var expandedItems: [JSONLDValue<Expanded>] = []
      for (_, values) in indexMap.map.sorted(by: { $0.key < $1.key }) {
        let unresolvedItems = values.map { JSONLDValue<Unresolved>($0) }
        let expanded = try await self.expand(
          activeContext, value: .many(unresolvedItems), property: property, insideList: insideList,
          loader: loader, logger: logger)
        expandedItems.append(contentsOf: expanded)
      }
      return .setOrList(
        .set(.many(expandedItems.map { .init($0) }), context: nil, index: nil))
    }
  }

  private static func expandObject(
    _ activeContext: ActiveContext,
    object: [String: SingleOrMany<JSONLDValue<Unresolved>>],
    property: String?,
    insideList: Bool,
    loader: (any JSONLDDocumentLoader)? = nil,
    logger: (any JSONLDLogger)? = nil
  ) async throws(JSONLDError) -> JSONLDValue<Expanded>? {
    var object = object
    var activeContext = activeContext

    if let localContextValue = object.removeValue(forKey: JSONLDKeyword.context.rawValue) {
      activeContext = try await activeContext.process(
        localContext: try .init(from: localContextValue.jsonValue), loader: loader, logger: logger)
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
        guard case .single(.iriOrTerm(let idStr)) = val else { throw .code(.invalidIdValue) }
        let expandedId = try activeContext.expandIRI(idStr, asDocumentRelative: true)
        expandedProperties[expandedProperty] = .string(expandedId)

      case .type?:
        var expandedTypes: [JSONValue] = []
        for item in val {
          guard case .iriOrTerm(let s) = item else { throw .code(.invalidTypeValue) }
          let expandedType = try activeContext.expandIRI(s, asVocab: true)
          expandedTypes.append(.string(expandedType))
        }
        expandedProperties[expandedProperty] = .array(expandedTypes)

      case .value?:
        let value = val.jsonValue
        if case .object = value { throw .code(.invalidValueObjectValue) }
        if case .array = value { throw .code(.invalidValueObjectValue) }
        expandedProperties[expandedProperty] = value

      case .language?:
        guard case .single(.iriOrTerm(let langStr)) = val else {
          throw .code(.invalidLanguageTaggedString)
        }
        expandedProperties[expandedProperty] = .string(langStr.lowercased())

      case .list?:
        if insideList { throw .code(.listOfLists) }
        let expandedList = try await self.expand(
          activeContext, value: val, property: property, insideList: true, loader: loader,
          logger: logger)

        for item in expandedList {
          if case .setOrList(.list) = item {
            throw .code(.listOfLists)
          }
        }
        expandedProperties[expandedProperty] = .array(expandedList.map(\.jsonValue))

      case .set?:
        let expandedSet = try await self.expand(
          activeContext, value: val, property: property, insideList: insideList, loader: loader,
          logger: logger)
        expandedProperties[expandedProperty] = .array(expandedSet.map(\.jsonValue))

      case .graph?:
        let expandedGraph = try await self.expand(
          activeContext, value: val, property: "@graph", insideList: false, loader: loader,
          logger: logger)
        expandedProperties[expandedProperty] = .array(expandedGraph.map(\.jsonValue))

      case .index?:
        guard case .single(.iriOrTerm(let indexStr)) = val else { throw .code(.invalidIndexValue) }
        expandedProperties[expandedProperty] = .string(indexStr)

      case .reverse?:
        if case .single(.unknown(let content)) = val,
          let expandedReverse = try await self.expandObject(
            activeContext, object: content, property: "@reverse", insideList: false, loader: loader,
            logger: logger),
          case .node(let node) = expandedReverse
        {
          expandedProperties[expandedProperty] = .object(node.jsonObject)
        } else {
          throw .code(.invalidReversePropertyMap)
        }

      case nil:
        if !expandedProperty.contains(":") && !expandedProperty.hasPrefix("_:") {
          continue
        }

        let container = activeContext.containerMapping(for: key)
        let expandedValues: [JSONLDValue<Expanded>]

        let isLanguageMap: Bool =
          if container == .language {
            switch val {
            case .single(.unknown), .single(.node): true
            default: false
            }
          } else {
            false
          }

        if isLanguageMap {
          let map: [String: SingleOrMany<JSONLDValue<Unresolved>>] =
            switch val {
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
                    ]))))
            }
          }
          expandedValues = values
        } else {
          let isListContainer = (container == .list)
          expandedValues = try await self.expand(
            activeContext, value: val, property: key, insideList: isListContainer || insideList,
            loader: loader, logger: logger)
        }

        if !expandedValues.isEmpty {
          if let termDef = activeContext.termDefinitions[key], termDef.reverse {
            for v in expandedValues {
              guard case .node = v else { throw .code(.invalidReversePropertyValue) }
            }
          }

          let finalValue: JSONValue =
            if container == .list {
              .object(["@list": .array(expandedValues.map(\.jsonValue))])
            } else {
              .array(expandedValues.map(\.jsonValue))
            }

          if let existing = expandedProperties[expandedProperty] {
            if case .array(var arr) = existing {
              if case .array(let newArr) = finalValue {
                arr.append(contentsOf: newArr)
              } else {
                arr.append(finalValue)
              }
              expandedProperties[expandedProperty] = .array(arr)
            } else {
              expandedProperties[expandedProperty] = .array([existing, finalValue])
            }
          } else {
            expandedProperties[expandedProperty] = finalValue
          }
        }

      default:
        continue
      }
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
          } else {
            throw .code(.invalidTypedValue)
          }
        }
      }

      return try .value(.init(from: .object(expandedProperties)))
    }

    if expandedProperties[.list] != nil {
      if expandedProperties.count > (expandedProperties.keys.contains("@index") ? 2 : 1) {
        throw .code(.invalidSetOrListObject)
      }
      return try .setOrList(.init(from: .object(expandedProperties)))
    }

    if expandedProperties.isEmpty && expandedProperties[.id] == nil
      && expandedProperties[.graph] == nil
    {
      return nil
    }

    return try .node(.init(from: .object(expandedProperties)))
  }

  private static func validateIRI(_ iri: String, code: JSONLDError.Code) throws(JSONLDError)
    -> String
  {
    if iri.contains(":") || JSONLDKeyword(rawValue: iri) != nil || iri.hasPrefix("_:") {
      return iri
    }
    throw .code(code)
  }
}

extension JSONLDValue where P == Expanded {
  fileprivate init(_ value: SetValue<Expanded>) {
    self =
      switch value {
      case .string(let s): .iriOrTerm(s)
      case .integer(let i): .value(try! .init(from: .object(["@value": .integer(i)])))
      case .float(let f): .value(try! .init(from: .object(["@value": .float(f)])))
      case .boolean(let b): .value(try! .init(from: .object(["@value": .boolean(b)])))
      case .null: .invalid(.notJSONLDValue)
      case .nodeObject(let n): .node(n)
      case .valueObject(let v): .value(v)
      }
  }
}

extension JSONLDValue where P == Unresolved {
  fileprivate init(_ value: SetValue<Unresolved>) {
    self =
      switch value {
      case .string(let s): .iriOrTerm(s)
      case .integer(let i): .value(try! .init(from: .object(["@value": .integer(i)])))
      case .float(let f): .value(try! .init(from: .object(["@value": .float(f)])))
      case .boolean(let b): .value(try! .init(from: .object(["@value": .boolean(b)])))
      case .null: .invalid(.notJSONLDValue)
      case .nodeObject(let n): .node(n)
      case .valueObject(let v): .value(v)
      }
  }
}

extension SetValue where P == Expanded {
  fileprivate init(_ value: JSONLDValue<Expanded>) {
    self =
      switch value {
      case .iriOrTerm(let s): .string(s)
      case .node(let n): .nodeObject(n)
      case .value(let v): .valueObject(v)
      case .setOrList, .languageMap, .indexMap, .unknown, .invalid:
        .null
      }
  }
}
