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
    let container: String?
    let reverse: Bool
  }

  private let options: Options
  private let contextValue: JSONValue
  private let termDefs: [String: TermDef]
  private let iriToTerms: [String: [TermDef]]
  private let keywordAliases: [String: String]

  init(context: JSONLDDocument<Unresolved>, options: Options) throws(JSONLDError) {
    self.options = options
    let firstNode = Array(context.value).first
    self.contextValue = firstNode?.context?.jsonValue ?? .object([:])
    let contextObject: JSONObject =
      if case .object(let object) = self.contextValue { object } else { [:] }

    let termDefs = try Self.parseTermDefinitions(contextObject)
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

  func compact(_ values: JSONLDValues<Unresolved>) throws(JSONLDError) -> JSONLDDocument<Unresolved>
  {
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
        compactedItems.append(compacted)
      }
    }

    let compacted: JSONValue =
      if compactedItems.isEmpty {
        .object([:])
      } else if compactedItems.count == 1 {
        compactedItems[0]
      } else {
        .object([self.alias(for: JSONLDKeyword.graph.rawValue): .array(compactedItems)])
      }

    guard case .object(var object) = compacted else {
      return try .init(from: compacted)
    }

    if !object.isEmpty {
      object[self.alias(for: JSONLDKeyword.context.rawValue)] = self.contextValue
    }
    return try .init(from: .object(object))
  }

  private func compactElement(_ value: JSONValue, activeProperty: String?) throws(JSONLDError)
    -> JSONValue?
  {
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
          return false
        }) {
          throw .code(.compactionToListOfLists)
        }
        if let property = activeProperty,
          let def = self.termDefs[property],
          def.container == JSONLDKeyword.list.rawValue
        {
          if self.options.compactArrays && compactedItems.count == 1 {
            return compactedItems[0]
          }
          return .array(compactedItems)
        }
        return .object([self.alias(for: JSONLDKeyword.list.rawValue): .array(compactedItems)])
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
      if expandedProperty == JSONLDKeyword.id.rawValue {
        let key = self.alias(for: expandedProperty)
        if let id = Self.stringValue(expandedValue) {
          result[key] = .string(self.compactIRI(id, vocab: false))
        }
        continue
      }

      if expandedProperty == JSONLDKeyword.type.rawValue {
        let key = self.alias(for: expandedProperty)
        if case .array(let types) = expandedValue {
          let compactedTypes = types.compactMap(Self.stringValue).map {
            self.compactIRI($0, vocab: true)
          }
          if self.options.compactArrays, compactedTypes.count == 1 {
            result[key] = .string(compactedTypes[0])
          } else {
            result[key] = .array(compactedTypes.map(JSONValue.string))
          }
        }
        continue
      }

      if expandedProperty == JSONLDKeyword.reverse.rawValue {
        guard case .object(let reverseObject) = expandedValue else {
          throw .code(.invalidReversePropertyMap)
        }
        var compactedReverse: JSONObject = [:]
        for (reverseProperty, reverseValue) in reverseObject {
          let term = self.selectTerm(
            iri: reverseProperty,
            value: reverseValue,
            containerHint: nil,
            reverse: true
          )
          guard case .array(let values) = reverseValue else { continue }
          var compactedValues: [JSONValue] = []
          compactedValues.reserveCapacity(values.count)
          for item in values {
            if let compacted = try self.compactElement(item, activeProperty: term) {
              compactedValues.append(compacted)
            }
          }
          compactedReverse[term] =
            if self.options.compactArrays && compactedValues.count == 1 {
              compactedValues[0]
            } else {
              .array(compactedValues)
            }
        }
        result[self.alias(for: JSONLDKeyword.reverse.rawValue)] = .object(compactedReverse)
        continue
      }

      let term = self.selectTerm(
        iri: expandedProperty, value: expandedValue, containerHint: nil, reverse: false)
      let def = self.termDefs[term]

      guard case .array(let values) = expandedValue else {
        result[term] = expandedValue
        continue
      }

      var compactedValues: [JSONValue] = []
      compactedValues.reserveCapacity(values.count)
      for item in values {
        if let compacted = try self.compactElement(item, activeProperty: term) {
          compactedValues.append(compacted)
        }
      }

      if def?.container == JSONLDKeyword.set.rawValue {
        var deduped: [JSONValue] = []
        for value in compactedValues where !deduped.contains(value) {
          deduped.append(value)
        }
        compactedValues = deduped
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

    return .object(result)
  }

  private func compactValueObject(_ object: JSONObject, activeProperty: String?) throws(JSONLDError)
    -> JSONValue
  {
    guard let value = object[JSONLDKeyword.value.rawValue] else { return .object(object) }
    let type = Self.stringValue(object[JSONLDKeyword.type.rawValue])
    let language = Self.stringValue(object[JSONLDKeyword.language.rawValue])
    if type == nil, language == nil {
      return value
    }

    if let property = activeProperty, let def = self.termDefs[property] {
      if let type, def.type == type {
        return value
      }
      if let language, def.type == nil, def.container != JSONLDKeyword.language.rawValue {
        _ = language
      }
    }

    var result: JSONObject = [self.alias(for: JSONLDKeyword.value.rawValue): value]
    if let type {
      result[self.alias(for: JSONLDKeyword.type.rawValue)] = .string(
        self.compactIRI(type, vocab: true))
    }
    if let language {
      result[self.alias(for: JSONLDKeyword.language.rawValue)] = .string(language)
    }
    return .object(result)
  }

  private func compactIRI(_ iri: String, vocab: Bool) -> String {
    if vocab, let defs = self.iriToTerms[iri], let term = defs.map(\.term).sorted().first {
      return term
    }
    if self.options.compactToRelative, let base = self.options.baseIRI,
      let baseURL = URL(string: base), let iriURL = URL(string: iri)
    {
      let basePath = baseURL.absoluteString
      let iriPath = iriURL.absoluteString
      if iriPath.hasPrefix(basePath) {
        return String(iriPath.dropFirst(basePath.count))
      }
    }
    return iri
  }

  private func alias(for keyword: String) -> String {
    self.keywordAliases[keyword] ?? keyword
  }

  private func selectTerm(iri: String, value: JSONValue, containerHint: String?, reverse: Bool)
    -> String
  {
    guard let candidates = self.iriToTerms[iri] else { return iri }
    if reverse {
      let reverseCandidates = candidates.filter(\.reverse)
      if !reverseCandidates.isEmpty {
        return self.bestTerm(from: reverseCandidates, value: value, containerHint: containerHint)
      }
    }
    return self.bestTerm(from: candidates, value: value, containerHint: containerHint)
  }

  private func bestTerm(from candidates: [TermDef], value: JSONValue, containerHint: String?)
    -> String
  {
    let sorted = candidates.sorted { a, b in
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

  private static func parseTermDefinitions(_ context: JSONObject) throws(JSONLDError) -> [TermDef] {
    var defs: [TermDef] = []

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
        defs.append(
          .init(
            term: term, iri: expandIRI(iri, context: context), type: nil, container: nil,
            reverse: false))
      case .object(let object):
        if let reverse = Self.stringValue(object[JSONLDKeyword.reverse.rawValue]) {
          defs.append(
            .init(
              term: term,
              iri: expandIRI(reverse, context: context),
              type: Self.stringValue(object[JSONLDKeyword.type.rawValue]),
              container: Self.stringValue(object[JSONLDKeyword.container.rawValue]),
              reverse: true
            ))
        } else if let id = Self.stringValue(object[JSONLDKeyword.id.rawValue]) {
          defs.append(
            .init(
              term: term,
              iri: expandIRI(id, context: context),
              type: Self.stringValue(object[JSONLDKeyword.type.rawValue]),
              container: Self.stringValue(object[JSONLDKeyword.container.rawValue]),
              reverse: false
            ))
        }
      default:
        continue
      }
    }

    return defs
  }

  private static func stringValue(_ value: JSONValue?) -> String? {
    guard case .string(let string)? = value else { return nil }
    return string
  }
}
