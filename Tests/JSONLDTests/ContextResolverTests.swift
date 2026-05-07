// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

@testable import JSONLD

struct ContextResolverTests {
  @Test(
    "Expect `loading remote context failed` error to load remote context without document loader"
  )
  func loadRemoteContextWithoutLoader() async {
    await #expect(throws: JSONLDError.code(.loadingRemoteContextFailed)) {
      _ = try await ContextResolver(loader: nil).process(
        contexts: "https://example.com/context",
        activeContext: .empty
      )
    }
  }

  @Test("Load remote context with document loader")
  func loadRemoteContext() async throws {
    let loader = RecordingDocumentLoader(
      response: .success(
        RemoteDocumentResponse(
          documentURL: "https://example.com/context",
          body: #"{"@context":{"term":"https://example.com/term"}}"#.data(using: .utf8)!,
          contentType: "application/ld+json"
        )
      )
    )

    _ = try await ContextResolver(loader: loader).process(
      contexts: "https://example.com/context",
      activeContext: .empty
    )

    let requests = await loader.requests()
    #expect(
      requests == [
        .init(
          url: "https://example.com/context",
          requestProfile: "http://www.w3.org/ns/json-ld#context"
        )
      ]
    )
  }

  @Test("Remote context invalid json")
  func loadInvalidJSONRemoteContext() async {
    let loader = RecordingDocumentLoader(
      response: .success(
        RemoteDocumentResponse(
          documentURL: "https://example.com/context",
          body: #"{"@context":"#.data(using: .utf8)!,
          contentType: "application/ld+json"
        )
      )
    )

    await #expect(throws: JSONLDError.code(.loadingRemoteContextFailed)) {
      _ = try await ContextResolver(loader: loader).process(
        contexts: "https://example.com/context",
        activeContext: .empty
      )
    }
  }

  @Test("Remote context missing `@context` field")
  func loadRemoteContextMissingContextField() async {
    let loader = RecordingDocumentLoader(
      response: .success(
        RemoteDocumentResponse(
          documentURL: "https://example.com/context",
          body: #"{"term":"https://example.com/term"}"#.data(using: .utf8)!,
          contentType: "application/ld+json"
        )
      )
    )

    await #expect(throws: JSONLDError.code(.invalidRemoteContext)) {
      _ = try await ContextResolver(loader: loader).process(
        contexts: "https://example.com/context",
        activeContext: .empty
      )
    }
  }
}
