// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

#if canImport(FoundationNetworking)
import Foundation
public import class FoundationNetworking.URLSession
public import class FoundationNetworking.HTTPURLResponse
public import struct FoundationNetworking.URLRequest
#else
public import Foundation
#endif

/// A reference document loader backed by `URLSession`.
///
/// This loader is opt-in. Assign an instance to `JSONLDProcessor.loader` to enable
/// remote document loading with Swift Concurrency.
public struct URLSessionDocumentLoader: JSONLDDocumentLoader {
  /// The session used to perform network requests.
  public let session: URLSession

  /// Creates a URLSession-backed document loader.
  public init(session: URLSession = .shared) {
    self.session = session
  }

  /// Loads a remote JSON-LD document from the specified URL.
  public func load(
    url: String,
    requestProfile: String?
  ) async -> Result<RemoteDocumentResponse, any Error> {
    guard let requestURL = URL(string: url) else {
      return .failure(URLError(.badURL))
    }

    do {
      var request = URLRequest(url: requestURL)
      if let requestProfile {
        request.setValue(
          #"application/ld+json;profile="\#(requestProfile)", application/ld+json, application/json"#,
          forHTTPHeaderField: "Accept"
        )
      }

      let (data, response) = try await self.session.data(for: request)

      let httpResponse = response as? HTTPURLResponse
      let responseURL = httpResponse?.url ?? response.url ?? requestURL
      let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type")
      let linkHeader = httpResponse?.value(forHTTPHeaderField: "Link")

      return .success(
        RemoteDocumentResponse(
          documentURL: responseURL.absoluteString,
          body: data,
          contentType: contentType,
          linkHeaders: linkHeader
        )
      )
    } catch {
      return .failure(error)
    }
  }
}
