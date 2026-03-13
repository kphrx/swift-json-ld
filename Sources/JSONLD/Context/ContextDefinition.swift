// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension Contexts {
  /// A JSON-LD *context definition* object.
  public struct ContextDefinition: JSONLDObjectProtocol, Equatable, Sendable {
    let baseIRI: BaseIRI?
    let vocabMapping: VocabMapping?
    let defaultLanguage: DefaultLanguage?
    let terms: [String: Value]
  }
}

extension Contexts.ContextDefinition {
  /// Returns this *context definition* as a JSON object.
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

  /// Creates a *context definition* from a JSON object.
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
        return (key, try Value(from: value))
      }
    )
  }
}

extension Contexts.ContextDefinition {
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
