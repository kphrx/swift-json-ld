// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A structure representing a JSON-LD document.
///
/// The document can be in different phases, such as `Unresolved` (raw input) or `Expanded`.
public struct JSONLDDocument<P: JSONLDPhase>: Equatable, CustomJSONValueConvertible {
  /// The retrieval URL of the document, if available.
  ///
  /// This is used as the default base IRI during expansion if no `@base` is specified.
  public let documentURL: String?

  /// The top-level content of the document.
  let value: SingleOrMany<JSONLDValue<P>.NodeObject>

  /// Creates a JSON-LD document from node objects.
  public init(_ value: SingleOrMany<JSONLDValue<P>.NodeObject>, documentURL: String? = nil) {
    self.value = value
    self.documentURL = documentURL
  }

  /// Returns this document as a JSON value.
  public var jsonValue: JSONValue {
    self.value.jsonValue
  }

  /// Returns this document as a collection of JSON-LD values.
  public var values: JSONLDValues<P> {
    .init(.many(self.value.map(JSONLDValue<P>.node)))
  }
}

extension JSONLDDocument where P == Unresolved {
  init(validating jsonValue: JSONValue) throws(JSONLDError) {
    self.init(
      try .init(from: jsonValue) { jsonValue throws(JSONLDError) in
        guard case .object(let jsonObject) = jsonValue else {
          throw .internalError(.notObject)
        }
        return try .init(from: jsonObject)
      }
    )
  }

  /// Creates an unresolved document from a JSON value.
  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    try self.init(validating: jsonValue)
  }
}

extension JSONLDDocument: Decodable where P == Unresolved {
  /// Initializes a document from a decoder.
  ///
  /// This initializer is only available for the `Unresolved` phase,
  /// as `Expanded` documents should only be created through the expansion algorithm.
  public init(from decoder: any Decoder) throws {
    let jsonValue = try JSONValue(from: decoder)
    try self.init(validating: jsonValue)
  }
}

extension JSONLDDocument where P == Expanded {
  /// Normalizes expanded values into a JSON-LD document.
  public init(normalizing values: JSONLDValues<Expanded>, documentURL: String? = nil) {
    self = values.asDocument(documentURL: documentURL)
  }
}
