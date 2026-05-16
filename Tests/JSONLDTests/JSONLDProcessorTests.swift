// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Testing

@testable import JSONLD

struct JSONLDProcessorTests {
  @Test("Expect `loading document failed` error to load without document loader")
  func loadRemoteDocumentWithoutLoader() async {
    let processor = JSONLDProcessor(mode: .v1p0)

    await #expect(throws: JSONLDError.code(.loadingDocumentFailed)) {
      _ = try await processor.expand(url: "https://example.com/document")
    }
  }
}
