// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct CompactionAlgorithm {
  struct Options {
    let baseIRI: String?
    let compactArrays: Bool
    let compactToRelative: Bool
  }

  private struct TermDef {
    let term: String
    let iri: String
    let type: String?
    let language: String?
    let languageDefined: Bool
    let container: String?
    let reverse: Bool
    let isSimpleTerm: Bool
  }

  private let options: Options
  private let contextValue: JSONValue
  private let termDefs: [String: TermDef]
  private let iriToTerms: [String: [TermDef]]
  private let keywordAliases: [String: String]
  private let vocabMapping: String?
  private let baseIRI: String?
  private let defaultLanguage: String?

  init(activeContext: ActiveContext, contextValue: JSONValue, options: Options) {
    self.options = options
    self.contextValue = contextValue
    let contextObject = Self.mergedContextObject(from: self.contextValue)
    self.baseIRI = Self.stringValue(contextObject[JSONLDKeyword.base.rawValue]) ?? options.baseIRI
    self.vocabMapping = Self.resolveVocabMapping(contextObject, baseIRI: self.baseIRI)
    self.defaultLanguage = Self.stringValue(contextObject[JSONLDKeyword.language.rawValue])?
      .lowercased()

    let simpleTerms = Self.simpleTerms(from: contextObject)
    let termDefs = Self.termDefinitions(from: activeContext, simpleTerms: simpleTerms)
    self.termDefs = Dictionary(uniqueKeysWithValues: termDefs.map { ($0.term, $0) })

    var iriMap: [String: [TermDef]] = [:]
    var keywordAliases: [String: String] = [:]
    for def in termDefs {
      iriMap[def.iri, default: []].append(def)
      if JSONLDKeyword(rawValue: def.iri) != nil {
        keywordAliases[def.iri] = keywordAliases[def.iri].map { min($0, def.term) } ?? def.term
      }
    }
    self.iriToTerms = iriMap
    self.keywordAliases = keywordAliases
  }

  private static func termDefinitions(
    from activeContext: ActiveContext,
    simpleTerms: Set<String>
  ) -> [TermDef] {
    activeContext.termDefinitions.map { term, definition in
      .init(
        term: term,
        iri: definition.iri,
        type: definition.typeMapping,
        language: definition.languageMapping,
        languageDefined: definition.languageMappingDefined,
        container: definition.containerMapping.keyword?.rawValue,
        reverse: definition.reverse,
        isSimpleTerm: simpleTerms.contains(term)
      )
    }
  }

  private static func simpleTerms(from context: JSONObject) -> Set<String> {
    Set(
      context.compactMap { key, value in
        if key.hasPrefix("@") { return nil }
        if case .string = value { return key }
        return nil
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

    var compactedItems: [JSONValue] = []
    compactedItems.reserveCapacity(elements.count)
    for value in elements {
      if let compacted = try self.compactElement(value, activeProperty: nil) {
        if case .object(let object) = compacted, self.isTopLevelFreeFloatingNode(object) {
          continue
        }
        compactedItems.append(compacted)
      }
    }

    let compacted: JSONValue =
      if compactedItems.isEmpty {
        .object([:])
      } else if !self.options.compactArrays {
        .object([self.alias(for: JSONLDKeyword.graph.rawValue): .array(compactedItems)])
      } else if compactedItems.count == 1 {
        compactedItems[0]
      } else {
        .object([self.alias(for: JSONLDKeyword.graph.rawValue): .array(compactedItems)])
      }

    guard case .object(var object) = compacted else {
      return try .init(validating: compacted)
    }

    if !object.isEmpty {
      if Self.isMeaningfulContext(self.contextValue) {
        object[self.alias(for: JSONLDKeyword.context.rawValue)] = self.contextValue
      }
    }
    return try .init(validating: .object(object))
  }

  private func compactElement(
    _ value: JSONValue,
    activeProperty: String?
  ) throws(JSONLDError) -> JSONValue? {
    switch value {
    case .null:
      return nil
    case .array(let array):
      var compacted: [JSONValue] = []
      compacted.reserveCapacity(array.count)
      for item in array {
        if let value = try self.compactElement(item, activeProperty: activeProperty) {
          compacted.append(value)
        }
      }
      if self.options.compactArrays && compacted.count == 1 {
        return compacted[0]
      }
      return .array(compacted)
    case .object(let object):
      if object[JSONLDKeyword.value.rawValue] != nil {
        return try self.compactValueObject(object, activeProperty: activeProperty)
      }
      if let list = object[JSONLDKeyword.list.rawValue] {
        guard case .array(let items) = list else { return .object(object) }
        if items.contains(where: Self.isListObject) {
          throw .code(.compactionToListOfLists)
        }
        var compactedItems: [JSONValue] = []
        compactedItems.reserveCapacity(items.count)
        for item in items {
          if let compacted = try self.compactElement(item, activeProperty: activeProperty) {
            compactedItems.append(compacted)
          }
        }
        if compactedItems.contains(where: {
          if case .object(let obj) = $0, obj[self.alias(for: JSONLDKeyword.list.rawValue)] != nil {
            return true
          }
          if case .array = $0 {
            return true
          }
          return false
        }) {
          throw .code(.compactionToListOfLists)
        }
        let hasIndex = object[JSONLDKeyword.index.rawValue] != nil
        if let property = activeProperty,
          let def = self.termDefs[property],
          def.container == JSONLDKeyword.list.rawValue,
          !hasIndex
        {
          if self.options.compactArrays && compactedItems.count == 1 {
            return compactedItems[0]
          }
          return .array(compactedItems)
        }
        var compactedObject: JSONObject = [
          self.alias(for: JSONLDKeyword.list.rawValue): .array(compactedItems)
        ]
        if let index = object[JSONLDKeyword.index.rawValue] {
          compactedObject[self.alias(for: JSONLDKeyword.index.rawValue)] = index
        }
        return .object(compactedObject)
      }
      if let set = object[JSONLDKeyword.set.rawValue] {
        guard case .array(let items) = set else { return .object(object) }
        var compactedItems: [JSONValue] = []
        compactedItems.reserveCapacity(items.count)
        for item in items {
          if let compacted = try self.compactElement(item, activeProperty: activeProperty) {
            if compacted != .null {
              compactedItems.append(compacted)
            }
          }
        }
        if let property = activeProperty,
          let def = self.termDefs[property],
          def.container == JSONLDKeyword.set.rawValue
        {
          return .array(compactedItems)
        }
        return .array(compactedItems)
      }
      if object[JSONLDKeyword.id.rawValue] != nil && object.count == 1 {
        let id = Self.stringValue(object[JSONLDKeyword.id.rawValue]) ?? ""
        if let property = activeProperty,
          let def = self.termDefs[property]
        {
          if def.type == JSONLDKeyword.vocab.rawValue {
            return .string(self.compactIRI(id, vocab: true))
          }
          if def.type == JSONLDKeyword.id.rawValue {
            return .string(self.compactIRI(id, vocab: false))
          }
        }
      }
      return try self.compactNodeObject(object)
    default:
      return value
    }
  }

  private func compactNodeObject(_ object: JSONObject) throws(JSONLDError) -> JSONValue {
    var result: JSONObject = [:]
    for (expandedProperty, expandedValue) in object.sorted(by: { $0.key < $1.key }) {
      switch JSONLDKeyword(rawValue: expandedProperty) {
      case .id?:
        self.compactIdKeyword(expandedValue, into: &result, key: expandedProperty)

      case .type?:
        self.compactTypeKeyword(expandedValue, into: &result, key: expandedProperty)

      case .index?:
        self.compactIndexKeyword(expandedValue, into: &result, key: expandedProperty)

      case .graph?:
        try self.compactGraphKeyword(expandedValue, into: &result, key: expandedProperty)

      case .reverse?:
        try self.compactReverseKeyword(expandedValue, into: &result)

      case nil:
        try self.compactProperty(expandedValue, into: &result, expandedProperty: expandedProperty)

      default:
        continue
      }
    }

    return .object(result)
  }

  private func compactIdKeyword(
    _ value: JSONValue,
    into result: inout JSONObject,
    key: String
  ) {
    let alias = self.alias(for: key)
    if let id = Self.stringValue(value) {
      result[alias] = .string(self.compactIRI(id, vocab: false))
    }
  }

  private func compactTypeKeyword(
    _ value: JSONValue,
    into result: inout JSONObject,
    key: String
  ) {
    let alias = self.alias(for: key)
    if case .array(let types) = value {
      let compactedTypes = types.compactMap(Self.stringValue).map {
        self.compactIRI($0, vocab: true)
      }
      if self.options.compactArrays, compactedTypes.count == 1 {
        result[alias] = .string(compactedTypes[0])
      } else {
        result[alias] = .array(compactedTypes.map(JSONValue.string))
      }
    }
  }

  private func compactIndexKeyword(
    _ value: JSONValue,
    into result: inout JSONObject,
    key: String
  ) {
    result[self.alias(for: key)] = value
  }

  private func compactGraphKeyword(
    _ value: JSONValue,
    into result: inout JSONObject,
    key: String
  ) throws(JSONLDError) {
    let alias = self.alias(for: key)
    let values =
      switch value {
      case .array(let values): values
      default: [value]
      }
    var compacted: [JSONValue] = []
    compacted.reserveCapacity(values.count)
    for v in values {
      if let item = try self.compactElement(v, activeProperty: alias) {
        compacted.append(item)
      }
    }
    result[alias] = .array(compacted)
  }

  private func compactReverseKeyword(
    _ value: JSONValue,
    into result: inout JSONObject
  ) throws(JSONLDError) {
    guard case .object(let reverseObject) = value else {
      throw .code(.invalidReversePropertyMap)
    }
    var compactedReverse: JSONObject = [:]
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
          let existingValues = Self.arrayValue(result[term])
          let mergedValues = existingValues + compactedValues

          if def?.container == JSONLDKeyword.index.rawValue,
            let indexMap = try self.compactIndexMap(originalValues, activeProperty: term)
          {
            result[term] = .object(indexMap)
            continue
          }

          result[term] =
            if self.options.compactArrays && mergedValues.count == 1
              && def?.container != JSONLDKeyword.set.rawValue
            {
              mergedValues[0]
            } else {
              .array(mergedValues)
            }
        } else {
          let compacted =
            if self.options.compactArrays && compactedValues.count == 1 {
              compactedValues[0]
            } else {
              JSONValue.array(compactedValues)
            }
          if let existing = compactedReverse[term] {
            compactedReverse[term] = .array(
              Self.arrayValue(existing) + Self.arrayValue(compacted)
            )
          } else {
            compactedReverse[term] = compacted
          }
        }
      }
    }
    if !compactedReverse.isEmpty {
      result[self.alias(for: JSONLDKeyword.reverse.rawValue)] = .object(compactedReverse)
    }
  }

  private func compactProperty(
    _ value: JSONValue,
    into result: inout JSONObject,
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
      result[term] = .array([])
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

      if def?.container == JSONLDKeyword.index.rawValue,
        let indexMap = try self.compactIndexMap(originalValues, activeProperty: term)
      {
        result[term] = .object(indexMap)
        continue
      }
      if def?.container == JSONLDKeyword.language.rawValue,
        let languageMap = self.compactLanguageMap(originalValues)
      {
        result[term] = .object(languageMap)
        continue
      }

      if compactedValues.isEmpty, def?.container != JSONLDKeyword.set.rawValue,
        def?.container != JSONLDKeyword.list.rawValue
      {
        continue
      }

      result[term] =
        if self.options.compactArrays && compactedValues.count == 1
          && def?.container != JSONLDKeyword.set.rawValue
        {
          compactedValues[0]
        } else {
          .array(compactedValues)
        }
    }
  }

  private struct ValueGroup {
    var original: [JSONValue] = []
    var compacted: [JSONValue] = []
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
      grouped[term, default: .init()].original.append(item)
      if let compacted = try self.compactElement(item, activeProperty: term) {
        if compacted != .null {
          grouped[term, default: .init()].compacted.append(compacted)
        }
      }
    }
    return grouped
  }

  private func compactIndexMap(
    _ values: [JSONValue],
    activeProperty: String?
  ) throws(JSONLDError) -> JSONObject? {
    var map: JSONObject = [:]
    for value in values {
      guard case .object(let object) = value,
        let index = Self.stringValue(object[JSONLDKeyword.index.rawValue])
      else {
        return nil
      }

      var compactedValue = object
      compactedValue.removeValue(forKey: JSONLDKeyword.index.rawValue)
      let compacted =
        if let value = try self.compactElement(
          .object(compactedValue),
          activeProperty: activeProperty
        ) {
          value
        } else {
          JSONValue.null
        }
      if compacted == JSONValue.null {
        continue
      }
      if let existing = map[index] {
        map[index] =
          switch existing {
          case .array(let array):
            .array(array + [compacted])
          default:
            .array([existing, compacted])
          }
      } else {
        map[index] = compacted
      }
    }
    return map
  }

  private func compactLanguageMap(_ values: [JSONValue]) -> JSONObject? {
    var map: JSONObject = [:]
    for value in values {
      guard case .object(let object) = value,
        let language = Self.stringValue(object[JSONLDKeyword.language.rawValue]),
        let text = Self.stringValue(object[JSONLDKeyword.value.rawValue]),
        object[JSONLDKeyword.type.rawValue] == nil,
        object[JSONLDKeyword.index.rawValue] == nil
      else {
        return nil
      }

      let existing = map[language]
      map[language] =
        switch existing {
        case .array(let array):
          .array(array + [.string(text)])
        case .string(let string):
          .array([.string(string), .string(text)])
        default:
          .string(text)
        }
    }
    return map
  }

  private func compactValueObject(
    _ object: JSONObject,
    activeProperty: String?
  ) throws(JSONLDError) -> JSONValue {
    guard let value = object[JSONLDKeyword.value.rawValue] else { return .object(object) }
    let type = Self.stringValue(object[JSONLDKeyword.type.rawValue])
    let language = Self.stringValue(object[JSONLDKeyword.language.rawValue])
    let index = object[JSONLDKeyword.index.rawValue]
    if type == nil, language == nil {
      if let index {
        return .object([
          self.alias(for: JSONLDKeyword.value.rawValue): value,
          self.alias(for: JSONLDKeyword.index.rawValue): index,
        ])
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
            return .object([self.alias(for: JSONLDKeyword.value.rawValue): value])
          }
        } else if isStringValue {
          return .object([self.alias(for: JSONLDKeyword.value.rawValue): value])
        }
      }
      return value
    }

    if let property = activeProperty, let def = self.termDefs[property] {
      if let type, def.type == type {
        if index != nil { return .object(object) }
        return value
      }
      if let language, def.type == nil, def.container != JSONLDKeyword.language.rawValue {
        if def.language == language.lowercased() {
          if index != nil { return .object(object) }
          return value
        }
        if def.language == nil, self.defaultLanguage == language.lowercased() {
          if index != nil { return .object(object) }
          return value
        }
      }
    }

    var result: JSONObject = [self.alias(for: JSONLDKeyword.value.rawValue): value]
    if let type {
      result[self.alias(for: JSONLDKeyword.type.rawValue)] = .string(
        self.compactIRI(type, vocab: true)
      )
    }
    if let language {
      result[self.alias(for: JSONLDKeyword.language.rawValue)] = .string(language)
    }
    if let index {
      result[self.alias(for: JSONLDKeyword.index.rawValue)] = index
    }
    return .object(result)
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

    var best: String?
    for def in self.termDefs.values
    where !def.reverse && def.isSimpleTerm && iri.hasPrefix(def.iri) && iri != def.iri {
      let suffix = String(iri.dropFirst(def.iri.count))
      if suffix.hasPrefix("//") || suffix.isEmpty {
        continue
      }
      let compact = "\(def.term):\(suffix)"
      if best == nil || compact.count < best!.count
        || (compact.count == best!.count && compact < best!)
      {
        best = compact
      }
    }
    for def in self.termDefs.values
    where !def.reverse && !def.isSimpleTerm && iri.hasPrefix(def.iri) && iri != def.iri {
      let suffix = String(iri.dropFirst(def.iri.count))
      if !suffix.hasPrefix("/") || suffix.hasPrefix("//") {
        continue
      }
      let compact = "\(def.term):\(suffix)"
      if best == nil || compact.count < best!.count
        || (compact.count == best!.count && compact < best!)
      {
        best = compact
      }
    }

    if includeVocab, let vocabMapping = self.vocabMapping, !vocabMapping.isEmpty,
      iri.hasPrefix(vocabMapping)
    {
      let suffix = String(iri.dropFirst(vocabMapping.count))
      if !suffix.isEmpty, JSONLDKeyword(rawValue: suffix) == nil, self.termDefs[suffix] == nil {
        if best == nil || suffix.count < best!.count
          || (suffix.count == best!.count && suffix < best!)
        {
          best = suffix
        }
      }
    }

    return best
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

  private func alias(for keyword: String) -> String {
    self.keywordAliases[keyword] ?? keyword
  }

  private func selectTerm(
    iri: String,
    value: JSONValue,
    containerHint: String?,
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
      let nonList = iriCandidates.filter { $0.container != JSONLDKeyword.list.rawValue }
      if !nonList.isEmpty {
        candidates = nonList
      }
    }

    if candidates.count == 1, let candidate = candidates.first,
      candidate.languageDefined, candidate.container != JSONLDKeyword.language.rawValue,
      let valueLanguage = Self.singleValueObjectLanguage(value), candidate.language != valueLanguage
    {
      return self.compactWithTerms(iri, includeVocab: true) ?? iri
    }

    if Self.containsListObjectWithIndex(value) {
      let nonListCandidates = candidates.filter { $0.container != JSONLDKeyword.list.rawValue }
      if nonListCandidates.isEmpty {
        return self.compactWithTerms(iri, includeVocab: true) ?? iri
      }
      return self.bestTerm(from: nonListCandidates, value: value, containerHint: containerHint)
    }

    if let listItems = Self.singleListItems(value) {
      let listCandidates = candidates.filter { $0.container == JSONLDKeyword.list.rawValue }
      if !listCandidates.isEmpty {
        if let type = Self.homogeneousType(in: listItems) {
          let typedCandidates = listCandidates.filter { $0.type == type }
          if !typedCandidates.isEmpty {
            return self.bestTerm(
              from: typedCandidates,
              value: value,
              containerHint: JSONLDKeyword.list.rawValue
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
              containerHint: JSONLDKeyword.list.rawValue
            )
          }
        }
        let unconstrained = listCandidates.filter { $0.type == nil && !$0.languageDefined }
        if !unconstrained.isEmpty {
          return self.bestTerm(
            from: unconstrained,
            value: value,
            containerHint: JSONLDKeyword.list.rawValue
          )
        }
      }
    }

    if Self.allItemsContainIndex(value),
      !candidates.contains(where: { $0.container == JSONLDKeyword.index.rawValue }),
      candidates.contains(where: { $0.container == JSONLDKeyword.language.rawValue })
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
      return array.contains(where: Self.containsListObjectWithIndex)
    case .object(let object):
      return object[JSONLDKeyword.list.rawValue] != nil
        && object[JSONLDKeyword.index.rawValue] != nil
    default:
      return false
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
    guard case .array(let items)? = object[JSONLDKeyword.list.rawValue] else { return nil }
    return items
  }

  private static func homogeneousType(in items: [JSONValue]) -> String? {
    if items.isEmpty { return nil }
    var seen: String?
    for item in items {
      guard case .object(let object) = item,
        let type = Self.stringValue(object[JSONLDKeyword.type.rawValue])
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
        guard object[JSONLDKeyword.value.rawValue] != nil else { return nil }
        language = .some(Self.stringValue(object[JSONLDKeyword.language.rawValue])?.lowercased())
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
        object[JSONLDKeyword.value.rawValue] != nil
      else {
        return nil
      }
      return Self.stringValue(object[JSONLDKeyword.language.rawValue])?.lowercased()
    case .object(let object):
      guard object[JSONLDKeyword.value.rawValue] != nil else { return nil }
      return Self.stringValue(object[JSONLDKeyword.language.rawValue])?.lowercased()
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
          return object[JSONLDKeyword.index.rawValue] != nil
        }
        return false
      }
    case .object(let object):
      return object[JSONLDKeyword.index.rawValue] != nil
    default:
      return false
    }
  }

  private func bestTerm(
    from candidates: [TermDef],
    value: JSONValue,
    containerHint: String?
  ) -> String {
    let sorted = candidates.sorted { a, b in
      let scoreA = self.scoreTerm(a, value: value, containerHint: containerHint)
      let scoreB = self.scoreTerm(b, value: value, containerHint: containerHint)
      if scoreA != scoreB { return scoreA < scoreB }
      if a.term.count == b.term.count { return a.term < b.term }
      return a.term.count < b.term.count
    }
    if case .array(let values) = value, values.count == 1, case .object(let obj) = values[0],
      let id = Self.stringValue(obj[JSONLDKeyword.id.rawValue])
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
    if let containerHint,
      let containerMatch = sorted.first(where: { $0.container == containerHint })
    {
      return containerMatch.term
    }
    return sorted.first?.term ?? candidates[0].term
  }

  private func scoreTerm(
    _ candidate: TermDef,
    value: JSONValue,
    containerHint: String?
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
          && array.allSatisfy({ Self.hasKeyword($0, keyword: JSONLDKeyword.index.rawValue) })
        {
          candidate.container == JSONLDKeyword.index.rawValue ? 0 : 2
        } else if array.count > 1
          && array.allSatisfy({ Self.hasKeyword($0, keyword: JSONLDKeyword.language.rawValue) })
        {
          candidate.container == JSONLDKeyword.language.rawValue ? 0 : 2
        } else if array.count == 1, case .object(let obj) = array[0],
          let type = Self.stringValue(obj[JSONLDKeyword.type.rawValue])
        {
          candidate.type == type ? 0 : 2
        } else if array.count == 1, case .object(let obj) = array[0],
          obj[JSONLDKeyword.id.rawValue] != nil
        {
          candidate.type == JSONLDKeyword.id.rawValue
            || candidate.type == JSONLDKeyword.vocab.rawValue ? 0 : 2
        } else if array.count == 1, case .object(let obj) = array[0],
          obj[JSONLDKeyword.value.rawValue] != nil
        {
          if let language = Self.stringValue(obj[JSONLDKeyword.language.rawValue]) {
            if candidate.container == JSONLDKeyword.language.rawValue {
              0
            } else if candidate.type == nil, candidate.container != JSONLDKeyword.index.rawValue {
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
        if object[JSONLDKeyword.index.rawValue] != nil {
          candidate.container == JSONLDKeyword.index.rawValue ? 0 : 2
        } else if let type = Self.stringValue(object[JSONLDKeyword.type.rawValue]) {
          candidate.type == type ? 0 : 2
        } else if let language = Self.stringValue(object[JSONLDKeyword.language.rawValue]) {
          if candidate.container == JSONLDKeyword.language.rawValue {
            0
          } else if candidate.type == nil, candidate.container != JSONLDKeyword.index.rawValue {
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
        } else if object[JSONLDKeyword.value.rawValue] != nil {
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
      if let vocab = Self.stringValue(context[JSONLDKeyword.vocab.rawValue]) {
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
        let languageValue = Self.stringValue(object[JSONLDKeyword.language.rawValue])?.lowercased()
        let languageDefined = object[JSONLDKeyword.language.rawValue] != nil
        let typeValue = Self.stringValue(object[JSONLDKeyword.type.rawValue]).map { type in
          if type == JSONLDKeyword.id.rawValue || type == JSONLDKeyword.vocab.rawValue {
            return type
          }
          return expandIRI(type, context: context)
        }
        if let reverse = Self.stringValue(object[JSONLDKeyword.reverse.rawValue]) {
          defs[term] = .init(
            term: term,
            iri: expandIRI(reverse, context: context),
            type: typeValue,
            language: languageValue,
            languageDefined: languageDefined,
            container: Self.stringValue(object[JSONLDKeyword.container.rawValue]),
            reverse: true,
            isSimpleTerm: false
          )
        } else if let id = Self.stringValue(object[JSONLDKeyword.id.rawValue]) {
          defs[term] = .init(
            term: term,
            iri: expandIRI(id, context: context),
            type: typeValue,
            language: languageValue,
            languageDefined: languageDefined,
            container: Self.stringValue(object[JSONLDKeyword.container.rawValue]),
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
            container: Self.stringValue(object[JSONLDKeyword.container.rawValue]),
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
    guard let vocab = Self.stringValue(context[JSONLDKeyword.vocab.rawValue]) else { return nil }
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
      for child in setOrList.setOrListValues {
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
    case .array(let array):
      return array
    case .some(let scalar):
      return [scalar]
    case .none:
      return []
    }
  }

  private static func hasKeyword(_ value: JSONValue, keyword: String) -> Bool {
    guard case .object(let object) = value else { return false }
    return object[keyword] != nil
  }

  private static func isListObject(_ value: JSONValue) -> Bool {
    guard case .object(let object) = value else { return false }
    return object[JSONLDKeyword.list.rawValue] != nil
  }

  private static func isAbsoluteIRI(_ value: String) -> Bool {
    if let colonIndex = value.firstIndex(of: ":"), colonIndex != value.startIndex {
      let scheme = value[..<colonIndex]
      guard scheme.first?.isLetter == true else { return false }
      return scheme.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
    }
    return false
  }

  private func isTopLevelFreeFloatingNode(_ object: JSONObject) -> Bool {
    if object.count != 1 { return false }
    return object[self.alias(for: JSONLDKeyword.id.rawValue)] != nil
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
      return Self.stringValue(object[JSONLDKeyword.type.rawValue])
    }
    if case .array(let array) = value, array.count == 1, case .object(let object) = array[0] {
      return Self.stringValue(object[JSONLDKeyword.type.rawValue])
    }
    return nil
  }

  private static func containsNonIRIString(_ value: JSONValue) -> Bool {
    func isIRIish(_ string: String) -> Bool {
      if string.hasPrefix("_:") { return true }
      if string.hasPrefix("/") || string.hasPrefix("./") || string.hasPrefix("../") { return true }
      if string.hasPrefix("#") || string.hasPrefix("?") { return true }
      if string.contains(":") { return true }
      return false
    }

    switch value {
    case .string(let string):
      return !isIRIish(string)
    case .array(let array):
      return array.contains { item in
        if case .string(let string) = item {
          return !isIRIish(string)
        }
        if case .object(let object) = item,
          let string = Self.stringValue(object[JSONLDKeyword.value.rawValue]),
          object[JSONLDKeyword.type.rawValue] == nil,
          object[JSONLDKeyword.language.rawValue] == nil
        {
          return !isIRIish(string)
        }
        return false
      }
    default:
      return false
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
      return !object.isEmpty
    case .array(let array):
      return !array.isEmpty
    case .null:
      return false
    default:
      return true
    }
  }
}
