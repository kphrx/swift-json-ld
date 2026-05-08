// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public import Foundation

struct RemoteDocument: Sendable {
  let documentURL: String
  let document: JSONValue
  let contentType: String?
  let profile: String?
  let contextURL: String?

  private init(
    documentURL: String,
    document: JSONValue,
    contentType: String? = nil,
    profile: String? = nil,
    contextURL: String? = nil
  ) {
    self.documentURL = documentURL
    self.document = document
    self.contentType = contentType
    self.profile = contentType
    self.contextURL = contextURL
  }

  static let contextProfile = "http://www.w3.org/ns/json-ld#context"

  static func load(
    url: String,
    using loader: any JSONLDDocumentLoader,
    requestProfile: String? = nil,
    failureCode: JSONLDError.Code = .loadingRemoteContextFailed
  ) async throws(JSONLDError) -> Self {
    let result = await loader.load(url: url, requestProfile: requestProfile)
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

    if !response.isJSON {
      let alternateLinks = response.linkHeaders.filter({ $0.relations.contains("alternate") })
      if let alternate = alternateLinks.first, alternate.type == "application/ld+json" {
        return try await Self.load(
          url: Self.resolveIRI(alternate.target, against: response.documentURL),
          using: loader,
          requestProfile: requestProfile,
          failureCode: failureCode
        )
      }
    }

    return try Self.fromResponse(response, failureCode: failureCode)
  }

  static func fromResponse(
    _ response: RemoteDocumentResponse,
    failureCode: JSONLDError.Code = .loadingDocumentFailed
  ) throws(JSONLDError) -> Self {
    let documentURL = response.documentURL
    guard response.isJSON else {
      throw .code(failureCode, debugInfo: .init(url: documentURL))
    }

    let mediaType = response.mediaType
    let contextLinks = response.linkHeaders.filter { $0.relations.contains(Self.contextProfile) }
    let contextURL: String? =
      if mediaType == "application/ld+json" {
        nil
      } else if contextLinks.count <= 1 {
        contextLinks.first.flatMap { Self.resolveIRI($0.target, against: documentURL) }
      } else {
        throw .code(.multipleContextLinkHeaders, debugInfo: .init(url: documentURL))
      }

    do {
      let document = try JSONDecoder().decode(JSONValue.self, from: response.body)
      return Self(
        documentURL: documentURL,
        document: document,
        contentType: mediaType,
        profile: response.profile,
        contextURL: contextURL
      )
    } catch {
      throw .code(
        failureCode,
        debugInfo: .init(url: documentURL, message: String(describing: error))
      )
    }
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
  /// A parsed HTTP `Link` header value from a remote document response.
  ///
  /// JSON-LD uses `Link` headers to discover alternate JSON-LD documents and external contexts.
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

  var parsedContentType: (type: String, parameter: [String: String])? {
    guard let contentType = self.contentType else { return nil }
    let parts = contentType.split(separator: ";").map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard let mediaType = parts.first?.lowercased() else { return nil }
    return (
      type: mediaType,
      parameter: .init(
        uniqueKeysWithValues: parts.dropFirst().compactMap {
          let pair = $0.split(separator: "=", maxSplits: 1).map(String.init)
          guard pair.count == 2 else { return nil }
          return (pair[0].lowercased(), pair[1].trimmingCharacters(in: .doubleQuote))
        }
      )
    )
  }

  var mediaType: String? {
    self.parsedContentType?.type
  }

  var profile: String? {
    self.parsedContentType?.parameter["profile"]
  }

  var isJSON: Bool {
    guard let mediaType = self.mediaType else { return false }
    return mediaType == "application/json"
      || mediaType == "application/ld+json"
      || mediaType.hasPrefix("application/")
        && mediaType.hasSuffix("+json")
  }

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
  /// Loads a document from the specified URL with a requested profile.
  ///
  /// - Parameters:
  ///   - url: The URL of the document to load.
  ///   - requestProfile: The preferred media type profile, if any.
  /// - Returns: A `Result` containing either the raw HTTP response on success or an `Error` on failure.
  func load(
    url: String,
    requestProfile: String?
  ) async -> Result<RemoteDocumentResponse, any Error>
}
