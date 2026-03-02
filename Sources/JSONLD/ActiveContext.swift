// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct ActiveContext: Equatable, Sendable {
  var baseIRI: String?
  var originalBaseIRI: String?
  var vocabMapping: String?
  var defaultLanguage: String?
  var termDefinitions: [String: TermDefinition]
  var nullTerms: Set<String>

  /// The maximum number of remote contexts that can be loaded recursively.
  static let maxRemoteContexts = 10

  static let empty = ActiveContext(
    baseIRI: nil,
    originalBaseIRI: nil,
    vocabMapping: nil,
    defaultLanguage: nil,
    termDefinitions: [:],
    nullTerms: []
  )

  init(
    baseIRI: String? = nil,
    originalBaseIRI: String? = nil,
    vocabMapping: String? = nil,
    defaultLanguage: String? = nil,
    termDefinitions: [String: TermDefinition] = [:],
    nullTerms: Set<String> = []
  ) {
    self.baseIRI = baseIRI
    self.originalBaseIRI = originalBaseIRI
    self.vocabMapping = vocabMapping
    self.defaultLanguage = defaultLanguage
    self.termDefinitions = termDefinitions
    self.nullTerms = nullTerms
  }

  func process(
    localContext: Contexts,
    remoteContexts: [String] = [],
    loader: (any JSONLDDocumentLoader)? = nil,
    logger: (any JSONLDLogger)? = nil
  ) async throws(JSONLDError) -> ActiveContext {
    var result = self

    switch localContext {
    case .null:
      return .init(baseIRI: self.originalBaseIRI, originalBaseIRI: self.originalBaseIRI)
    case .single(let context):
      try await result.process(
        context: context, remoteContexts: remoteContexts, loader: loader, logger: logger)
    case .array(let contexts):
      for context in contexts {
        try await result.process(
          context: context, remoteContexts: remoteContexts, loader: loader, logger: logger)
      }
    }

    return result
  }

  private mutating func process(
    context: Context,
    remoteContexts: [String],
    loader: (any JSONLDDocumentLoader)?,
    logger: (any JSONLDLogger)?
  ) async throws(JSONLDError) {
    switch context {
    case .absoluteIRI(let iri), .relativeIRI(let iri):
      let resolvedIRI = try self.expandIRI(iri, asDocumentRelative: true)

      if remoteContexts.contains(resolvedIRI) {
        throw .code(.recursiveContextInclusion)
      }
      if remoteContexts.count >= Self.maxRemoteContexts {
        throw .code(.loadingRemoteContextFailed)
      }

      var updatedRemoteContexts = remoteContexts
      updatedRemoteContexts.append(resolvedIRI)

      guard let loader else {
        throw .code(.loadingRemoteContextFailed)
      }

      let result = await loader.load(url: resolvedIRI)
      let remoteDocument: RemoteDocument =
        switch result {
        case .success(let doc):
          doc
        case .failure(let error):
          logger?.log(
            "Failed to load remote context from \(resolvedIRI): \(error)", level: .error)
          throw .code(.loadingRemoteContextFailed)
        }

      guard case .object(let obj) = remoteDocument.document,
        let innerContext = obj[.context]
      else {
        throw .code(.invalidRemoteContext)
      }

      let remoteContext = try Contexts(from: innerContext)

      var subContext = self
      subContext.baseIRI = remoteDocument.documentURL

      self = try await subContext.process(
        localContext: remoteContext,
        remoteContexts: updatedRemoteContexts,
        loader: loader,
        logger: logger
      )

    case .contextDefinition(let definition):
      if let baseIRI = definition.baseIRI {
        switch baseIRI {
        case .string(let value):
          if value.isEmpty {
            self.baseIRI = self.originalBaseIRI ?? self.baseIRI
          } else if value.contains(":") {
            self.baseIRI = value
          } else {
            self.baseIRI = try self.expandIRI(value, asDocumentRelative: true)
          }
        case .null:
          self.baseIRI = nil
        }
      }

      if let vocabMapping = definition.vocabMapping {
        switch vocabMapping {
        case .string(let value):
          if self.isAbsoluteIRI(value) || value.hasPrefix("_:") {
            self.vocabMapping = value
          } else {
            throw .code(.invalidVocabMapping)
          }
        case .null:
          self.vocabMapping = nil
        }
      }

      if let defaultLanguage = definition.defaultLanguage {
        switch defaultLanguage {
        case .string(let value):
          self.defaultLanguage = value.lowercased()
        case .null:
          self.defaultLanguage = nil
        }
      }

      var defined: [String: Bool] = [:]
      for term in definition.terms.keys.sorted() {
        try self.defineTerm(definition, term: term, defined: &defined)
      }
    }
  }

  private mutating func defineTerm(
    _ definition: ContextDefinition,
    term: String,
    defined: inout [String: Bool]
  ) throws(JSONLDError) {
    if let isDefined = defined[term] {
      if isDefined { return }
      throw .code(.cyclicIRIMapping)
    }

    defined[term] = false

    guard let value = definition.terms[term] else {
      defined[term] = true
      return
    }

    if case .null = value {
      self.termDefinitions[term] = nil
      self.nullTerms.insert(term)
      defined[term] = true
      return
    }

    var termDefinition = TermDefinition(iri: "")

    switch value {
    case .iriOrTerm(let iri):
      termDefinition.iri = try self.expandIRIForDefinition(
        iri, asVocab: true, definition: definition, term: term, defined: &defined)

      if !self.isAbsoluteIRI(termDefinition.iri) && !termDefinition.iri.hasPrefix("_:") {
        throw .code(.invalidIRIMapping)
      }

    case .keyword(let keyword):
      if keyword == .context {
        throw .code(.invalidKeywordAlias)
      }
      termDefinition.iri = keyword.rawValue

    case .expanded(let expanded):
      switch expanded {
      case .standard(let standard):
        switch standard.id {
        case .keyword(let keyword)?:
          if keyword == .context {
            throw .code(.invalidKeywordAlias)
          }
          termDefinition.iri = keyword.rawValue
        case .iriOrTerm(let iri)?:
          termDefinition.iri = try self.expandIRIForDefinition(
            iri, asVocab: true, definition: definition, term: term, defined: &defined)
          if !self.isAbsoluteIRI(termDefinition.iri) && !termDefinition.iri.hasPrefix("_:") {
            throw .code(.invalidIRIMapping)
          }
        case .null?:
          self.termDefinitions[term] = nil
          self.nullTerms.insert(term)
          defined[term] = true
          return
        case nil:
          if term.contains(":") {
            let colonIndex = term.firstIndex(of: ":")!
            let prefix = String(term[..<colonIndex])
            if definition.terms[prefix] != nil {
              try self.defineTerm(definition, term: prefix, defined: &defined)
            }
            if let prefixDefinition = self.termDefinitions[prefix] {
              termDefinition.iri =
                prefixDefinition.iri + String(term[term.index(after: colonIndex)...])
            } else {
              termDefinition.iri = term
            }
          } else if let vocab = self.vocabMapping {
            termDefinition.iri = vocab + term
          } else {
            termDefinition.iri = term
          }

          if !self.isAbsoluteIRI(termDefinition.iri) && !termDefinition.iri.hasPrefix("_:") {
            throw .code(.invalidIRIMapping)
          }
        }

        switch standard.type {
        case .keyword(let keyword)?:
          if keyword == .none {
            throw .code(.invalidTypeMapping)
          }
          termDefinition.typeMapping = keyword.rawValue
        case .iriOrTerm(let iri)?:
          let typeMapping = try self.expandIRIForDefinition(
            iri, asVocab: true, definition: definition, term: term, defined: &defined)
          if typeMapping != "@id" && typeMapping != "@vocab" && !self.isAbsoluteIRI(typeMapping) {
            throw .code(.invalidTypeMapping)
          }
          termDefinition.typeMapping = typeMapping
        case .null?, nil:
          termDefinition.typeMapping = nil
        }

        switch standard.language {
        case .string(let value)?:
          termDefinition.languageMapping = value.lowercased()
          termDefinition.languageMappingDefined = true
        case .null?:
          termDefinition.languageMapping = nil
          termDefinition.languageMappingDefined = true
        case nil:
          termDefinition.languageMapping = nil
          termDefinition.languageMappingDefined = false
        }

        if let container = standard.container {
          termDefinition.containerMapping = container
        }

        termDefinition.localContext = standard.context
        termDefinition.index = standard.index
        termDefinition.nest = standard.nest
        termDefinition.prefix = standard.prefix
        termDefinition.protected = standard.protected

      case .reverse(let reverse):
        termDefinition.reverse = true
        let reverseIRI: String =
          if case .string(let s) = reverse.reverse.jsonValue { s } else { "" }
        termDefinition.iri = try self.expandIRIForDefinition(
          reverseIRI, asVocab: true, definition: definition, term: term, defined: &defined)

        if !self.isAbsoluteIRI(termDefinition.iri) && !termDefinition.iri.hasPrefix("_:") {
          throw .code(.invalidIRIMapping)
        }

        if let container = reverse.container {
          termDefinition.containerMapping =
            switch container {
            case .set: .set
            case .index: .index
            case .null: .null
            }
        }

        switch reverse.type {
        case .keyword(let keyword)?:
          termDefinition.typeMapping = keyword.rawValue
        case .iriOrTerm(let iri)?:
          let typeMapping = try self.expandIRIForDefinition(
            iri, asVocab: true, definition: definition, term: term, defined: &defined)
          if typeMapping != "@id" && typeMapping != "@vocab" && !self.isAbsoluteIRI(typeMapping) {
            throw .code(.invalidTypeMapping)
          }
          termDefinition.typeMapping = typeMapping
        case .null?, nil:
          break
        }

        switch reverse.language {
        case .string(let value)?:
          termDefinition.languageMapping = value.lowercased()
          termDefinition.languageMappingDefined = true
        case .null?:
          termDefinition.languageMapping = nil
          termDefinition.languageMappingDefined = true
        case nil:
          termDefinition.languageMapping = nil
          termDefinition.languageMappingDefined = false
        }

        termDefinition.localContext = reverse.context
        termDefinition.index = reverse.index
        termDefinition.nest = reverse.nest
        termDefinition.prefix = reverse.prefix
        termDefinition.protected = reverse.protected
      }
    case .null:
      break
    }

    self.nullTerms.remove(term)
    self.termDefinitions[term] = termDefinition
    defined[term] = true
  }

  private mutating func expandIRIForDefinition(
    _ value: String,
    asVocab: Bool,
    definition: ContextDefinition,
    term: String,
    defined: inout [String: Bool]
  ) throws(JSONLDError) -> String {
    if let keyword = JSONLDKeyword(rawValue: value) {
      return keyword.rawValue
    }

    if self.nullTerms.contains(value) {
      return value
    }

    if let colonIndex = value.firstIndex(of: ":") {
      let prefix = String(value[..<colonIndex])
      let suffix = String(value[value.index(after: colonIndex)...])

      if prefix == "_" || suffix.hasPrefix("//") {
        return value
      }

      if definition.terms[prefix] != nil {
        if let isDefined = defined[prefix], !isDefined {
          throw .code(.cyclicIRIMapping)
        }
        try self.defineTerm(definition, term: prefix, defined: &defined)
      }

      if let prefixDefinition = self.termDefinitions[prefix] {
        return prefixDefinition.iri + suffix
      }

      return value
    }

    if definition.terms[value] != nil && value != term {
      if let isDefined = defined[value], !isDefined {
        throw .code(.cyclicIRIMapping)
      }
      try self.defineTerm(definition, term: value, defined: &defined)
    }
    if let termDef = self.termDefinitions[value], value != term {
      return termDef.iri
    }

    if asVocab, let vocab = self.vocabMapping {
      return vocab + value
    }

    return value
  }

  mutating func expandIRI(
    _ value: String,
    asVocab: Bool = false,
    asDocumentRelative: Bool = false
  ) throws(JSONLDError) -> String {
    if let keyword = JSONLDKeyword(rawValue: value) {
      return keyword.rawValue
    }

    if self.nullTerms.contains(value) {
      return value
    }

    if let termDef = self.termDefinitions[value] {
      return termDef.iri
    }

    if let colonIndex = value.firstIndex(of: ":") {
      let prefix = String(value[..<colonIndex])
      let suffix = String(value[value.index(after: colonIndex)...])

      if prefix == "_" || suffix.hasPrefix("//") {
        return value
      }

      if let prefixDefinition = self.termDefinitions[prefix] {
        return prefixDefinition.iri + suffix
      }

      return value
    }

    if asVocab, let vocab = self.vocabMapping {
      return vocab + value
    }

    if asDocumentRelative, let baseIRI = self.baseIRI {
      if let baseURL = URL(string: baseIRI),
        let resolvedURL = URL(string: value, relativeTo: baseURL)
      {
        return Self.normalizeResolvedIRI(resolvedURL.absoluteString)
      }
    }

    return value
  }

  private func isAbsoluteIRI(_ iri: String) -> Bool {
    if JSONLDKeyword(rawValue: iri) != nil { return true }

    if iri.hasPrefix("_:") {
      return false
    }

    if let url = URL(string: iri), url.scheme != nil {
      return true
    }

    guard let colonIndex = iri.firstIndex(of: ":"), colonIndex != iri.startIndex else {
      return false
    }
    let scheme = iri[..<colonIndex]
    let first = scheme.first!
    guard first.isLetter else { return false }
    return scheme.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
  }

  private static func normalizeResolvedIRI(_ iri: String) -> String {
    guard var components = URLComponents(string: iri) else { return iri }
    components.percentEncodedPath = Self.removeDotSegments(components.percentEncodedPath)
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

  func typeMapping(for term: String) -> String? {
    self.termDefinitions[term]?.typeMapping
  }

  func languageMapping(for term: String) -> String? {
    self.termDefinitions[term]?.languageMapping
  }

  func hasLanguageMapping(for term: String) -> Bool {
    self.termDefinitions[term]?.languageMappingDefined ?? false
  }

  func containerMapping(for term: String) -> ExpandedTermDefinition.Container {
    self.termDefinitions[term]?.containerMapping ?? .null
  }
}

struct TermDefinition: Equatable, Sendable {
  var iri: String
  var reverse: Bool
  var typeMapping: String?
  var languageMapping: String?
  var languageMappingDefined: Bool
  var containerMapping: ExpandedTermDefinition.Container
  var localContext: Contexts?
  var index: JSONValue?
  var nest: JSONValue?
  var prefix: JSONValue?
  var protected: JSONValue?

  init(
    iri: String,
    reverse: Bool = false,
    typeMapping: String? = nil,
    languageMapping: String? = nil,
    languageMappingDefined: Bool = false,
    containerMapping: ExpandedTermDefinition.Container = .null,
    localContext: Contexts? = nil,
    index: JSONValue? = nil,
    nest: JSONValue? = nil,
    prefix: JSONValue? = nil,
    protected: JSONValue? = nil
  ) {
    self.iri = iri
    self.reverse = reverse
    self.typeMapping = typeMapping
    self.languageMapping = languageMapping
    self.languageMappingDefined = languageMappingDefined
    self.containerMapping = containerMapping
    self.localContext = localContext
    self.index = index
    self.nest = nest
    self.prefix = prefix
    self.protected = protected
  }
}
