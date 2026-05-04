// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public import Foundation

/// A structure representing a remote document and its associated metadata.
///
/// This structure encapsulates the result of a document loading operation,
/// providing the JSON content along with metadata required by the JSON-LD Processing Algorithms.
struct RemoteDocument: Sendable {
  /// The final URL of the document after any redirects.
  ///
  /// This URL is used as the base IRI for the document if no `@base` is specified
  /// within the document itself.
  let documentURL: String

  /// The content of the document as a `JSONValue`.
  ///
  /// For JSON-LD documents, this should be the parsed JSON structure.
  let document: JSONValue

  /// The content type of the document, if available.
  ///
  /// This helps the processor determine how to handle the document (e.g., as `application/ld+json`).
  let contentType: String?

  /// The URL of an associated JSON-LD context.
  ///
  /// This is typically retrieved from an HTTP `Link` header with the
  /// `http://www.w3.org/ns/json-ld#context` relation.
  let contextURL: String?

  private init(
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

  private static let contextRelation = "http://www.w3.org/ns/json-ld#context"

  static func load(
    url: String,
    using loader: any JSONLDDocumentLoader,
    failureCode: JSONLDError.Code = .loadingRemoteContextFailed
  ) async throws(JSONLDError) -> Self {
    let result = await loader.load(url: url)
    let response: RemoteDocumentResponse =
      switch result {
      case .success(let response):
        response
      case .failure(let error):
        throw .code(
          failureCode,
          debugInfo: .init(url: url, message: String(describing: error))
        )
      }

    if !Self.isJSONMediaType(response.contentType) {
      let alternateLinks = response.linkHeaders.filter({ $0.relations.contains("alternate") })
      if let alternate = alternateLinks.first, alternate.type == "application/ld+json" {
        return try await Self.load(
          url: Self.resolveIRI(alternate.target, against: response.documentURL),
          using: loader,
          failureCode: failureCode
        )
      }
    }

    return try Self.fromResponse(response)
  }

  static func fromResponse(_ response: RemoteDocumentResponse) throws(JSONLDError) -> Self {
    let mediaType = Self.mediaType(from: response.contentType)
    guard Self.isJSONMediaType(mediaType) else {
      throw .code(.loadingDocumentFailed, debugInfo: .init(url: response.documentURL))
    }

    let contextURL: String?
    if mediaType == "application/ld+json" {
      contextURL = nil
    } else {
      let contextLinks = response.linkHeaders.filter({ $0.relations.contains(Self.contextRelation) }
      )
      guard contextLinks.count <= 1 else {
        throw .code(.multipleContextLinkHeaders, debugInfo: .init(url: response.documentURL))
      }
      contextURL = contextLinks.first.flatMap {
        Self.resolveIRI($0.target, against: response.documentURL)
      }
    }

    let document: JSONValue
    do {
      document = try JSONDecoder().decode(JSONValue.self, from: response.body)
    } catch {
      throw .code(
        .loadingDocumentFailed,
        debugInfo: .init(url: response.documentURL, message: String(describing: error))
      )
    }

    return Self(
      documentURL: response.documentURL,
      document: document,
      contentType: mediaType,
      contextURL: contextURL
    )
  }

  private static func mediaType(from contentType: String?) -> String? {
    contentType?
      .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
      .first?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  private static func isJSONMediaType(_ mediaType: String?) -> Bool {
    guard let mediaType else { return true }
    return mediaType == "application/json"
      || mediaType == "application/ld+json"
      || mediaType.hasPrefix("application/")
        && mediaType.hasSuffix("+json")
  }

  private static func resolveIRI(_ iri: String, against baseIRI: String) -> String {
    guard let baseURL = URL(string: baseIRI),
      let resolvedURL = URL(string: iri, relativeTo: baseURL)
    else {
      return iri
    }
    return resolvedURL.absoluteString
  }
}

extension CharacterSet {
  static let doubleQuote = Self(charactersIn: "\"")
}

/// A raw HTTP response loaded by a JSON-LD document loader.
///
/// The loader is responsible for fetching bytes and response metadata only. JSON-LD-specific
/// interpretation, such as content type checks and `Link` header processing, is performed by
/// the JSON-LD processor.
public struct RemoteDocumentResponse: Sendable {
  public struct LinkHeader: Sendable {
    let target: String
    let relations: [String]
    let type: String?

    init?(_ value: Substring) {
      let parts = value.split(separator: ";").map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
      }

      self.init(target: parts.first, parameter: parts.dropFirst())
    }

    init?(_ value: String) {
      let parts = value.split(separator: ";").map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
      }

      self.init(target: parts.first, parameter: parts.dropFirst())
    }

    private init?(target targetPart: String?, parameter parameterParts: ArraySlice<String>) {
      guard let targetPart, targetPart.hasPrefix("<"), targetPart.hasSuffix(">") else {
        return nil
      }

      self.target = String(targetPart.dropFirst().dropLast())
      self.relations = parameterParts.compactMap { parameter -> [String]? in
        let pair = parameter.split(separator: "=", maxSplits: 1).map(String.init)
        guard pair.count == 2, pair[0].lowercased() == "rel" else {
          return nil
        }
        return pair[1].trimmingCharacters(in: .doubleQuote)
          .split(separator: " ")
          .map(String.init)
      }.flatMap { $0 }
      self.type =
        parameterParts.compactMap { parameter -> String? in
          let pair = parameter.split(separator: "=", maxSplits: 1).map(String.init)
          guard pair.count == 2, pair[0].lowercased() == "type" else {
            return nil
          }
          return pair[1].trimmingCharacters(in: .doubleQuote)
        }.first
    }
  }

  /// The final URL of the document after any redirects.
  public let documentURL: String

  /// The raw response body.
  public let body: Data

  /// The HTTP `Content-Type` header value, if available.
  public let contentType: String?

  /// The HTTP `Link` header values, if available.
  public let linkHeaders: [LinkHeader]

  /// Creates a raw remote document response.
  public init(
    documentURL: String,
    body: Data,
    contentType: String? = nil,
    linkHeaders: String? = nil
  ) {
    self.documentURL = documentURL
    self.body = body
    self.contentType = contentType
    self.linkHeaders = linkHeaders?.split(separator: ",").compactMap(LinkHeader.init(_:)) ?? []
  }

  /// Creates a raw remote document response.
  public init(
    documentURL: String,
    body: Data,
    contentType: String? = nil,
    linkHeaders: [String]
  ) {
    self.documentURL = documentURL
    self.body = body
    self.contentType = contentType
    self.linkHeaders = linkHeaders.flatMap {
      $0.split(separator: ",").compactMap(LinkHeader.init(_:))
    }
  }
}

/// A protocol for loading remote documents and contexts.
///
/// Implementations provide HTTP transport (e.g. `URLSession` or `AsyncHTTPClient`) while the
/// JSON-LD module remains responsible for interpreting response headers and the response body.
public protocol JSONLDDocumentLoader: Sendable {
  /// Loads a document from the specified URL.
  ///
  /// - Parameter url: The URL of the document to load.
  /// - Returns: A `Result` containing either the raw HTTP response on success or an `Error` on failure.
  func load(url: String) async -> Result<RemoteDocumentResponse, any Error>
}
