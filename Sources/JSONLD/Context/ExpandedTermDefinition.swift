// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension Contexts.ContextDefinition {
  public enum Value: JSONLDValueProtocol, Equatable, Sendable {
    case null
    case keyword(JSONLDKeyword)
    case iriOrTerm(String)
    case expanded(ExpandedTermDefinition)
  }
}

extension Contexts.ContextDefinition.Value {
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

extension Contexts.ContextDefinition.Value: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self = .null
  }
}

extension Contexts.ContextDefinition.Value: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    if let keyword = JSONLDKeyword(rawValue: value) {
      self = .keyword(keyword)
    } else {
      self = .iriOrTerm(value)
    }
  }
}

extension Contexts.ContextDefinition.Value: ExpressibleByDictionaryLiteral {
  public init(
    dictionaryLiteral elements: (String, String?)...
  ) {
    self = .expanded(.fromLiteral(elements))
  }
}

extension Contexts.ContextDefinition.ExpandedTermDefinition: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, String?)...) {
    self = .fromLiteral(elements)
  }
}

extension Contexts.ContextDefinition.ExpandedTermDefinition {
  fileprivate static func fromLiteral(_ elements: [(String, String?)]) -> Self {
    do {
      return try .init(
        from: .init(
          uniqueKeysWithValues: elements.map { key, value in
            guard JSONLDKeyword(rawValue: key) != nil else {
              preconditionFailure("Invalid term definition literal: unknown keyword \(key)")
            }
            return (key, value.map(JSONValue.string) ?? .null)
          }
        )
      )
    } catch {
      preconditionFailure("Invalid term definition literal: \(error)")
    }
  }
}

extension Contexts.ContextDefinition {
  public enum ExpandedTermDefinition: JSONLDObjectProtocol, Equatable, Sendable {
    case standard(Standard)
    case reverse(Reverse)
  }
}

extension Contexts.ContextDefinition.ExpandedTermDefinition {
  public var jsonObject: JSONObject {
    switch self {
    case .standard(let standard): standard.jsonObject
    case .reverse(let reverse): reverse.jsonObject
    }
  }

  public init(from jsonObject: JSONObject) throws(JSONLDError) {
    var properties = jsonObject

    let id = try properties.removeValue(for: .id).map(Id.init)
    let type = try properties.removeValue(for: .type).map(TermType.init)
    let language = try properties.removeValue(for: .language).map(Language.init)
    let container = try properties.removeValue(for: .container).map(Container.init)
    let reverse = try properties.removeValue(for: .reverse).map(ReverseProperty.init)
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

extension Contexts.ContextDefinition.ExpandedTermDefinition {
  public struct Standard: Equatable, Sendable {
    let id: Id?
    let type: TermType?
    let language: Language?
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
    let reverse: ReverseProperty
    let type: TermType?
    let language: Language?
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

extension Contexts.ContextDefinition.ExpandedTermDefinition {
  public enum Id: JSONLDValueProtocol, Equatable, Sendable {
    case null
    case keyword(JSONLDKeyword)
    case iriOrTerm(String)
  }
}

extension Contexts.ContextDefinition.ExpandedTermDefinition.Id {
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

extension Contexts.ContextDefinition.ExpandedTermDefinition.Reverse {
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

    init(from container: Contexts.ContextDefinition.ExpandedTermDefinition.Container)
      throws(JSONLDError)
    {
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

extension Contexts.ContextDefinition.ExpandedTermDefinition {
  public enum TermType: JSONLDValueProtocol, Equatable, Sendable {
    case null
    case keyword(JSONLDKeyword)
    case iriOrTerm(String)
  }
}

extension Contexts.ContextDefinition.ExpandedTermDefinition.TermType {
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

extension Contexts.ContextDefinition.ExpandedTermDefinition {
  public enum Language: JSONLDValueProtocol, Equatable, Sendable {
    case null
    case string(String)
  }
}

extension Contexts.ContextDefinition.ExpandedTermDefinition.Language {
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

extension Contexts.ContextDefinition.ExpandedTermDefinition {
  public enum ReverseProperty: JSONLDValueProtocol, Equatable, Sendable {
    case null
    case string(String)
  }
}

extension Contexts.ContextDefinition.ExpandedTermDefinition.ReverseProperty {
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
