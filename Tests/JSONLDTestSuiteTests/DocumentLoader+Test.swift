// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation
import JSONLD

struct TestDocumentLoader: JSONLDDocumentLoader {
  enum Error: Swift.Error {
    case unknown(url: String)
    case unknown(error: Swift.Error)
  }

  func load(url: String) async -> Result<RemoteDocumentResponse, any Swift.Error> {
    let base = "https://w3c.github.io/json-ld-api/tests/"
    guard url.hasPrefix(base) else {
      return .failure(Error.unknown(url: url))
    }
    let relativePath = String(url.dropFirst(base.count))

    do {
      let body = try TestCaseLoader.loadData(String(url.dropFirst(base.count)))
      return .success(
        RemoteDocumentResponse(
          documentURL: url,
          body: body,
          contentType: Self.contentType(for: relativePath)
        )
      )
    } catch let error {
      return .failure(Error.unknown(error: error))
    }
  }

  private static func contentType(for path: String) -> String? {
    if path.hasSuffix(".json") {
      "application/json"
    } else if path.hasSuffix(".jsonld") {
      "application/ld+json"
    } else if path.hasSuffix(".html") {
      "text/html"
    } else if path.hasSuffix(".nq") {
      "application/n-quads"
    } else {
      nil
    }
  }
}
