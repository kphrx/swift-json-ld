// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A structure representing a remote document and its associated metadata.
///
/// This structure encapsulates the result of a document loading operation,
/// providing the JSON content along with metadata required by the JSON-LD Processing Algorithms.
public struct RemoteDocument: Sendable {
  /// The final URL of the document after any redirects.
  ///
  /// This URL is used as the base IRI for the document if no `@base` is specified
  /// within the document itself.
  public let documentURL: String

  /// The content of the document as a `JSONValue`.
  ///
  /// For JSON-LD documents, this should be the parsed JSON structure.
  public let document: JSONValue

  /// The content type of the document, if available.
  ///
  /// This helps the processor determine how to handle the document (e.g., as `application/ld+json`).
  public let contentType: String?

  /// The raw HTTP `Link` header, if provided by the loader.
  ///
  /// This is used to resolve an associated JSON-LD context.
  public let linkHeader: String?

  /// Creates a remote document with metadata.
  public init(
    documentURL: String,
    document: JSONValue,
    contentType: String? = nil,
    linkHeader: String? = nil
  ) {
    self.documentURL = documentURL
    self.document = document
    self.contentType = contentType
    self.linkHeader = linkHeader
  }
}

/// A protocol for loading remote documents and contexts.
///
/// Implementations of this protocol provide the networking logic (e.g., using `URLSession` or `AsyncHTTPClient`)
/// allowing the JSON-LD processor to remain independent of specific networking stacks.
public protocol JSONLDDocumentLoader: Sendable {
  /// Loads a document from the specified URL.
  ///
  /// - Parameter url: The URL of the document to load.
  /// - Returns: A `Result` containing either a `RemoteDocument` on success or an `Error` on failure.
  func load(url: String) async -> Result<RemoteDocument, any Error>
}
