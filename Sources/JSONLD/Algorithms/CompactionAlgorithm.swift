// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct CompactionAlgorithm {
  struct Options {
    let baseIRI: String?
    let compactArrays: Bool
    let compactToRelative: Bool
  }

  private typealias Container = Contexts.ContextDefinition.ExpandedTermDefinition.Container

  private struct TermDef {
    let term: String
    let iri: String
    let type: String?
    let language: String?
    let languageDefined: Bool
    let container: Container?
    let reverse: Bool
    let isSimpleTerm: Bool
  }

  private let options: Options
  private let contextValue: JSONValue
  private let termDefs: [String: TermDef]
  private let iriToTerms: [String: [TermDef]]
  private let keywordAliases: [JSONLDKeyword: String]
  private let vocabMapping: String?
  private let baseIRI: String?
  private let defaultLanguage: String?

  init(activeContext: ActiveContext, contextValue: JSONValue, options: Options) {
    self.options = options
    self.contextValue = contextValue
    let contextObject = Self.mergedContextObject(from: self.contextValue)
    self.baseIRI = Self.stringValue(contextObject[.base]) ?? options.baseIRI
    self.vocabMapping = Self.resolveVocabMapping(contextObject, baseIRI: self.baseIRI)
    self.defaultLanguage = Self.stringValue(contextObject[.language])?
      .lowercased()

    let simpleTerms = Self.simpleTerms(from: contextObject)
    let termDefs = Self.termDefinitions(from: activeContext, simpleTerms: simpleTerms)
    self.termDefs = Dictionary(uniqueKeysWithValues: termDefs.map { ($0.term, $0) })

    self.iriToTerms = .init(grouping: termDefs) { $0.iri }
    self.keywordAliases = .init(
      uniqueKeysWithValues: self.iriToTerms.compactMap { key, value in
        if let keyword = JSONLDKeyword(rawValue: key),
          let term = value.min(by: { $0.term < $1.term })?.term
        {
          (keyword, term)
        } else {
          nil
        }
      }
    )
  }

  private static func termDefinitions(
    from activeContext: ActiveContext,
    simpleTerms: Set<String>
  ) -> [TermDef] {
    activeContext.termDefinitions.map { term, definition in
      let container: Container? =
        if definition.containerMapping == .null {
          nil
        } else {
          definition.containerMapping
        }
      return TermDef(
        term: term,
        iri: definition.iri,
        type: definition.typeMapping,
        language: definition.languageMapping,
        languageDefined: definition.languageMappingDefined,
        container: container,
        reverse: definition.reverse,
        isSimpleTerm: simpleTerms.contains(term)
      )
    }
  }

  private static func simpleTerms(from context: JSONObject) -> Set<String> {
    Set(
      context.compactMap { key, value in
        if case .string = value, !key.hasPrefix("@") {
          key
        } else {
          nil
        }
      }
    )
  }

  func compact<P: JSONLDPhase>(
    _ values: JSONLDValues<P>
  ) throws(JSONLDError) -> JSONLDDocument<Compacted> {
    let input = values.jsonValue
    let elements: [JSONValue] =
      switch input {
      case .array(let array): array
      default: [input]
      }

    var compactedItems: [JSONLDValue<Compacted>] = []
    compactedItems.reserveCapacity(elements.count)
    for value in elements {
      if let compacted = try self.compactElement(value, activeProperty: nil) {
        for item in compacted.values {
          if case .node(let node) = item, self.isTopLevelFreeFloatingNode(node) {
            continue
          }
          compactedItems.append(item)
        }
      }
    }

    if compactedItems.isEmpty {
      return .init(.single(.init()))
    }

    if !self.options.compactArrays || compactedItems.count != 1 {
      let graphEntry: JSONLDValue<Compacted>.NodeObject.GraphEntry = (
        term: self.term(for: .graph),
        value: .many(compactedItems)
      )
      let node = try self.addTopLevelContext(
        .init(graph: graphEntry)
      )
      return .init(.single(node))
    }

    let item = compactedItems[0]
    return switch item {
    case .node(let node):
      .init(.single(try self.addTopLevelContext(node)))
    default:
      try .init(validating: item.jsonValue)
    }
  }

  private func compactElement(
    _ value: JSONValue,
    activeProperty: String?
  ) throws(JSONLDError) -> CompactedItem? {
    switch value {
    case .null:
      return nil
    case .array(let array):
      var compacted: [JSONLDValue<Compacted>] = []
      compacted.reserveCapacity(array.count)
      for item in array {
        if let value = try self.compactElement(item, activeProperty: activeProperty) {
          compacted.append(contentsOf: value.values)
        }
      }
      return if self.options.compactArrays && compacted.count == 1 {
        .single(compacted[0])
      } else {
        .array(compacted)
      }
    case .object(let object):
      if object[.value] != nil {
        return .single(try self.compactValueObject(object, activeProperty: activeProperty))
      }
      if let list = object[.list] {
        guard case .array(let items) = list else {
          return .single(.setOrList(try .init(from: object)))
        }
        if items.contains(where: Self.isListObject) {
          throw .code(.compactionToListOfLists)
        }
        var compactedItems: [JSONLDValue<Compacted>] = []
        compactedItems.reserveCapacity(items.count)
        for item in items {
          if let compacted = try self.compactElement(item, activeProperty: activeProperty) {
            if compacted.isArray {
              throw .code(.compactionToListOfLists)
            }
            if compacted.values.contains(where: Self.isListObject) {
              throw .code(.compactionToListOfLists)
            }
            compactedItems.append(contentsOf: compacted.values)
          }
        }
        let hasIndex = object[.index] != nil
        if let property = activeProperty,
          let def = self.termDefs[property],
          def.container == .list,
          !hasIndex
        {
          return if self.options.compactArrays && compactedItems.count == 1 {
            .single(compactedItems[0])
          } else {
            .array(compactedItems)
          }
        }
        let elements = try compactedItems.map(Self.setOrListElement(from:))
        let indexValue = Self.stringValue(object[.index])
        let indexTerm = indexValue.flatMap { _ in self.term(for: .index) }
        return .single(
          .setOrList(
            .init(
              term: self.term(for: .list),
              value: .list(.many(elements)),
              index: indexValue,
              indexTerm: indexTerm
            )
          )
        )
      }
      if let set = object[.set] {
        guard case .array(let items) = set else {
          return .single(.setOrList(try .init(from: object)))
        }
        var compactedItems: [JSONLDValue<Compacted>] = []
        compactedItems.reserveCapacity(items.count)
        for item in items {
          if let compacted = try self.compactElement(item, activeProperty: activeProperty) {
            if !compacted.isNullSingle {
              compactedItems.append(contentsOf: compacted.values)
            }
          }
        }
        return .array(compactedItems)
      }
      if object[.id] != nil && object.count == 1 {
        let id = Self.stringValue(object[.id]) ?? ""
        if let property = activeProperty,
          let def = self.termDefs[property]
        {
          if def.type == JSONLDKeyword.vocab.rawValue {
            return .single(.iriOrTerm(self.compactIRI(id, vocab: true)))
          }
          if def.type == JSONLDKeyword.id.rawValue {
            return .single(.iriOrTerm(self.compactIRI(id, vocab: false)))
          }
        }
      }
      return .single(.node(try self.compactNodeObject(object)))
    default:
      return .single(Self.compactedScalarValue(from: value))
    }
  }

  private struct NodeBuilder {
    var context: JSONLDValue<Compacted>.NodeObject.ContextEntry?
    var id: JSONLDValue<Compacted>.NodeObject.IdEntry?
    var graph: JSONLDValue<Compacted>.NodeObject.GraphEntry?
    var type: JSONLDValue<Compacted>.NodeObject.TypeEntry?
    var reverse: JSONLDValue<Compacted>.NodeObject.ReverseEntry?
    var index: JSONLDValue<Compacted>.NodeObject.IndexEntry?
    var properties: [String: SingleOrMany<JSONLDValue<Compacted>>] = [:]
  }

  private func compactNodeObject(
    _ object: JSONObject
  ) throws(JSONLDError) -> JSONLDValue<Compacted>.NodeObject {
    var builder = NodeBuilder()
    for (expandedProperty, expandedValue) in object.sorted(by: { $0.key < $1.key }) {
      switch JSONLDKeyword(rawValue: expandedProperty) {
      case .id?:
        self.compactIdKeyword(expandedValue, into: &builder)

      case .type?:
        self.compactTypeKeyword(expandedValue, into: &builder)

      case .index?:
        self.compactIndexKeyword(expandedValue, into: &builder)

      case .graph?:
        try self.compactGraphKeyword(expandedValue, into: &builder)

      case .reverse?:
        try self.compactReverseKeyword(expandedValue, into: &builder)

      case nil:
        try self.compactProperty(
          expandedValue,
          into: &builder,
          expandedProperty: expandedProperty
        )

      default:
        continue
      }
    }

    return .init(
      context: builder.context,
      id: builder.id,
      graph: builder.graph,
      type: builder.type,
      reverse: builder.reverse,
      index: builder.index,
      properties: builder.properties
    )
  }

  private func compactIdKeyword(
    _ value: JSONValue,
    into builder: inout NodeBuilder,
  ) {
    if let id = Self.stringValue(value) {
      builder.id = (term: self.term(for: .id), value: self.compactIRI(id, vocab: false))
    }
  }

  private func compactTypeKeyword(
    _ value: JSONValue,
    into builder: inout NodeBuilder,
  ) {
    if case .array(let types) = value {
      let compactedTypes = types.compactMap(Self.stringValue).map {
        self.compactIRI($0, vocab: true)
      }
      let typeValue: SingleOrMany<String> =
        if self.options.compactArrays, compactedTypes.count == 1 {
          .single(compactedTypes[0])
        } else {
          .many(compactedTypes)
        }
      builder.type = (term: self.term(for: .type), value: typeValue)
    }
  }

  private func compactIndexKeyword(
    _ value: JSONValue,
    into builder: inout NodeBuilder,
  ) {
    if let index = Self.stringValue(value) {
      builder.index = (term: self.term(for: .index), value: index)
    }
  }

  private func compactGraphKeyword(
    _ value: JSONValue,
    into builder: inout NodeBuilder,
  ) throws(JSONLDError) {
    let values =
      switch value {
      case .array(let values): values
      default: [value]
      }
    var compacted: [JSONLDValue<Compacted>] = []
    compacted.reserveCapacity(values.count)
    for v in values {
      if let item = try self.compactElement(
        v,
        activeProperty: self.term(for: .graph) ?? JSONLDKeyword.graph.rawValue
      ) {
        compacted.append(contentsOf: item.values)
      }
    }
    builder.graph = (term: self.term(for: .graph), value: .many(compacted))
  }

  private func compactReverseKeyword(
    _ value: JSONValue,
    into builder: inout NodeBuilder
  ) throws(JSONLDError) {
    guard case .object(let reverseObject) = value else {
      throw .code(.invalidReversePropertyMap)
    }
    var compactedReverse: [String: SingleOrMany<JSONLDValue<Compacted>>] = [:]
    for (reverseProperty, reverseValue) in reverseObject {
      guard case .array(let values) = reverseValue else { continue }

      let grouped = try self.groupAndCompactValues(
        iri: reverseProperty,
        values: values,
        reverse: true
      )

      for (term, group) in grouped.sorted(by: { $0.key < $1.key }) {
        let compactedValues = group.compacted
        let originalValues = group.original

        if self.termDefs[term]?.reverse == true {
          let def = self.termDefs[term]
          let existingValues = Self.arrayValue(builder.properties[term])
          let mergedValues = existingValues + compactedValues

          if def?.container == .index,
            let indexMap = try self.compactIndexMap(originalValues, activeProperty: term)
          {
            builder.properties[term] = .single(.indexMap(indexMap))
            continue
          }

          let shouldUseArray =
            group.forceArray
            || !self.options.compactArrays
            || mergedValues.count != 1
            || def?.container == .set
            || def?.container == .list
          builder.properties[term] =
            if shouldUseArray {
              .many(mergedValues)
            } else {
              .single(mergedValues[0])
            }
        } else {
          let shouldUseArray =
            group.forceArray
            || !self.options.compactArrays
            || compactedValues.count != 1
          let compactedValue: SingleOrMany<JSONLDValue<Compacted>> =
            if shouldUseArray {
              .many(compactedValues)
            } else {
              .single(compactedValues[0])
            }
          if let existing = compactedReverse[term] {
            let merged = Self.arrayValue(existing) + Self.arrayValue(compactedValue)
            compactedReverse[term] = .many(merged)
          } else {
            compactedReverse[term] = compactedValue
          }
        }
      }
    }
    if !compactedReverse.isEmpty {
      let reverseMap = ReversePropertyMap<Compacted>(map: compactedReverse)
      builder.reverse = (term: self.term(for: .reverse), value: reverseMap)
    }
  }

  private func compactProperty(
    _ value: JSONValue,
    into builder: inout NodeBuilder,
    expandedProperty: String
  ) throws(JSONLDError) {
    if (self.iriToTerms[expandedProperty] ?? []).isEmpty && !Self.isAbsoluteIRI(expandedProperty) {
      return
    }

    let values: [JSONValue] =
      switch value {
      case .array(let values): values
      default: [value]
      }

    if values.isEmpty {
      let term = self.selectTerm(
        iri: expandedProperty,
        value: value,
        containerHint: nil,
        reverse: false
      )
      builder.properties[term] = .many([])
      return
    }

    let grouped = try self.groupAndCompactValues(
      iri: expandedProperty,
      values: values,
      reverse: false
    )

    for (term, group) in grouped.sorted(by: { $0.key < $1.key }) {
      let def = self.termDefs[term]
      let compactedValues = group.compacted
      let originalValues = group.original

      if def?.container == .index,
        let indexMap = try self.compactIndexMap(originalValues, activeProperty: term)
      {
        builder.properties[term] = .single(.indexMap(indexMap))
        continue
      }
      if def?.container == .language,
        let languageMap = self.compactLanguageMap(originalValues)
      {
        builder.properties[term] = .single(.languageMap(languageMap))
        continue
      }

      if compactedValues.isEmpty, !group.forceArray, def?.container != .set,
        def?.container != .list
      {
        continue
      }

      let shouldUseArray =
        group.forceArray
        || !self.options.compactArrays
        || compactedValues.count != 1
        || def?.container == .set
        || def?.container == .list
      builder.properties[term] =
        if shouldUseArray {
          .many(compactedValues)
        } else {
          .single(compactedValues[0])
        }
    }
  }

  private struct CompactedItem: Equatable {
    let values: [JSONLDValue<Compacted>]
    let isArray: Bool

    static func single(_ value: JSONLDValue<Compacted>) -> Self {
      .init(values: [value], isArray: false)
    }

    static func array(_ values: [JSONLDValue<Compacted>]) -> Self {
      .init(values: values, isArray: true)
    }

    var isNullSingle: Bool {
      !self.isArray && self.values.count == 1 && self.values[0] == .null
    }

    func asSingleOrMany() -> SingleOrMany<JSONLDValue<Compacted>> {
      if self.isArray {
        .many(self.values)
      } else if self.values.count == 1 {
        .single(self.values[0])
      } else {
        .many(self.values)
      }
    }
  }

  private struct ValueGroup {
    var original: [JSONValue] = []
    var compacted: [JSONLDValue<Compacted>] = []
    var forceArray: Bool = false
  }

  private func groupAndCompactValues(
    iri: String,
    values: [JSONValue],
    reverse: Bool
  ) throws(JSONLDError) -> [String: ValueGroup] {
    var grouped: [String: ValueGroup] = [:]
    for item in values {
      let term = self.selectTerm(
        iri: iri,
        value: .array([item]),
        containerHint: nil,
        reverse: reverse
      )
      var group = grouped[term, default: .init()]
      group.original.append(item)
      if let compacted = try self.compactElement(item, activeProperty: term) {
        if !compacted.isNullSingle {
          group.compacted.append(contentsOf: compacted.values)
          group.forceArray = group.forceArray || compacted.isArray
        }
      }
      grouped[term] = group
    }
    return grouped
  }

  private func compactIndexMap(
    _ values: [JSONValue],
    activeProperty: String?
  ) throws(JSONLDError) -> JSONLDValue<Compacted>.IndexMap? {
    var map: [String: SingleOrMany<JSONLDValue<Compacted>.IndexMap.Value>] = [:]
    for value in values {
      guard case .object(let object) = value,
        let index = Self.stringValue(object[.index])
      else {
        return nil
      }

      var compactedValue = object
      _ = compactedValue.removeValue(for: .index)
      guard
        let compacted = try self.compactElement(
          .object(compactedValue),
          activeProperty: activeProperty
        )
      else {
        continue
      }
      if compacted.isNullSingle {
        continue
      }

      let mappedValues = try compacted.values.map(Self.indexMapValue(from:))
      let newValue: SingleOrMany<JSONLDValue<Compacted>.IndexMap.Value> =
        if compacted.isArray {
          .many(mappedValues)
        } else if mappedValues.count == 1 {
          .single(mappedValues[0])
        } else {
          .many(mappedValues)
        }

      if let existing = map[index] {
        let merged = Self.arrayValue(existing) + mappedValues
        map[index] = .many(merged)
      } else {
        map[index] = newValue
      }
    }
    return .init(map: map)
  }

  private func compactLanguageMap(_ values: [JSONValue]) -> JSONLDValue<Compacted>.LanguageMap? {
    var map: [String: SingleOrMany<JSONLDValue<Compacted>.LanguageMap.Value>] = [:]
    for value in values {
      guard case .object(let object) = value,
        let language = Self.stringValue(object[.language]),
        let text = Self.stringValue(object[.value]),
        object[.type] == nil,
        object[.index] == nil
      else {
        return nil
      }

      let existing = map[language]
      let newValue = JSONLDValue<Compacted>.LanguageMap.Value.string(text)
      if let existing {
        let merged = Self.arrayValue(existing) + [newValue]
        map[language] = .many(merged)
      } else {
        map[language] = .single(newValue)
      }
    }
    return .init(map: map)
  }

  private func compactValueObject(
    _ object: JSONObject,
    activeProperty: String?
  ) throws(JSONLDError) -> JSONLDValue<Compacted> {
    guard let value = object[.value] else {
      return .node(try self.compactNodeObject(object))
    }
    let type = Self.stringValue(object[.type])
    let language = Self.stringValue(object[.language])
    let index = object[.index]
    let valueObjectValue = try JSONLDValue<Compacted>.ValueObject.Value(from: value)
    let valueTerm = self.term(for: .value)
    let typeTerm = self.term(for: .type)
    let languageTerm = self.term(for: .language)
    let indexTerm = self.term(for: .index)

    func expandedValueObject(
      type: String?,
      language: String?,
      indexValue: JSONValue?
    ) throws(JSONLDError) -> JSONLDValue<Compacted> {
      let typeEntry: JSONLDValue<Compacted>.ValueObject.TypeEntry? =
        if let type {
          (term: nil, value: try .init(type))
        } else {
          nil
        }
      let languageEntry: JSONLDValue<Compacted>.ValueObject.LanguageEntry? =
        language.map { (term: nil, value: $0) }
      let indexEntry: JSONLDValue<Compacted>.ValueObject.IndexEntry? =
        try indexValue.map { indexValue throws(JSONLDError) in
          guard let index = Self.stringValue(indexValue) else {
            throw .code(.invalidIndexValue)
          }
          return (term: nil, value: index)
        }
      return .value(
        .init(
          value: (term: nil, value: valueObjectValue),
          type: typeEntry,
          language: languageEntry,
          context: nil,
          index: indexEntry
        )
      )
    }

    if type == nil, language == nil {
      if let index {
        guard let indexValue = Self.stringValue(index) else {
          throw .code(.invalidIndexValue)
        }
        return .value(
          .init(
            value: (term: valueTerm, value: valueObjectValue),
            type: nil,
            language: nil,
            context: nil,
            index: (term: indexTerm, value: indexValue)
          )
        )
      }
      let isStringValue =
        if case .string = value {
          true
        } else {
          false
        }
      if self.defaultLanguage != nil, let property = activeProperty {
        if let def = self.termDefs[property] {
          if def.type == nil, !def.languageDefined, isStringValue {
            return .value(.init(value: (term: valueTerm, value: valueObjectValue)))
          }
        } else if isStringValue {
          return .value(.init(value: (term: valueTerm, value: valueObjectValue)))
        }
      }
      return Self.compactedScalarValue(from: value)
    }

    if let property = activeProperty, let def = self.termDefs[property] {
      if let type, def.type == type {
        return if index != nil {
          try expandedValueObject(type: type, language: nil, indexValue: index)
        } else {
          Self.compactedScalarValue(from: value)
        }
      }
      if let language, def.type == nil, def.container != .language {
        if def.language == language.lowercased() {
          return if index != nil {
            try expandedValueObject(type: nil, language: language, indexValue: index)
          } else {
            Self.compactedScalarValue(from: value)
          }
        }
        if def.language == nil, self.defaultLanguage == language.lowercased() {
          return if index != nil {
            try expandedValueObject(type: nil, language: language, indexValue: index)
          } else {
            Self.compactedScalarValue(from: value)
          }
        }
      }
    }

    let typeEntry: JSONLDValue<Compacted>.ValueObject.TypeEntry? =
      if let type {
        (term: typeTerm, value: try .init(self.compactIRI(type, vocab: true)))
      } else {
        nil
      }
    let languageEntry: JSONLDValue<Compacted>.ValueObject.LanguageEntry? =
      language.map { (term: languageTerm, value: $0) }
    let indexEntry: JSONLDValue<Compacted>.ValueObject.IndexEntry? =
      try index.map { indexValue throws(JSONLDError) in
        guard let index = Self.stringValue(indexValue) else {
          throw .code(.invalidIndexValue)
        }
        return (term: indexTerm, value: index)
      }
    return .value(
      .init(
        value: (term: valueTerm, value: valueObjectValue),
        type: typeEntry,
        language: languageEntry,
        context: nil,
        index: indexEntry
      )
    )
  }

  private func compactIRI(_ iri: String, vocab: Bool) -> String {
    if !vocab, self.options.compactToRelative, let base = self.baseIRI,
      let baseURL = URL(string: base), let iriURL = URL(string: iri),
      let relative = self.relativeIRI(from: iriURL, base: baseURL)
    {
      return relative
    }

    if vocab {
      if let defs = self.iriToTerms[iri], let term = defs.map(\.term).sorted().first {
        return term
      }
      if let compact = self.compactWithTerms(iri, includeVocab: true) {
        return compact
      }
      if self.shouldUseRelativeCompactionForVocab(iri),
        let base = self.baseIRI,
        let baseURL = URL(string: base),
        let iriURL = URL(string: iri),
        let relative = self.relativeIRI(from: iriURL, base: baseURL)
      {
        return relative
      }
    } else if let compact = self.compactWithTerms(iri, includeVocab: false) {
      return compact
    }
    if !vocab, self.options.compactToRelative, let base = self.baseIRI,
      let baseURL = URL(string: base), let iriURL = URL(string: iri)
    {
      if let relative = self.relativeIRI(from: iriURL, base: baseURL) {
        return relative
      }
    }
    return iri
  }

  private func compactWithTerms(_ iri: String, includeVocab: Bool) -> String? {
    if includeVocab, let vocabMapping = self.vocabMapping, !vocabMapping.isEmpty,
      iri.hasPrefix(vocabMapping)
    {
      let suffix = String(iri.dropFirst(vocabMapping.count))
      if !suffix.isEmpty, JSONLDKeyword(rawValue: suffix) == nil, self.termDefs[suffix] == nil {
        return suffix
      }
    }

    return self.termDefs.values.compactMap {
      guard !$0.reverse, iri.hasPrefix($0.iri), iri != $0.iri else { return nil }
      let suffix = String(iri.dropFirst($0.iri.count))
      guard !suffix.hasPrefix("//"),
        $0.isSimpleTerm && !suffix.isEmpty || !$0.isSimpleTerm && suffix.hasPrefix("/")
      else { return nil }
      return "\($0.term):\(suffix)"
    }.min { $0.count < $1.count || ($0.count == $1.count && $0 < $1) }
  }

  private func shouldUseRelativeCompactionForVocab(_ iri: String) -> Bool {
    if !self.options.compactToRelative { return false }
    if self.vocabMapping != "" { return false }
    guard let base = self.baseIRI, let baseURL = URL(string: base), let iriURL = URL(string: iri),
      let baseComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
      let iriComponents = URLComponents(url: iriURL, resolvingAgainstBaseURL: false)
    else {
      return false
    }
    if baseComponents.scheme != iriComponents.scheme || baseComponents.host != iriComponents.host
      || baseComponents.port != iriComponents.port || baseComponents.user != iriComponents.user
      || baseComponents.password != iriComponents.password
    {
      return false
    }
    return iriComponents.path.hasPrefix(baseComponents.path)
  }

  private func relativeIRI(from iriURL: URL, base baseURL: URL) -> String? {
    guard let iri = URLComponents(url: iriURL, resolvingAgainstBaseURL: false),
      let base = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    else {
      return nil
    }

    if iri.scheme != base.scheme || iri.host != base.host || iri.port != base.port
      || iri.user != base.user || iri.password != base.password
    {
      return nil
    }

    if iri.path == base.path {
      if let fragment = iri.percentEncodedFragment {
        return "#\(fragment)"
      }
      if let query = iri.percentEncodedQuery {
        return "?\(query)"
      }
    }

    let baseDirectory = Self.baseDirectoryPath(base.path)
    let baseSegments = Self.pathSegments(baseDirectory)
    let iriSegments = Self.pathSegments(iri.path)

    var common = 0
    while common < baseSegments.count && common < iriSegments.count
      && baseSegments[common] == iriSegments[common]
    {
      common += 1
    }

    let upCount = baseSegments.count - common
    let remaining = iriSegments[common...]

    var relativeParts: [String] = Array(repeating: "..", count: upCount)
    relativeParts.append(contentsOf: remaining)

    var relative = relativeParts.joined(separator: "/")
    if relative.isEmpty {
      relative =
        iri.path == base.path ? (iri.path.split(separator: "/").last.map(String.init) ?? "") : ""
    }
    if iri.path.hasSuffix("/") && !relative.isEmpty && !relative.hasSuffix("/") {
      relative += "/"
    }
    if let query = iri.percentEncodedQuery {
      relative += "?\(query)"
    }
    if let fragment = iri.percentEncodedFragment {
      relative += "#\(fragment)"
    }
    return relative
  }

  private func term(for keyword: JSONLDKeyword) -> String? {
    self.keywordAliases[keyword]
  }

  private func selectTerm(
    iri: String,
    value: JSONValue,
    containerHint: Container?,
    reverse: Bool
  ) -> String {
    guard let iriCandidates = self.iriToTerms[iri] else {
      if let compact = self.compactWithTerms(iri, includeVocab: true) {
        return compact
      }
      return self.compactIRI(iri, vocab: true)
    }
    let isListValue = Self.singleListItems(value) != nil
    var candidates = iriCandidates
    if !isListValue {
      let nonList = iriCandidates.filter { $0.container != .list }
      if !nonList.isEmpty {
        candidates = nonList
      }
    }

    if candidates.count == 1, let candidate = candidates.first,
      candidate.languageDefined, candidate.container != .language,
      let valueLanguage = Self.singleValueObjectLanguage(value), candidate.language != valueLanguage
    {
      return self.compactWithTerms(iri, includeVocab: true) ?? iri
    }

    if Self.containsListObjectWithIndex(value) {
      let nonListCandidates = candidates.filter { $0.container != .list }
      if nonListCandidates.isEmpty {
        return self.compactWithTerms(iri, includeVocab: true) ?? iri
      }
      return self.bestTerm(from: nonListCandidates, value: value, containerHint: containerHint)
    }

    if let listItems = Self.singleListItems(value) {
      let listCandidates = candidates.filter { $0.container == .list }
      if !listCandidates.isEmpty {
        if let type = Self.homogeneousType(in: listItems) {
          let typedCandidates = listCandidates.filter { $0.type == type }
          if !typedCandidates.isEmpty {
            return self.bestTerm(
              from: typedCandidates,
              value: value,
              containerHint: .list
            )
          }
        }
        if let language = Self.homogeneousLanguage(in: listItems) {
          let languageCandidates: [TermDef]
          if let unwrapped = language {
            languageCandidates = listCandidates.filter { $0.language == unwrapped.lowercased() }
          } else {
            let explicitNilLanguage = listCandidates.filter {
              $0.languageDefined && $0.language == nil
            }
            if explicitNilLanguage.isEmpty {
              languageCandidates = listCandidates.filter { $0.language == nil }
            } else {
              languageCandidates = explicitNilLanguage
            }
          }
          if !languageCandidates.isEmpty {
            return self.bestTerm(
              from: languageCandidates,
              value: value,
              containerHint: .list
            )
          }
        }
        let unconstrained = listCandidates.filter { $0.type == nil && !$0.languageDefined }
        if !unconstrained.isEmpty {
          return self.bestTerm(
            from: unconstrained,
            value: value,
            containerHint: .list
          )
        }
      }
    }

    if Self.allItemsContainIndex(value),
      !candidates.contains(where: { $0.container == .index }),
      candidates.contains(where: { $0.container == .language })
    {
      return self.compactWithTerms(iri, includeVocab: true) ?? iri
    }

    if let valueType = Self.valueTypeHint(value) {
      let constrained = candidates.filter { $0.type != nil }
      if !constrained.isEmpty, !constrained.contains(where: { $0.type == valueType }) {
        return self.compactWithTerms(iri, includeVocab: true) ?? iri
      }
    }

    let nonIDCandidates = candidates.filter { $0.type != JSONLDKeyword.id.rawValue }
    if Self.containsNonIRIString(value) {
      if !nonIDCandidates.isEmpty {
        return self.bestTerm(from: nonIDCandidates, value: value, containerHint: containerHint)
      }
      return iri
    }

    if reverse {
      let reverseCandidates = candidates.filter(\.reverse)
      if !reverseCandidates.isEmpty {
        return self.bestTerm(from: reverseCandidates, value: value, containerHint: containerHint)
      }
      return self.bestTerm(from: candidates, value: value, containerHint: containerHint)
    }

    let forwardCandidates = candidates.filter { !$0.reverse }
    if !forwardCandidates.isEmpty {
      return self.bestTerm(from: forwardCandidates, value: value, containerHint: containerHint)
    }
    return iri
  }

  private static func containsListObjectWithIndex(_ value: JSONValue) -> Bool {
    switch value {
    case .array(let array):
      array.contains(where: Self.containsListObjectWithIndex)
    case .object(let object):
      object[.list] != nil && object[.index] != nil
    default:
      false
    }
  }

  private static func singleListItems(_ value: JSONValue) -> [JSONValue]? {
    let object: JSONObject
    switch value {
    case .array(let array):
      guard array.count == 1, case .object(let unwrapped) = array[0] else { return nil }
      object = unwrapped
    case .object(let unwrapped):
      object = unwrapped
    default:
      return nil
    }
    guard case .array(let items)? = object[.list] else { return nil }
    return items
  }

  private static func homogeneousType(in items: [JSONValue]) -> String? {
    if items.isEmpty { return nil }
    var seen: String?
    for item in items {
      guard case .object(let object) = item,
        let type = Self.stringValue(object[.type])
      else {
        return nil
      }
      if let seen, seen != type { return nil }
      seen = type
    }
    return seen
  }

  private static func homogeneousLanguage(in items: [JSONValue]) -> String?? {
    if items.isEmpty { return nil }
    var seen: String??
    for item in items {
      let language: String??
      switch item {
      case .string, .integer, .float, .boolean, .null:
        language = .some(nil)
      case .object(let object):
        guard object[.value] != nil else { return nil }
        language = .some(Self.stringValue(object[.language])?.lowercased())
      default:
        return nil
      }
      if let seen, seen != language { return nil }
      seen = language
    }
    return seen
  }

  private static func singleValueObjectLanguage(_ value: JSONValue) -> String? {
    switch value {
    case .array(let array):
      guard array.count == 1, case .object(let object) = array[0],
        object[.value] != nil
      else {
        return nil
      }
      return Self.stringValue(object[.language])?.lowercased()
    case .object(let object):
      guard object[.value] != nil else { return nil }
      return Self.stringValue(object[.language])?.lowercased()
    default:
      return nil
    }
  }

  private static func allItemsContainIndex(_ value: JSONValue) -> Bool {
    switch value {
    case .array(let array):
      if array.isEmpty { return false }
      return array.allSatisfy {
        if case .object(let object) = $0 {
          return object[.index] != nil
        }
        return false
      }
    case .object(let object):
      return object[.index] != nil
    default:
      return false
    }
  }

  private func bestTerm(
    from candidates: [TermDef],
    value: JSONValue,
    containerHint: Container?
  ) -> String {
    let sorted = candidates.sorted { a, b in
      let scoreA = self.scoreTerm(a, value: value, containerHint: containerHint)
      let scoreB = self.scoreTerm(b, value: value, containerHint: containerHint)
      if scoreA != scoreB { return scoreA < scoreB }
      if a.term.count == b.term.count { return a.term < b.term }
      return a.term.count < b.term.count
    }
    if case .array(let values) = value, values.count == 1, case .object(let obj) = values[0],
      let id = Self.stringValue(obj[.id])
    {
      if let vocabMatch = sorted.first(where: {
        $0.type == JSONLDKeyword.vocab.rawValue && self.iriToTerms[id] != nil
      }) {
        return vocabMatch.term
      }
      if let idMatch = sorted.first(where: { $0.type == JSONLDKeyword.id.rawValue }) {
        return idMatch.term
      }
    }
    return
      if let containerHint,
      let containerMatch = sorted.first(where: { $0.container == containerHint })
    {
      containerMatch.term
    } else {
      sorted.first?.term ?? candidates[0].term
    }
  }

  private func scoreTerm(
    _ candidate: TermDef,
    value: JSONValue,
    containerHint: Container?
  ) -> (Int, Int, Int, String) {
    let containerPriority: Int =
      if let containerHint, candidate.container == containerHint {
        0
      } else if containerHint == nil {
        1
      } else {
        2
      }

    let valuePriority: Int =
      switch value {
      case .array(let array):
        if array.count > 1
          && array.allSatisfy({ $0[.index] != nil })
        {
          candidate.container == .index ? 0 : 2
        } else if array.count > 1
          && array.allSatisfy({ $0[.language] != nil })
        {
          candidate.container == .language ? 0 : 2
        } else if array.count == 1, case .object(let obj) = array[0],
          let type = Self.stringValue(obj[.type])
        {
          candidate.type == type ? 0 : 2
        } else if array.count == 1, case .object(let obj) = array[0],
          obj[.id] != nil
        {
          candidate.type == JSONLDKeyword.id.rawValue
            || candidate.type == JSONLDKeyword.vocab.rawValue ? 0 : 2
        } else if array.count == 1, case .object(let obj) = array[0],
          obj[.value] != nil
        {
          if let language = Self.stringValue(obj[.language]) {
            if candidate.container == .language {
              0
            } else if candidate.type == nil, candidate.container != .index {
              if candidate.languageDefined {
                if let candidateLanguage = candidate.language {
                  candidateLanguage == language.lowercased() ? 0 : 2
                } else {
                  2
                }
              } else if self.defaultLanguage == nil || self.defaultLanguage == language.lowercased()
              {
                0
              } else {
                1
              }
            } else {
              2
            }
          } else if candidate.type != nil {
            2
          } else if candidate.languageDefined {
            candidate.language == nil ? 0 : 2
          } else if self.defaultLanguage != nil {
            1
          } else {
            0
          }
        } else {
          1
        }
      case .object(let object):
        if object[.index] != nil {
          candidate.container == .index ? 0 : 2
        } else if let type = Self.stringValue(object[.type]) {
          candidate.type == type ? 0 : 2
        } else if let language = Self.stringValue(object[.language]) {
          if candidate.container == .language {
            0
          } else if candidate.type == nil, candidate.container != .index {
            if candidate.languageDefined {
              if let candidateLanguage = candidate.language {
                candidateLanguage == language.lowercased() ? 0 : 2
              } else {
                2
              }
            } else if self.defaultLanguage == nil || self.defaultLanguage == language.lowercased() {
              0
            } else {
              1
            }
          } else {
            2
          }
        } else if object[.value] != nil {
          if candidate.type != nil {
            2
          } else if candidate.languageDefined {
            candidate.language == nil ? 0 : 2
          } else if self.defaultLanguage != nil {
            1
          } else {
            0
          }
        } else {
          1
        }
      default:
        1
      }

    let reversePriority = candidate.reverse ? 0 : 1
    return (containerPriority, valuePriority, reversePriority, candidate.term)
  }

  private static func parseTermDefinitions(_ context: JSONObject) throws(JSONLDError) -> [TermDef] {
    var defs: [String: TermDef] = [:]

    func expandIRI(_ value: String, context: JSONObject, seen: Set<String> = []) -> String {
      if JSONLDKeyword(rawValue: value) != nil { return value }
      if let colon = value.firstIndex(of: ":") {
        let prefix = String(value[..<colon])
        let suffix = String(value[value.index(after: colon)...])
        if let prefixDef = Self.stringValue(context[prefix]) {
          let expandedPrefix = expandIRI(prefixDef, context: context, seen: seen.union([prefix]))
          if expandedPrefix.hasPrefix("@") { return value }
          return expandedPrefix + suffix
        }
        return value
      }
      if seen.contains(value) { return value }
      if let mapped = Self.stringValue(context[value]) {
        return expandIRI(mapped, context: context, seen: seen.union([value]))
      }
      if let vocab = Self.stringValue(context[.vocab]) {
        return vocab + value
      }
      return value
    }

    for (term, value) in context {
      if term.hasPrefix("@") { continue }
      switch value {
      case .string(let iri):
        defs[term] = .init(
          term: term,
          iri: expandIRI(iri, context: context),
          type: nil,
          language: nil,
          languageDefined: false,
          container: nil,
          reverse: false,
          isSimpleTerm: true
        )
      case .object(let object):
        let languageValue = Self.stringValue(object[.language])?.lowercased()
        let languageDefined = object[.language] != nil
        let typeValue = Self.stringValue(object[.type]).map { type in
          if type == JSONLDKeyword.id.rawValue || type == JSONLDKeyword.vocab.rawValue {
            return type
          }
          return expandIRI(type, context: context)
        }
        let container: Container?
        if let containerValue = object[.container] {
          let mapping = try Container(from: containerValue)
          container = mapping == .null ? nil : mapping
        } else {
          container = nil
        }
        if let reverse = Self.stringValue(object[.reverse]) {
          defs[term] = .init(
            term: term,
            iri: expandIRI(reverse, context: context),
            type: typeValue,
            language: languageValue,
            languageDefined: languageDefined,
            container: container,
            reverse: true,
            isSimpleTerm: false
          )
        } else if let id = Self.stringValue(object[.id]) {
          defs[term] = .init(
            term: term,
            iri: expandIRI(id, context: context),
            type: typeValue,
            language: languageValue,
            languageDefined: languageDefined,
            container: container,
            reverse: false,
            isSimpleTerm: false
          )
        } else {
          defs[term] = .init(
            term: term,
            iri: expandIRI(term, context: context),
            type: typeValue,
            language: languageValue,
            languageDefined: languageDefined,
            container: container,
            reverse: false,
            isSimpleTerm: false
          )
        }
      case .null:
        defs[term] = nil
      default:
        continue
      }
    }

    return Array(defs.values)
  }

  private static func resolveVocabMapping(_ context: JSONObject, baseIRI: String?) -> String? {
    guard let vocab = Self.stringValue(context[.vocab]) else { return nil }
    if vocab.isEmpty || vocab.contains(":") { return vocab }
    guard let baseIRI, let baseURL = URL(string: baseIRI),
      let resolved = URL(string: vocab, relativeTo: baseURL)
    else {
      return vocab
    }
    return resolved.absoluteURL.absoluteString
  }

  private static func stringValue(_ value: JSONValue?) -> String? {
    guard case .string(let string)? = value else { return nil }
    return string
  }

  static func validateInvalidCompactionInputs(
    _ values: JSONLDValues<Unresolved>
  ) throws(JSONLDError) {
    for value in values.value {
      try Self.validateInvalidCompactionInput(value)
    }
  }

  private static func validateInvalidCompactionInput(
    _ value: JSONLDValue<Unresolved>
  ) throws(JSONLDError) {
    switch value {
    case .invalid(.listOfLists):
      throw .code(.compactionToListOfLists)
    case .node(let node):
      if let graph = node.graph {
        for child in graph {
          try Self.validateInvalidCompactionInput(child)
        }
      }
      if let reverse = node.reverse {
        for values in reverse.map.values {
          for child in values {
            try Self.validateInvalidCompactionInput(child)
          }
        }
      }
      for values in node.properties.values {
        for child in values {
          try Self.validateInvalidCompactionInput(child)
        }
      }
    case .setOrList(let setOrList):
      for child in setOrList.value {
        try Self.validateInvalidCompactionInput(.init(child))
      }
    case .indexMap(let indexMap):
      for values in indexMap.map.values {
        for child in values {
          try Self.validateInvalidCompactionInput(.init(child))
        }
      }
    default:
      break
    }
  }

  private static func arrayValue(_ value: JSONValue?) -> [JSONValue] {
    switch value {
    case .array(let array)?:
      array
    case let scalar?:
      [scalar]
    case .none:
      []
    }
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

  private static func isListObject(_ value: JSONValue) -> Bool {
    guard case .object(let object) = value else { return false }
    return object[.list] != nil
  }

  private static func isListObject(_ value: JSONLDValue<Compacted>) -> Bool {
    if case .setOrList(let object) = value {
      if case .list = object.value {
        return true
      }
    }
    return false
  }

  private static func compactedScalarValue(from value: JSONValue) -> JSONLDValue<Compacted> {
    switch value {
    case .string(let string):
      .iriOrTerm(string)
    case .integer(let integer):
      .integer(integer)
    case .float(let float):
      .float(float)
    case .boolean(let boolean):
      .boolean(boolean)
    case .null:
      .null
    default:
      .invalid(.notJSONLDValue)
    }
  }

  private static func setOrListElement(
    from value: JSONLDValue<Compacted>
  ) throws(JSONLDError) -> JSONLDValue<Compacted>.SetOrListObject.Element {
    switch value {
    case .iriOrTerm(let string):
      .string(string)
    case .integer(let integer):
      .integer(integer)
    case .float(let float):
      .float(float)
    case .boolean(let boolean):
      .boolean(boolean)
    case .null:
      .null
    case .node(let node):
      .nodeObject(node)
    case .value(let value):
      .valueObject(value)
    case .setOrList, .languageMap, .indexMap, .unknown, .invalid:
      throw .code(.listOfLists)
    }
  }

  private static func indexMapValue(
    from value: JSONLDValue<Compacted>
  ) throws(JSONLDError) -> JSONLDValue<Compacted>.IndexMap.Value {
    switch value {
    case .iriOrTerm(let string):
      .string(string)
    case .integer(let integer):
      .integer(integer)
    case .float(let float):
      .float(float)
    case .boolean(let boolean):
      .boolean(boolean)
    case .null:
      .null
    case .node(let node):
      .nodeObject(node)
    case .value(let value):
      .valueObject(value)
    case .setOrList(let object):
      .setOrListObject(object)
    case .languageMap, .indexMap, .unknown, .invalid:
      throw .code(.invalidIndexValue)
    }
  }

  private static func isAbsoluteIRI(_ value: String) -> Bool {
    if let colonIndex = value.firstIndex(of: ":"), colonIndex != value.startIndex {
      let scheme = value[..<colonIndex]
      guard scheme.first?.isLetter == true else { return false }
      return scheme.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
    }
    return false
  }

  private func addTopLevelContext(
    _ node: JSONLDValue<Compacted>.NodeObject
  ) throws(JSONLDError) -> JSONLDValue<Compacted>.NodeObject {
    guard !node.jsonObject.isEmpty else {
      return node
    }
    guard Self.isMeaningfulContext(self.contextValue) else {
      return node
    }
    let context = try Contexts(from: self.contextValue)
    let contextEntry: JSONLDValue<Compacted>.NodeObject.ContextEntry = (
      term: self.term(for: .context),
      value: context
    )
    return .init(
      context: contextEntry,
      id: node.idEntry,
      graph: node.graphEntry,
      type: node.typeEntry,
      reverse: node.reverseEntry,
      index: node.indexEntry,
      properties: node.properties
    )
  }

  private func isTopLevelFreeFloatingNode(_ node: JSONLDValue<Compacted>.NodeObject) -> Bool {
    node.properties.isEmpty
      && node.context == nil
      && node.graph == nil
      && node.type == nil
      && node.reverse == nil
      && node.index == nil
      && node.id != nil
  }

  private static func baseDirectoryPath(_ path: String) -> String {
    if path.hasSuffix("/") { return path }
    guard let slash = path.lastIndex(of: "/") else { return "" }
    return String(path[..<path.index(after: slash)])
  }

  private static func pathSegments(_ path: String) -> [String] {
    path.split(separator: "/").map(String.init)
  }

  private static func valueTypeHint(_ value: JSONValue) -> String? {
    if case .object(let object) = value {
      Self.stringValue(object[.type])
    } else if case .array(let array) = value,
      array.count == 1,
      case .object(let object) = array[0]
    {
      Self.stringValue(object[.type])
    } else {
      nil
    }
  }

  private static func containsNonIRIString(_ value: JSONValue) -> Bool {
    func isIRIish(_ string: String) -> Bool {
      if string.hasPrefix("_:") { return true }
      if string.hasPrefix("/") || string.hasPrefix("./") || string.hasPrefix("../") { return true }
      if string.hasPrefix("#") || string.hasPrefix("?") { return true }
      if string.contains(":") { return true }
      return false
    }

    return switch value {
    case .string(let string):
      !isIRIish(string)
    case .array(let array):
      array.contains { item in
        if case .string(let string) = item {
          return !isIRIish(string)
        }
        if case .object(let object) = item,
          let string = Self.stringValue(object[.value]),
          object[.type] == nil,
          object[.language] == nil
        {
          return !isIRIish(string)
        }
        return false
      }
    default:
      false
    }
  }

  private static func mergedContextObject(from value: JSONValue) -> JSONObject {
    switch value {
    case .object(let object):
      return object
    case .array(let array):
      var merged: JSONObject = [:]
      for item in array {
        if case .object(let object) = item {
          for (key, value) in object {
            merged[key] = value
          }
        }
      }
      return merged
    default:
      return [:]
    }
  }

  private static func isMeaningfulContext(_ value: JSONValue) -> Bool {
    switch value {
    case .object(let object):
      !object.isEmpty
    case .array(let array):
      !array.isEmpty
    case .null:
      false
    default:
      true
    }
  }
}
