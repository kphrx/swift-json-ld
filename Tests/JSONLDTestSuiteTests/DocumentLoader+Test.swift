// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation
import JSONLD

struct TestDocumentLoader: JSONLDDocumentLoader {
  enum Error: Swift.Error {
    case unknown(url: String)
    case unknown(error: Swift.Error)
  }

  func load(url: String) async -> Result<RemoteDocument, any Swift.Error> {
    let base = "https://w3c.github.io/json-ld-api/tests/"
    guard url.hasPrefix(base) else {
      return .failure(Error.unknown(url: url))
    }
    let relativePath = String(url.dropFirst(base.count))

    do {
      let document = try TestCaseLoader.load(relativePath, type: JSONValue.self)
      return .success(RemoteDocument(documentURL: url, document: document))
    } catch let error {
      return .failure(Error.unknown(error: error))
    }
  }
}
