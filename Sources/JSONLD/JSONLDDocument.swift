// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A structure representing a JSON-LD document.
///
/// The document can be in different phases, such as `Unresolved` (raw input) or `Expanded`.
public struct JSONLDDocument<P: JSONLDPhase>: JSONLDValueProtocol, Equatable {
  /// The retrieval URL of the document, if available.
  ///
  /// This is used as the default base IRI during expansion if no `@base` is specified.
  public let documentURL: String?

  /// The top-level content of the document.
  let value: SingleOrMany<NodeObject<P>>

  public init(_ value: SingleOrMany<NodeObject<P>>, documentURL: String? = nil) {
    self.value = value
    self.documentURL = documentURL
  }

  public var jsonValue: JSONValue {
    self.value.jsonValue
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    self.init(try .init(from: jsonValue))
  }

  public var values: JSONLDValues<P> {
    .init(.many(self.value.map(JSONLDValue<P>.node)))
  }
}

extension JSONLDDocument: Decodable where P == Unresolved {
  /// Initializes a document from a decoder.
  ///
  /// This initializer is only available for the `Unresolved` phase,
  /// as `Expanded` documents should only be created through the expansion algorithm.
  public init(from decoder: Decoder) throws {
    let jsonValue = try JSONValue(from: decoder)
    try self.init(from: jsonValue)
  }
}

extension JSONLDDocument where P == Expanded {
  public init(normalizing values: JSONLDValues<Expanded>, documentURL: String? = nil) {
    self = values.asDocument(documentURL: documentURL)
  }
}
