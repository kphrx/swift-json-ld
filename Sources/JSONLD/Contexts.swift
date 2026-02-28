// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public enum Contexts: JSONLDValueProtocol, Equatable, Sendable {
  case null
  case single(Context)
  case array([Context])

  public var jsonValue: JSONValue {
    switch self {
    case .null: .null
    case .single(let context): context.jsonValue
    case .array(let contexts): contexts.jsonValue
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      if case .null = jsonValue {
        .null
      } else {
        switch try SingleOrMany<Context>(from: jsonValue) {
        case .single(let context): .single(context)
        case .many(let contexts): .array(contexts)
        }
      }
  }
}

public enum Context: JSONLDValueProtocol, Equatable, Sendable {
  case absoluteIRI(String)
  case relativeIRI(String)
  case contextDefinition(ContextDefinition)

  public var jsonValue: JSONValue {
    switch self {
    case .absoluteIRI(let value), .relativeIRI(let value): .string(value)
    case .contextDefinition(let contextDefinition): contextDefinition.jsonValue
    }
  }

  init(iri value: String) throws(JSONLDError) {
    self =
      if value.contains(":") {
        .absoluteIRI(value)
      } else {
        .relativeIRI(value)
      }
  }

  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    self = .contextDefinition(try .init(from: jsonObject))
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .object(let jsonObject): try .init(from: jsonObject)
      case .string(let value): try .init(iri: value)
      default: throw .code(.invalidLocalContext)
      }
  }
}

public struct ContextDefinition: JSONLDObjectProtocol, Equatable, Sendable {
  let baseIRI: BaseIRI?
  let vocabMapping: VocabMapping?
  let defaultLanguage: DefaultLanguage?
  let terms: [String: TermDefinitionValue]

  public var jsonObject: JSONObject {
    var jsonObject = self.terms.jsonObject

    if let baseIRI = self.baseIRI {
      jsonObject[.base] = baseIRI.jsonValue
    }

    if let vocabMapping = self.vocabMapping {
      jsonObject[.vocab] = vocabMapping.jsonValue
    }

    if let defaultLanguage = self.defaultLanguage {
      jsonObject[.language] = defaultLanguage.jsonValue
    }

    return jsonObject
  }

  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject
    if properties.removeValue(for: .version) != nil {
      // NOTE: JSON-LD 1.1 uses @version, but json-ld-1.0 processing mode conflicts.
      throw .code(.processingModeConflict)
    }
    if properties.removeValue(for: .propagate) != nil || properties.removeValue(for: .import) != nil
    {
      // NOTE: JSON-LD 1.1 context keywords are invalid in json-ld-1.0 processing mode.
      throw .code(.invalidContextEntry)
    }
    if properties.removeValue(forKey: "") != nil {
      throw .code(.invalidTermDefinition)
    }

    self.baseIRI = try properties.removeValue(for: .base).map(BaseIRI.init)
    self.vocabMapping = try properties.removeValue(for: .vocab).map(VocabMapping.init)
    self.defaultLanguage = try properties.removeValue(for: .language).map(DefaultLanguage.init)

    self.terms = try Dictionary(
      uniqueKeysWithValues: properties.map { key, value throws(JSONLDError) in
        if JSONLDKeyword(rawValue: key) != nil {
          throw .code(.keywordRedefinition)
        }
        return (key, try TermDefinitionValue(from: value))
      }
    )
  }
}

extension ContextDefinition {
  enum BaseIRI: JSONLDValueProtocol, Equatable, Sendable {
    case null
    case string(String)

    var jsonValue: JSONValue {
      switch self {
      case .null: .null
      case .string(let value): .string(value)
      }
    }

    init(from jsonValue: JSONValue) throws(JSONLDError) {
      self =
        switch jsonValue {
        case .null:
          .null
        case .string(let value) where JSONLDKeyword(rawValue: value) == nil:
          .string(value)
        default:
          throw .code(.invalidBaseIRI)
        }
    }
  }

  enum VocabMapping: JSONLDValueProtocol, Equatable, Sendable {
    case null
    case string(String)

    var jsonValue: JSONValue {
      switch self {
      case .null: .null
      case .string(let value): .string(value)
      }
    }

    init(from jsonValue: JSONValue) throws(JSONLDError) {
      self =
        switch jsonValue {
        case .null:
          .null
        case .string(let value) where JSONLDKeyword(rawValue: value) == nil:
          .string(value)
        default:
          throw .code(.invalidVocabMapping)
        }
    }
  }

  enum DefaultLanguage: JSONLDValueProtocol, Equatable, Sendable {
    case null
    case string(String)

    var jsonValue: JSONValue {
      switch self {
      case .null: .null
      case .string(let value): .string(value)
      }
    }

    init(from jsonValue: JSONValue) throws(JSONLDError) {
      self =
        switch jsonValue {
        case .null:
          .null
        case .string(let value) where JSONLDKeyword(rawValue: value) == nil:
          .string(value)
        default:
          throw .code(.invalidDefaultLanguage)
        }
    }
  }
}

public enum TermDefinitionValue: JSONLDValueProtocol, Equatable, Sendable {
  case null
  case keyword(JSONLDKeyword)
  case iriOrTerm(String)
  case expanded(ExpandedTermDefinition)

  public var jsonValue: JSONValue {
    switch self {
    case .null: .null
    case .keyword(let keyword): keyword.jsonValue
    case .iriOrTerm(let value): .string(value)
    case .expanded(let definition): definition.jsonValue
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .null:
        .null
      case .string(let value):
        if let keyword = JSONLDKeyword(rawValue: value) {
          .keyword(keyword)
        } else {
          .iriOrTerm(value)
        }
      case .object(let jsonObject):
        .expanded(try .init(from: jsonObject))
      default:
        throw .code(.invalidTermDefinition)
      }
  }
}

public enum ExpandedTermDefinition: JSONLDObjectProtocol, Equatable, Sendable {
  case standard(Standard)
  case reverse(Reverse)

  public var jsonObject: JSONObject {
    switch self {
    case .standard(let standard): standard.jsonObject
    case .reverse(let reverse): reverse.jsonObject
    }
  }

  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject

    let id = try properties.removeValue(for: .id).map(TermDefinitionId.init)
    let type = try properties.removeValue(for: .type).map(TermDefinitionType.init)
    let language = try properties.removeValue(for: .language).map(TermDefinitionLanguage.init)
    let container = try properties.removeValue(for: .container).map(Container.init)
    let reverse = try properties.removeValue(for: .reverse).map(TermDefinitionReverse.init)
    let context = try properties.removeValue(for: .context).map(Contexts.init(from:))
    let index = properties.removeValue(for: .index)
    let nest = properties.removeValue(for: .nest)
    let prefix = properties.removeValue(for: .prefix)
    let protected = properties.removeValue(for: .protected)

    if index != nil || context != nil || nest != nil || prefix != nil || protected != nil {
      // TODO: Allow these keywords in JSON-LD 1.1 processing mode.
      throw .code(.invalidTermDefinition)
    }

    if let reverse {
      if id != nil {
        throw .code(.invalidReverseProperty)
      }
      let reverseContainer = try container.map(Reverse.Container.init(from:))
      self = .reverse(
        .init(
          reverse: reverse,
          type: type,
          language: language,
          container: reverseContainer,
          context: context,
          index: index,
          nest: nest,
          prefix: prefix,
          protected: protected
        ))
    } else {
      self = .standard(
        .init(
          id: id,
          type: type,
          language: language,
          container: container,
          context: context,
          index: index,
          nest: nest,
          prefix: prefix,
          protected: protected
        ))
    }
    _ = properties
  }
}

extension ExpandedTermDefinition {
  public struct Standard: Equatable, Sendable {
    let id: TermDefinitionId?
    let type: TermDefinitionType?
    let language: TermDefinitionLanguage?
    let container: Container?
    let context: Contexts?
    let index: JSONValue?
    let nest: JSONValue?
    let prefix: JSONValue?
    let protected: JSONValue?

    var jsonObject: JSONObject {
      var jsonObject: JSONObject = [:]

      if let id = self.id {
        jsonObject[.id] = id.jsonValue
      }

      if let type = self.type {
        jsonObject[.type] = type.jsonValue
      }

      if let language = self.language {
        jsonObject[.language] = language.jsonValue
      }

      if let container = self.container {
        jsonObject[.container] = container.jsonValue
      }

      if let context = self.context {
        jsonObject[.context] = context.jsonValue
      }

      if let index = self.index {
        jsonObject[.index] = index
      }

      if let nest = self.nest {
        jsonObject[.nest] = nest
      }

      if let prefix = self.prefix {
        jsonObject[.prefix] = prefix
      }

      if let protected = self.protected {
        jsonObject[.protected] = protected
      }

      return jsonObject
    }
  }

  public struct Reverse: Equatable, Sendable {
    let reverse: TermDefinitionReverse
    let type: TermDefinitionType?
    let language: TermDefinitionLanguage?
    let container: Container?
    let context: Contexts?
    let index: JSONValue?
    let nest: JSONValue?
    let prefix: JSONValue?
    let protected: JSONValue?

    var jsonObject: JSONObject {
      var jsonObject: JSONObject = [:]

      jsonObject[.reverse] = reverse.jsonValue

      if let type = self.type {
        jsonObject[.type] = type.jsonValue
      }

      if let language = self.language {
        jsonObject[.language] = language.jsonValue
      }

      if let container = self.container {
        jsonObject[.container] = container.jsonValue
      }

      if let context = self.context {
        jsonObject[.context] = context.jsonValue
      }

      if let index = self.index {
        jsonObject[.index] = index
      }

      if let nest = self.nest {
        jsonObject[.nest] = nest
      }

      if let prefix = self.prefix {
        jsonObject[.prefix] = prefix
      }

      if let protected = self.protected {
        jsonObject[.protected] = protected
      }

      return jsonObject
    }
  }

  public enum Container: JSONLDValueProtocol, Equatable, Sendable {
    case null
    case set
    case list
    case index
    case language

    var keyword: JSONLDKeyword? {
      switch self {
      case .null:
        nil
      case .set:
        .set
      case .list:
        .list
      case .index:
        .index
      case .language:
        .language
      }
    }

    public var jsonValue: JSONValue {
      self.keyword?.jsonValue ?? .null
    }

    public init(from jsonValue: JSONValue) throws(JSONLDError) {
      switch jsonValue {
      case .null:
        self = .null
      case .string(let value):
        guard let keyword = JSONLDKeyword(rawValue: value) else {
          throw .code(.invalidContainerMapping)
        }
        self =
          switch keyword {
          case .set: .set
          case .list: .list
          case .index: .index
          case .language: .language
          default: throw .code(.invalidContainerMapping)
          }
      case .array:
        // NOTE: JSON-LD 1.1 allows container arrays; json-ld-1.0 does not.
        throw .code(.invalidContainerMapping)
      default:
        throw .code(.invalidContainerMapping)
      }
    }

  }
}

public enum TermDefinitionId: JSONLDValueProtocol, Equatable, Sendable {
  case null
  case keyword(JSONLDKeyword)
  case iriOrTerm(String)

  public var jsonValue: JSONValue {
    switch self {
    case .null: .null
    case .keyword(let keyword): keyword.jsonValue
    case .iriOrTerm(let value): .string(value)
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .null:
        .null
      case .string(let value):
        if let keyword = JSONLDKeyword(rawValue: value) {
          .keyword(keyword)
        } else {
          .iriOrTerm(value)
        }
      default:
        throw .code(.invalidIRIMapping)
      }
  }
}

extension ExpandedTermDefinition.Reverse {
  public enum Container: Equatable, Sendable {
    case null
    case set
    case index

    var keyword: JSONLDKeyword? {
      switch self {
      case .null:
        nil
      case .set:
        .set
      case .index:
        .index
      }
    }

    var jsonValue: JSONValue {
      self.keyword?.jsonValue ?? .null
    }

    init(from container: ExpandedTermDefinition.Container) throws(JSONLDError) {
      switch container {
      case .null:
        self = .null
      case .set: self = .set
      case .index: self = .index
      case .list, .language:
        throw .code(.invalidReverseProperty)
      }
    }
  }
}

public enum TermDefinitionType: JSONLDValueProtocol, Equatable, Sendable {
  case null
  case keyword(JSONLDKeyword)
  case iriOrTerm(String)

  public var jsonValue: JSONValue {
    switch self {
    case .null: .null
    case .keyword(let keyword): keyword.jsonValue
    case .iriOrTerm(let value): .string(value)
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .null:
        .null
      case .string(let value):
        if let keyword = JSONLDKeyword(rawValue: value) {
          if keyword == .none {
            throw .code(.invalidTypeMapping)
          } else {
            .keyword(keyword)
          }
        } else {
          .iriOrTerm(value)
        }
      default:
        throw .code(.invalidTypeMapping)
      }
  }
}

public enum TermDefinitionLanguage: JSONLDValueProtocol, Equatable, Sendable {
  case null
  case string(String)

  public var jsonValue: JSONValue {
    switch self {
    case .null: .null
    case .string(let value): .string(value)
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .null:
        .null
      case .string(let value) where JSONLDKeyword(rawValue: value) == nil:
        .string(value)
      default:
        throw .code(.invalidLanguageMapping)
      }
  }
}

public enum TermDefinitionReverse: JSONLDValueProtocol, Equatable, Sendable {
  case null
  case string(String)

  public var jsonValue: JSONValue {
    switch self {
    case .null: .null
    case .string(let value): .string(value)
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self =
      switch jsonValue {
      case .null:
        .null
      case .string(let value) where JSONLDKeyword(rawValue: value) == nil:
        .string(value)
      default:
        throw .code(.invalidIRIMapping)
      }
  }
}
