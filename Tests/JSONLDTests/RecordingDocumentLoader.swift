// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import JSONLD

actor RecordingDocumentLoader: JSONLDDocumentLoader {
  struct Request: Equatable {
    let url: String
    let requestProfile: String?
  }

  private let response: Result<RemoteDocumentResponse, any Error>
  private var recordedRequests: [Request] = []

  init(response: Result<RemoteDocumentResponse, any Error>) {
    self.response = response
  }

  func load(
    url: String,
    requestProfile: String?
  ) async -> Result<
    RemoteDocumentResponse, any Error
  > {
    self.recordedRequests.append(.init(url: url, requestProfile: requestProfile))
    return self.response
  }

  func requests() -> [Request] {
    self.recordedRequests
  }
}
