// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public enum Contexts: JSONLDValueProtocol, Equatable {
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

  init(from jsonArray: JSONArray) throws(JSONLDError) {
    self = .array(try jsonArray.map(Context.init(from:)))
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

public enum Context: JSONLDValueProtocol, Equatable {
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

public struct ContextDefinition: JSONLDObjectProtocol, Equatable {
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
  enum BaseIRI: JSONLDValueProtocol, Equatable {
    case string(String)
    case null

    var jsonValue: JSONValue {
      switch self {
      case .string(let value): .string(value)
      case .null: .null
      }
    }

    init(from jsonValue: JSONValue) throws(JSONLDError) {
      switch jsonValue {
      case .string(let value):
        if JSONLDKeyword(rawValue: value) != nil {
          throw .code(.invalidBaseIRI)
        }
        self = .string(value)
      case .null:
        self = .null
      default:
        throw .code(.invalidBaseIRI)
      }
    }
  }

  enum VocabMapping: JSONLDValueProtocol, Equatable {
    case string(String)
    case null

    var jsonValue: JSONValue {
      switch self {
      case .string(let value): .string(value)
      case .null: .null
      }
    }

    init(from jsonValue: JSONValue) throws(JSONLDError) {
      switch jsonValue {
      case .string(let value):
        if JSONLDKeyword(rawValue: value) != nil {
          throw .code(.invalidVocabMapping)
        }
        self = .string(value)
      case .null:
        self = .null
      default:
        throw .code(.invalidVocabMapping)
      }
    }
  }

  enum DefaultLanguage: JSONLDValueProtocol, Equatable {
    case string(String)
    case null

    var jsonValue: JSONValue {
      switch self {
      case .string(let value): .string(value)
      case .null: .null
      }
    }

    init(from jsonValue: JSONValue) throws(JSONLDError) {
      switch jsonValue {
      case .string(let value):
        if JSONLDKeyword(rawValue: value) != nil {
          throw .code(.invalidDefaultLanguage)
        }
        self = .string(value)
      case .null:
        self = .null
      default:
        throw .code(.invalidDefaultLanguage)
      }
    }
  }
}

public enum TermDefinitionValue: JSONLDValueProtocol, Equatable {
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
    switch jsonValue {
    case .null:
      self = .null
    case .string(let value):
      if let keyword = JSONLDKeyword(rawValue: value) {
        self = .keyword(keyword)
      } else {
        self = .iriOrTerm(value)
      }
    case .object(let jsonObject):
      self = .expanded(try .init(from: jsonObject))
    default:
      throw .code(.invalidTermDefinition)
    }
  }
}

public enum ExpandedTermDefinition: JSONLDObjectProtocol, Equatable {
  case standard(Standard)
  case reverse(Reverse)

  public var jsonObject: JSONObject {
    switch self {
    case .standard(let standard):
      standard.jsonObject
    case .reverse(let reverse):
      reverse.jsonObject
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

    if index != nil {
      // TODO: Allow @index in JSON-LD 1.1 processing mode.
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
          index: index
        ))
    } else {
      self = .standard(
        .init(
          id: id,
          type: type,
          language: language,
          container: container,
          context: context,
          index: index
        ))
    }
    _ = properties
  }
}

extension ExpandedTermDefinition {
  public struct Standard: Equatable {
    let id: TermDefinitionId?
    let type: TermDefinitionType?
    let language: TermDefinitionLanguage?
    let container: Container?
    let context: Contexts?
    let index: JSONValue?

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

      return jsonObject
    }
  }

  public struct Reverse: Equatable {
    let reverse: TermDefinitionReverse
    let type: TermDefinitionType?
    let language: TermDefinitionLanguage?
    let container: Reverse.Container?
    let context: Contexts?
    let index: JSONValue?

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

      return jsonObject
    }
  }

  public enum Container: JSONLDValueProtocol, Equatable {
    case set
    case list
    case index
    case language
    case null

    var keyword: JSONLDKeyword? {
      switch self {
      case .set:
        .set
      case .list:
        .list
      case .index:
        .index
      case .language:
        .language
      case .null:
        nil
      }
    }

    public var jsonValue: JSONValue {
      self.keyword?.jsonValue ?? .null
    }

    public init(from jsonValue: JSONValue) throws(JSONLDError) {
      switch jsonValue {
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
      case .null:
        self = .null
      case .array:
        // NOTE: JSON-LD 1.1 allows container arrays; json-ld-1.0 does not.
        throw .code(.invalidContainerMapping)
      default:
        throw .code(.invalidContainerMapping)
      }
    }

  }
}

public enum TermDefinitionId: JSONLDValueProtocol, Equatable {
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
    switch jsonValue {
    case .string(let value):
      if let keyword = JSONLDKeyword(rawValue: value) {
        self = .keyword(keyword)
      } else {
        self = .iriOrTerm(value)
      }
    case .null:
      self = .null
    default:
      throw .code(.invalidIRIMapping)
    }
  }
}

extension ExpandedTermDefinition.Reverse {
  public enum Container: Equatable {
    case set
    case index
    case null

    var keyword: JSONLDKeyword? {
      switch self {
      case .set:
        .set
      case .index:
        .index
      case .null:
        nil
      }
    }

    var jsonValue: JSONValue {
      self.keyword?.jsonValue ?? .null
    }

    init(from container: ExpandedTermDefinition.Container) throws(JSONLDError) {
      switch container {
      case .set: self = .set
      case .index: self = .index
      case .list, .language:
        throw .code(.invalidReverseProperty)
      case .null:
        self = .null
      }
    }
  }
}

public enum TermDefinitionType: JSONLDValueProtocol, Equatable {
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
    switch jsonValue {
    case .string(let value):
      if let keyword = JSONLDKeyword(rawValue: value) {
        if keyword == .none {
          throw .code(.invalidTypeMapping)
        }
        self = .keyword(keyword)
      } else {
        self = .iriOrTerm(value)
      }
    case .null:
      self = .null
    default:
      throw .code(.invalidTypeMapping)
    }
  }
}

public enum TermDefinitionLanguage: JSONLDValueProtocol, Equatable {
  case string(String)
  case null

  public var jsonValue: JSONValue {
    switch self {
    case .string(let value): .string(value)
    case .null: .null
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let value):
      self = .string(value)
    case .null:
      self = .null
    default:
      throw .code(.invalidLanguageMapping)
    }
  }
}

public enum TermDefinitionReverse: JSONLDValueProtocol, Equatable {
  case string(String)
  case null

  public var jsonValue: JSONValue {
    switch self {
    case .string(let value): .string(value)
    case .null: .null
    }
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .string(let value):
      self = .string(value)
    case .null:
      self = .null
    default:
      throw .code(.invalidIRIMapping)
    }
  }
}
