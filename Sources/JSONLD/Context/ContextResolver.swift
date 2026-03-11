// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

struct ContextResolver {
  let loader: (any JSONLDDocumentLoader)?
  let allowEmptyVocabMapping: Bool
  let allowRelativeVocabMapping: Bool

  init(
    loader: (any JSONLDDocumentLoader)?,
    allowEmptyVocabMapping: Bool = false,
    allowRelativeVocabMapping: Bool = false
  ) {
    self.loader = loader
    self.allowEmptyVocabMapping = allowEmptyVocabMapping
    self.allowRelativeVocabMapping = allowRelativeVocabMapping
  }

  func process(
    contexts: Contexts,
    activeContext: ActiveContext,
    remoteContexts: [String] = []
  ) async throws(JSONLDError) -> ActiveContext {
    var result = activeContext

    switch contexts {
    case .null:
      return .init(
        baseIRI: activeContext.originalBaseIRI, originalBaseIRI: activeContext.originalBaseIRI)
    case .single(let context):
      try await self.process(
        context: context, activeContext: &result, remoteContexts: remoteContexts)
    case .array(let contexts):
      for context in contexts {
        try await self.process(
          context: context, activeContext: &result, remoteContexts: remoteContexts)
      }
    }

    return result
  }

  private func process(
    context: Contexts.Element,
    activeContext: inout ActiveContext,
    remoteContexts: [String]
  ) async throws(JSONLDError) {
    switch context {
    case .absoluteIRI(let iri), .relativeIRI(let iri):
      let resolvedIRI = try activeContext.expandIRI(iri, asDocumentRelative: true)

      if remoteContexts.contains(resolvedIRI) {
        throw .code(.recursiveContextInclusion)
      }
      if remoteContexts.count >= ActiveContext.maxRemoteContexts {
        // TODO: Add processingMode and throw `.code(.contextOverflow)` in json-ld-1.1 mode.
        throw .internalError(
          .implementationLimitExceeded,
          debugInfo: .init(url: resolvedIRI))
      }

      var updatedRemoteContexts = remoteContexts
      updatedRemoteContexts.append(resolvedIRI)

      guard let loader = self.loader else {
        throw .code(
          .loadingRemoteContextFailed,
          debugInfo: .init(url: resolvedIRI, message: "document loader is not configured"))
      }

      let result = await loader.load(url: resolvedIRI)
      let remoteDocument: RemoteDocument =
        switch result {
        case .success(let doc):
          doc
        case .failure(let error):
          throw .code(
            .loadingRemoteContextFailed,
            debugInfo: .init(url: resolvedIRI, message: String(describing: error)))
        }

      guard case .object(let object) = remoteDocument.document,
        let innerContext = object[.context]
      else {
        throw .code(.invalidRemoteContext)
      }

      let remoteContext = try Contexts(from: innerContext)

      var subContext = activeContext
      subContext.baseIRI = remoteDocument.documentURL

      activeContext = try await self.process(
        contexts: remoteContext,
        activeContext: subContext,
        remoteContexts: updatedRemoteContexts
      )

    case .contextDefinition(let definition):
      try self.apply(contextDefinition: definition, to: &activeContext)
    }
  }

  private func apply(
    contextDefinition: Contexts.ContextDefinition, to activeContext: inout ActiveContext
  )
    throws(JSONLDError)
  {
    try activeContext.applyBaseIRI(contextDefinition.baseIRI)
    try activeContext.applyVocabMapping(
      contextDefinition.vocabMapping,
      allowEmptyMapping: self.allowEmptyVocabMapping,
      allowRelativeMapping: self.allowRelativeVocabMapping
    )
    activeContext.applyDefaultLanguage(contextDefinition.defaultLanguage)
    try activeContext.applyTerms(from: contextDefinition)
  }
}
