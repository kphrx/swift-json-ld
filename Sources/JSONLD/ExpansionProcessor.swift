// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum ExpansionProcessor {
  static func expand(
    _ activeContext: ActiveContext,
    value: SingleOrMany<JSONLDValue<Unresolved>>,
    property: String?,
    insideList: Bool = false
  ) throws(JSONLDError) -> [JSONLDValue<Expanded>] {
    var result: [JSONLDValue<Expanded>] = []
    for item in value {
      if let expanded = try self.expand(
        activeContext, value: item, property: property, insideList: insideList)
      {
        if case .setOrList(let setOrList) = expanded, case .set(let values, _, _) = setOrList {
          for v in values {
            result.append(JSONLDValue<Expanded>(v))
          }
        } else {
          result.append(expanded)
        }
      }
    }
    return result
  }

  private static func expand(
    _ activeContext: ActiveContext,
    value: JSONLDValue<Unresolved>,
    property: String?,
    insideList: Bool = false
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    switch value {
    case .unknown(let content):
      return try self.expandObject(
        activeContext, object: content, property: property, insideList: insideList)

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
            return try .node(NodeObject<Expanded>(from: .object(["@id": .string(expandedId)])))
          }
          if typeMapping == "@vocab" {
            let expandedId = try mutableContext.expandIRI(string, asVocab: true)
            return try .node(NodeObject<Expanded>(from: .object(["@id": .string(expandedId)])))
          }
          return try .value(
            ValueObject<Expanded>(
              from: .object(["@value": .string(string), "@type": .string(typeMapping)])))
        } else if let languageMapping = mutableContext.languageMapping(for: property) {
          return try .value(
            ValueObject<Expanded>(
              from: .object(["@value": .string(string), "@language": .string(languageMapping)])))
        }
      }
      return try .value(ValueObject<Expanded>(from: .object(["@value": .string(string)])))

    case .node(let nodeObject):
      var activeContext = activeContext
      if let localContext = nodeObject.context {
        activeContext = try activeContext.process(localContext: localContext)
      }

      var combinedProperties = nodeObject.properties
      if let id = nodeObject.id { combinedProperties["@id"] = .single(.iriOrTerm(id)) }
      if let types = nodeObject.type {
        combinedProperties["@type"] = .many(types.map { .iriOrTerm($0) })
      }
      if let graph = nodeObject.graph {
        combinedProperties["@graph"] = .many(graph.map { .node($0) })
      }

      return try self.expandObject(
        activeContext, object: combinedProperties, property: property, insideList: insideList)

    case .value(_):
      return try self.expandObject(
        activeContext, object: ["@value": .single(.iriOrTerm("dummy"))], property: property,
        insideList: insideList)  // TODO: Proper re-expansion

    case .setOrList(let setOrListObject):
      switch setOrListObject {
      case .set(let values, _, _):
        let unresolvedItems: [JSONLDValue<Unresolved>] = values.map { JSONLDValue<Unresolved>($0) }
        let expanded = try self.expand(
          activeContext, value: .many(unresolvedItems), property: property, insideList: insideList)
        return try JSONLDValue<Expanded>.setOrList(
          .set(.many(expanded.map { SetValue<Expanded>($0) }), context: nil, index: nil))
      case .list(let values, _, _):
        if insideList { throw .code(.listOfLists) }
        let unresolvedItems: [JSONLDValue<Unresolved>] = values.map { JSONLDValue<Unresolved>($0) }
        let expanded = try self.expand(
          activeContext, value: .many(unresolvedItems), property: property, insideList: true)
        return try JSONLDValue<Expanded>.setOrList(
          .list(.many(expanded.map { SetValue<Expanded>($0) }), context: nil, index: nil))
      }

    case .languageMap(let languageMap):
      var expandedItems: [JSONLDValue<Expanded>] = []
      for (lang, values) in languageMap.map.sorted(by: { $0.key < $1.key }) {
        for val in values {
          if case .string(let s) = val {
            expandedItems.append(
              try .value(
                .init(
                  from: .object(["@value": .string(s), "@language": .string(lang.lowercased())])))
            )
          }
        }
      }
      return .setOrList(
        .set(.many(expandedItems.map { SetValue<Expanded>($0) }), context: nil, index: nil))

    case .indexMap(let indexMap):
      var expandedItems: [JSONLDValue<Expanded>] = []
      for (_, values) in indexMap.map.sorted(by: { $0.key < $1.key }) {
        let unresolvedItems: [JSONLDValue<Unresolved>] = values.map { JSONLDValue<Unresolved>($0) }
        let expanded = try self.expand(
          activeContext, value: .many(unresolvedItems), property: property, insideList: insideList)
        expandedItems.append(contentsOf: expanded)
      }
      return .setOrList(
        .set(.many(expandedItems.map { SetValue<Expanded>($0) }), context: nil, index: nil))
    }
  }

  private static func expandObject(
    _ activeContext: ActiveContext,
    object: [String: SingleOrMany<JSONLDValue<Unresolved>>],
    property: String?,
    insideList: Bool
  ) throws(JSONLDError) -> JSONLDValue<Expanded>? {
    var object = object
    var activeContext = activeContext

    if let localContextValue = object.removeValue(forKey: JSONLDKeyword.context.rawValue) {
      activeContext = try activeContext.process(
        localContext: try .init(from: localContextValue.jsonValue))
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
          expandedTypes.append(.string(try validateIRI(expandedType, code: .invalidTypeMapping)))
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
        let expandedList = try self.expand(
          activeContext, value: val, property: property, insideList: true)

        for item in expandedList {
          if case .setOrList(.list) = item {
            throw .code(.listOfLists)
          }
        }
        expandedProperties[expandedProperty] = .array(expandedList.map(\.jsonValue))

      case .set?:
        let expandedSet = try self.expand(
          activeContext, value: val, property: property, insideList: insideList)
        expandedProperties[expandedProperty] = .array(expandedSet.map(\.jsonValue))

      case .graph?:
        let expandedGraph = try self.expand(
          activeContext, value: val, property: "@graph", insideList: false)
        expandedProperties[expandedProperty] = .array(expandedGraph.map(\.jsonValue))

      case .index?:
        guard case .single(.iriOrTerm(let indexStr)) = val else { throw .code(.invalidIndexValue) }
        expandedProperties[expandedProperty] = .string(indexStr)

      case .reverse?:
        if case .single(.unknown(let content)) = val,
          let expandedReverse = try self.expandObject(
            activeContext, object: content, property: "@reverse", insideList: false),
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
        let isListContainer = (container == .list)

        let expandedValues = try self.expand(
          activeContext, value: val, property: key, insideList: isListContainer || insideList)

        if !expandedValues.isEmpty {
          if let termDef = activeContext.termDefinitions[key], termDef.reverse {
            for v in expandedValues {
              guard case .node = v else { throw .code(.invalidReversePropertyValue) }
            }
          }

          let finalValue: JSONValue =
            if isListContainer {
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
