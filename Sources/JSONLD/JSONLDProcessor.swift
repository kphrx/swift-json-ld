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
    return try await self.expand(
      document.values,
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
    let expandedValues = try await self.expandValues(
      values,
      expandContext: expandContext,
      baseIRI: baseIRI,
      normative: normative
    )

    return .init(normalizing: expandedValues, documentURL: baseIRI)
  }

  /// Expands a collection of JSON-LD values and returns expanded values without document normalization.
  public func expandValues(
    _ values: JSONLDValues<Unresolved>,
    expandContext: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    normative: Bool = true
  ) async throws(JSONLDError) -> JSONLDValues<Expanded> {
    try await ExpansionAlgorithm.run(
      .init(
        values: values,
        expandContext: expandContext,
        baseIRI: baseIRI,
        normative: normative
      ),
      loader: self.loader
    )
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
  public func flatten(
    _ document: JSONLDDocument<Unresolved>,
    context: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Unresolved> {
    try await self.flatten(
      document.values,
      context: context,
      baseIRI: baseIRI ?? document.documentURL,
      compactArrays: compactArrays
    )
  }

  /// Flattens a collection of JSON-LD values.
  public func flatten(
    _ values: JSONLDValues<Unresolved>,
    context: JSONLDDocument<Unresolved>? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Unresolved> {
    _ = compactArrays
    // TODO: If context is specified, apply compaction after flattening.
    _ = context

    let expanded = try await self.expandValues(values, baseIRI: baseIRI)
    let expandedDocument = JSONLDDocument<Expanded>(normalizing: expanded, documentURL: baseIRI)
    return FlatteningAlgorithm.run(expandedDocument)
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
