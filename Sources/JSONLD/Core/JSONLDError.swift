// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public struct JSONLDError: Error, Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case code(Code)
    case internalError(Internal)
  }

  public enum Code: String, Equatable, Sendable {
    // JSON-LD 1.0 Processing Algorithms and API § 11.4 Error Handling § JsonLdErrorCode
    // Context Processing errors
    case invalidIdValue = "invalid @id value"
    case invalidReverseProperty = "invalid reverse property"
    case invalidIRIMapping = "invalid IRI mapping"
    case cyclicIRIMapping = "cyclic IRI mapping"
    case invalidKeywordAlias = "invalid keyword alias"
    case invalidTypeMapping = "invalid type mapping"
    case invalidLanguageMapping = "invalid language mapping"
    case invalidContainerMapping = "invalid container mapping"

    // Expansion errors
    case listOfLists = "list of lists"
    case invalidIndexValue = "invalid @index value"
    case invalidLanguageMapValue = "invalid language map value"

    case loadingDocumentFailed = "loading document failed"
    case conflictingIndexes = "conflicting indexes"
    case invalidLocalContext = "invalid local context"
    case multipleContextLinkHeaders = "multiple context link headers"
    case loadingRemoteContextFailed = "loading remote context failed"
    case invalidRemoteContext = "invalid remote context"
    case recursiveContextInclusion = "recursive context inclusion"
    case invalidBaseIRI = "invalid base IRI"
    case invalidVocabMapping = "invalid vocab mapping"
    case invalidDefaultLanguage = "invalid default language"
    case keywordRedefinition = "keyword redefinition"
    case invalidTermDefinition = "invalid term definition"
    case collidingKeywords = "colliding keywords"
    case invalidTypeValue = "invalid type value"
    case invalidValueObject = "invalid value object"
    case invalidValueObjectValue = "invalid value object value"
    case invalidLanguageTaggedString = "invalid language-tagged string"
    case invalidLanguageTaggedValue = "invalid language-tagged value"
    case invalidTypedValue = "invalid typed value"
    case invalidSetOrListObject = "invalid set or list object"
    case compactionToListOfLists = "compaction to list of lists"
    case invalidReversePropertyMap = "invalid reverse property map"
    case invalidReverseValue = "invalid @reverse value"
    case invalidReversePropertyValue = "invalid reverse property value"

    // JSON-LD 1.1 Processing Algorithms and API § 9.6 Error Handling § 9.6.2 JsonLdErrorCode
    case contextOverflow = "context overflow"
    case invalidContextEntry = "invalid context entry"
    case processingModeConflict = "processing mode conflict"
  }

  public enum Internal: Equatable, Sendable {
    case notObject
    case notNodeObject
    case notValueObject
    case notSetOrListObject
    case notKeyword
    case implementationLimitExceeded
  }

  public struct DebugInfo: Equatable, Sendable {
    public let url: String?
    public let message: String?

    public init(url: String? = nil, message: String? = nil) {
      self.url = url
      self.message = message
    }
  }

  public let kind: Kind
  public let debugInfo: DebugInfo?

  public init(kind: Kind, debugInfo: DebugInfo? = nil) {
    self.kind = kind
    self.debugInfo = debugInfo
  }

  public static func code(_ code: Code, debugInfo: DebugInfo? = nil) -> Self {
    .init(kind: .code(code), debugInfo: debugInfo)
  }

  public static func internalError(_ internalError: Internal, debugInfo: DebugInfo? = nil) -> Self {
    .init(kind: .internalError(internalError), debugInfo: debugInfo)
  }
}

extension JSONLDError {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.kind == rhs.kind
  }
}

extension JSONLDError: CustomStringConvertible {
  public var description: String {
    switch self.kind {
    case .code(let code): code.rawValue
    case .internalError(let internalError):
      switch internalError {
      case .notObject: "not an object"
      case .notNodeObject: "not a node object"
      case .notValueObject: "not a value object"
      case .notSetOrListObject: "not a set or list object"
      case .notKeyword: "not a keyword"
      case .implementationLimitExceeded: "implementation limit exceeded"
      }
    }
  }
}
