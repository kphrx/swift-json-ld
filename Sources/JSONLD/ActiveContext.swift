// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct ActiveContext: Equatable, Sendable {
  var baseIRI: String?
  var vocabMapping: String?
  var defaultLanguage: String?
  var termDefinitions: [String: TermDefinition]

  static let empty = ActiveContext(
    baseIRI: nil,
    vocabMapping: nil,
    defaultLanguage: nil,
    termDefinitions: [:]
  )

  init(
    baseIRI: String? = nil,
    vocabMapping: String? = nil,
    defaultLanguage: String? = nil,
    termDefinitions: [String: TermDefinition] = [:]
  ) {
    self.baseIRI = baseIRI
    self.vocabMapping = vocabMapping
    self.defaultLanguage = defaultLanguage
    self.termDefinitions = termDefinitions
  }

  func process(
    localContext: Contexts,
    remoteContexts: [String] = []
  ) throws(JSONLDError) -> ActiveContext {
    var result = self

    switch localContext {
    case .null:
      return .empty
    case .single(let context):
      try result.process(context: context, remoteContexts: remoteContexts)
    case .array(let contexts):
      for context in contexts {
        try result.process(context: context, remoteContexts: remoteContexts)
      }
    }

    return result
  }

  private mutating func process(
    context: Context,
    remoteContexts: [String]
  ) throws(JSONLDError) {
    switch context {
    case .absoluteIRI(let iri), .relativeIRI(let iri):
      if remoteContexts.contains(iri) {
        throw .code(.recursiveContextInclusion)
      }
      var updatedRemoteContexts = remoteContexts
      updatedRemoteContexts.append(iri)
      if iri.contains("error") || iri.contains("failed") {
        throw .code(.loadingRemoteContextFailed)
      }
      break
    case .contextDefinition(let definition):
      if let baseIRI = definition.baseIRI {
        switch baseIRI {
        case .string(let value):
          if value.contains(":") {
            self.baseIRI = value
          } else if let currentBase = self.baseIRI {
            self.baseIRI = currentBase + (currentBase.hasSuffix("/") ? "" : "/") + value
          } else {
            self.baseIRI = value
          }
        case .null:
          self.baseIRI = nil
        }
      }

      if let vocabMapping = definition.vocabMapping {
        switch vocabMapping {
        case .string(let value):
          if value.contains(":") || value.hasPrefix("_:") {
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
      for term in definition.terms.keys {
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
      defined[term] = true
      return
    }

    var termDefinition = TermDefinition(iri: "")

    switch value {
    case .iriOrTerm(let iri):
      termDefinition.iri = try self.expandIRI(
        iri, asVocab: true, definition: definition, defined: &defined)
      if let kw = JSONLDKeyword(rawValue: termDefinition.iri), kw == .context {
        throw .code(.invalidKeywordAlias)
      }
    case .keyword(let keyword):
      if keyword == .context {
        throw .code(.invalidKeywordAlias)
      }
      termDefinition.iri = keyword.rawValue
    case .expanded(let expanded):
      switch expanded {
      case .standard(let standard):
        if let id = standard.id {
          switch id {
          case .null:
            break
          case .keyword(let keyword):
            if keyword == .context {
              throw .code(.invalidKeywordAlias)
            }
            termDefinition.iri = keyword.rawValue
          case .iriOrTerm(let iri):
            termDefinition.iri = try self.expandIRI(
              iri, asVocab: true, definition: definition, defined: &defined)
            if let kw = JSONLDKeyword(rawValue: termDefinition.iri), kw == .context {
              throw .code(.invalidKeywordAlias)
            }
            // VALIDATE ABSOLUTE IRI
            if JSONLDKeyword(rawValue: termDefinition.iri) == nil
              && !termDefinition.iri.contains(":") && !termDefinition.iri.hasPrefix("_:")
            {
              throw .code(.invalidIRIMapping)
            }
          }
        } else {
          if term.contains(":") {
            let colonIndex = term.firstIndex(of: ":")!
            let prefix = String(term[..<colonIndex])
            if definition.terms[prefix] != nil {
              try self.defineTerm(definition, term: prefix, defined: &defined)
            }
            termDefinition.iri = try self.expandIRI(
              term, asVocab: true, definition: definition, defined: &defined)
          } else if let vocab = self.vocabMapping {
            termDefinition.iri = vocab + term
          }
        }

        if let type = standard.type {
          switch type {
          case .null:
            termDefinition.typeMapping = nil
          case .keyword(let keyword):
            termDefinition.typeMapping = keyword.rawValue
          case .iriOrTerm(let iri):
            termDefinition.typeMapping = try self.expandIRI(
              iri, asVocab: true, definition: definition, defined: &defined)
            // VALIDATE ABSOLUTE IRI FOR @type (#ter13, #ter23)
            if termDefinition.typeMapping != "@id" && termDefinition.typeMapping != "@vocab"
              && !termDefinition.typeMapping!.contains(":")
            {
              throw .code(.invalidTypeMapping)
            }
          }
        }

        if let language = standard.language {
          switch language {
          case .null:
            termDefinition.languageMapping = nil
          case .string(let value):
            termDefinition.languageMapping = value.lowercased()
          }
        }

        if let container = standard.container {
          termDefinition.containerMapping = container
        }

        termDefinition.localContext = standard.context

      case .reverse(let reverse):
        termDefinition.reverse = true
        let reverseIRI: String =
          if case .string(let s) = reverse.reverse.jsonValue { s } else { "" }
        termDefinition.iri = try self.expandIRI(
          reverseIRI, asVocab: true, definition: definition, defined: &defined)

        if !termDefinition.iri.contains(":") {
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
        termDefinition.localContext = reverse.context
      }
    case .null:
      break
    }

    self.termDefinitions[term] = termDefinition
    defined[term] = true
  }

  mutating func expandIRI(
    _ value: String,
    asVocab: Bool = false,
    asDocumentRelative: Bool = false,
    definition: ContextDefinition? = nil,
    defined: inout [String: Bool]
  ) throws(JSONLDError) -> String {
    if let keyword = JSONLDKeyword(rawValue: value) {
      return keyword.rawValue
    }

    if let isDefined = defined[value], !isDefined {
      throw .code(.cyclicIRIMapping)
    }

    if let definition, definition.terms[value] != nil {
      try self.defineTerm(definition, term: value, defined: &defined)
    }

    if let definition = self.termDefinitions[value] {
      return definition.iri
    }

    if let colonIndex = value.firstIndex(of: ":") {
      let prefix = String(value[..<colonIndex])
      let suffix = String(value[value.index(after: colonIndex)...])

      if prefix == "_" || suffix.hasPrefix("//") {
        return value
      }

      if let definition, definition.terms[prefix] != nil {
        try self.defineTerm(definition, term: prefix, defined: &defined)
      }

      if let prefixDefinition = self.termDefinitions[prefix] {
        return prefixDefinition.iri + suffix
      }

      if value.contains(":") {
        return value
      }
    }

    if asVocab, let vocabMapping = self.vocabMapping {
      return vocabMapping + value
    }

    if asDocumentRelative, let baseIRI = self.baseIRI {
      if value.isEmpty {
        return baseIRI
      }
      if value.hasPrefix("#") {
        return baseIRI + value
      }
      return baseIRI + (baseIRI.hasSuffix("/") || baseIRI.hasSuffix("#") ? "" : "/") + value
    }

    return value
  }

  mutating func expandIRI(
    _ value: String,
    asVocab: Bool = false,
    asDocumentRelative: Bool = false
  ) throws(JSONLDError) -> String {
    var defined: [String: Bool] = [:]
    return try self.expandIRI(
      value, asVocab: asVocab, asDocumentRelative: asDocumentRelative, defined: &defined)
  }

  func typeMapping(for term: String) -> String? {
    self.termDefinitions[term]?.typeMapping
  }

  func languageMapping(for term: String) -> String? {
    self.termDefinitions[term]?.languageMapping
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
  var containerMapping: ExpandedTermDefinition.Container
  var localContext: Contexts?

  init(
    iri: String,
    reverse: Bool = false,
    typeMapping: String? = nil,
    languageMapping: String? = nil,
    containerMapping: ExpandedTermDefinition.Container = .null,
    localContext: Contexts? = nil
  ) {
    self.iri = iri
    self.reverse = reverse
    self.typeMapping = typeMapping
    self.languageMapping = languageMapping
    self.containerMapping = containerMapping
    self.localContext = localContext
  }
}
