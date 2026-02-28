// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A structure representing a remote document.
public struct RemoteDocument: Sendable {
  /// The final URL of the document after any redirects.
  public let documentURL: String

  /// The content of the document as a `JSONValue`.
  public let document: JSONValue

  /// The content type of the document, if available.
  public let contentType: String?

  /// The URL of an associated JSON-LD context, typically from a `Link` header.
  public let contextURL: String?

  public init(
    documentURL: String,
    document: JSONValue,
    contentType: String? = nil,
    contextURL: String? = nil
  ) {
    self.documentURL = documentURL
    self.document = document
    self.contentType = contentType
    self.contextURL = contextURL
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
