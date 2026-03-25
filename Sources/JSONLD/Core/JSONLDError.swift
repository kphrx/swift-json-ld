// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// An error raised by the JSON-LD processor.
public struct JSONLDError: Error, Equatable, Sendable {
  /// The error kind.
  public enum Kind: Equatable, Sendable {
    case code(Code)
    case internalError(Internal)
  }

  /// A JSON-LD error code representing `JsonLdErrorCode`.
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

  /// An internal error used to represent invalid states.
  public enum Internal: Equatable, Sendable {
    case notObject
    case notNodeObject
    case notValueObject
    case notSetOrListObject
    case notKeyword
    case implementationLimitExceeded
  }

  /// Supplemental debug information for an error.
  public struct DebugInfo: Equatable, Sendable {
    /// The URL associated with the error, if available.
    public let url: String?
    /// A human-readable message, if available.
    public let message: String?

    /// Creates debug information with an optional URL and message.
    public init(url: String? = nil, message: String? = nil) {
      self.url = url
      self.message = message
    }
  }

  /// The error kind.
  public let kind: Kind
  /// Optional debug information.
  public let debugInfo: DebugInfo?

  /// Creates a JSON-LD error with a kind and optional debug information.
  public init(kind: Kind, debugInfo: DebugInfo? = nil) {
    self.kind = kind
    self.debugInfo = debugInfo
  }

  /// Creates a JSON-LD error from a `JsonLdErrorCode`.
  public static func code(_ code: Code, debugInfo: DebugInfo? = nil) -> Self {
    .init(kind: .code(code), debugInfo: debugInfo)
  }

  /// Creates a JSON-LD error from an internal error.
  public static func internalError(_ internalError: Internal, debugInfo: DebugInfo? = nil) -> Self {
    .init(kind: .internalError(internalError), debugInfo: debugInfo)
  }
}

extension JSONLDError {
  /// Compares JSON-LD errors by kind.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.kind == rhs.kind
  }
}

extension JSONLDError: CustomStringConvertible {
  /// A human-readable description of the error.
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
