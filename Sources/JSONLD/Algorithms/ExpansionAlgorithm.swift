// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct ExpansionAlgorithm {
  struct Input {
    let values: JSONLDValues<Unresolved>
    let expandContext: Contexts?
    let baseIRI: String?
    let normative: Bool
  }

  static func run(
    _ input: Input,
    loader: (any JSONLDDocumentLoader)?
  ) async throws(JSONLDError) -> JSONLDValues<Expanded> {
    _ = input.normative

    var activeContext = ActiveContext.empty
    if let baseIRI = input.baseIRI {
      activeContext.baseIRI = baseIRI
      activeContext.originalBaseIRI = baseIRI
    }

    if let expandContext = input.expandContext {
      activeContext = try await activeContext.process(contexts: expandContext, loader: loader)
    }

    let expanded = try await ExpansionProcessor.expand(
      activeContext,
      value: input.values.value,
      property: nil,
      loader: loader
    )

    return .init(.many(expanded))
  }
}
