// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A processor for JSON-LD documents.
///
/// This class handles operations like expansion, compaction, and flattening.
/// It maintains configuration settings like the document loader.
public class JSONLDProcessor {
  /// The loader used to resolve remote documents and contexts.
  public var loader: any JSONLDDocumentLoader = DefaultLoader()

  public init() {}

  /// Expands the specified JSON-LD document.
  public func expand(
    _ document: JSONLDDocument<Unresolved>,
    expandContext: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    normative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Expanded> {
    let unresolvedValues = document.value.map(JSONLDValue<Unresolved>.node)

    let values = JSONLDValues<Unresolved>(.many(unresolvedValues))
    return try await self.expand(
      values,
      expandContext: expandContext,
      baseIRI: baseIRI ?? document.documentURL,
      normative: normative
    )
  }

  /// Expands a collection of JSON-LD values.
  public func expand(
    _ values: JSONLDValues<Unresolved>,
    expandContext: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    normative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Expanded> {
    var activeContext = ActiveContext.empty
    if let baseIRI {
      activeContext.baseIRI = baseIRI
      activeContext.originalBaseIRI = baseIRI
    }

    if let expandContext {
      for contexts in expandContext.value.compactMap(\.context) {
        activeContext = try await activeContext.process(
          localContext: contexts, loader: self.loader)
      }
    }

    let expanded = try await ExpansionProcessor.expand(
      activeContext,
      value: values.value,
      property: nil,
      loader: self.loader
    )

    var nodes: [NodeObject<Expanded>] = []
    for item in expanded {
      guard case .node(let node) = item else { continue }

      if let graph = node.graph,
        node.context == nil,
        node.id == nil,
        node.type == nil,
        node.reverse == nil,
        node.index == nil,
        node.properties.isEmpty
      {
        nodes.append(
          contentsOf: graph.compactMap {
            if case .node(let node) = $0 { node } else { nil }
          })
      } else {
        nodes.append(node)
      }
    }

    return JSONLDDocument<Expanded>(.init(nodes), documentURL: baseIRI)
  }

  /// Compacts the specified JSON-LD document.
  public func compact<P: JSONLDPhase>(
    _ document: JSONLDDocument<P>,
    context: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument<P> {
    _ = (context, baseIRI, compactArrays, compactToRelative)
    return document
  }

  /// Compacts a collection of JSON-LD values.
  public func compact<P: JSONLDPhase>(
    _ values: JSONLDValues<P>,
    context: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) throws(JSONLDError) -> JSONLDValues<P> {
    _ = (context, baseIRI, compactArrays, compactToRelative)
    return values
  }

  /// Flattens the specified JSON-LD document.
  public func flatten<P: JSONLDPhase>(
    _ document: JSONLDDocument<P>,
    context: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) throws(JSONLDError) -> JSONLDDocument<P> {
    _ = (context, baseIRI, compactArrays)
    return document
  }

  /// Flattens a collection of JSON-LD values.
  public func flatten<P: JSONLDPhase>(
    _ values: JSONLDValues<P>,
    context: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) throws(JSONLDError) -> JSONLDValues<P> {
    _ = (context, baseIRI, compactArrays)
    return values
  }

  /// Fetches a document from a URL and expands it.
  public func expand(
    url: String,
    expandContext: JSONLDDocument<Unresolved>? = nil,
    normative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Expanded> {
    let result = await self.loader.load(url: url)
    let remoteDocument: RemoteDocument =
      switch result {
      case .success(let doc):
        doc
      case .failure(let error):
        throw .code(
          .loadingRemoteContextFailed,
          debugInfo: .init(url: url, message: String(describing: error)))
      }

    let document = try JSONLDDocument<Unresolved>(from: remoteDocument.document)
    return try await self.expand(
      document,
      expandContext: expandContext,
      baseIRI: remoteDocument.documentURL,
      normative: normative
    )
  }
}

private struct DefaultLoader: JSONLDDocumentLoader {
  func load(url: String) async -> Result<RemoteDocument, any Error> {
    // TODO: Implementation of a default loader using URLSession or AsyncHTTPClient.
    .failure(
      JSONLDError.code(
        .loadingRemoteContextFailed,
        debugInfo: .init(url: url, message: "default loader is not implemented")))
  }
}
