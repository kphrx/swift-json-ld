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
  public func compact(
    _ document: JSONLDDocument<Unresolved>,
    context: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Compacted> {
    try await self.compact(
      document.values,
      context: context,
      baseIRI: baseIRI ?? document.documentURL,
      compactArrays: compactArrays,
      compactToRelative: compactToRelative
    )
  }

  /// Compacts a collection of JSON-LD values.
  public func compact(
    _ values: JSONLDValues<Unresolved>,
    context: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Compacted> {
    try CompactionAlgorithm.validateInvalidCompactionInputs(values)
    let expanded = try await self.expandValues(values, baseIRI: baseIRI)
    let normalizedInput = try JSONLDValues<Unresolved>(from: expanded.jsonValue)
    let algorithm = try CompactionAlgorithm(
      context: context,
      options: .init(
        baseIRI: baseIRI, compactArrays: compactArrays, compactToRelative: compactToRelative)
    )
    return try algorithm.compact(normalizedInput)
  }

  /// Flattens the specified JSON-LD document.
  public func flatten(
    _ document: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil
  ) async throws(JSONLDError) -> JSONLDDocument<Flattened> {
    try await self.flatten(
      document.values,
      baseIRI: baseIRI ?? document.documentURL
    )
  }

  /// Flattens a collection of JSON-LD values.
  public func flatten(
    _ values: JSONLDValues<Unresolved>,
    baseIRI: String? = nil
  ) async throws(JSONLDError) -> JSONLDDocument<Flattened> {
    let expanded = try await self.expandValues(values, baseIRI: baseIRI)
    let expandedDocument = JSONLDDocument<Expanded>(normalizing: expanded, documentURL: baseIRI)
    return try FlatteningAlgorithm.run(expandedDocument)
  }

  /// Flattens and compacts the specified JSON-LD document.
  public func flatten(
    _ document: JSONLDDocument<Unresolved>,
    context: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Compacted> {
    try await self.flatten(
      document.values,
      context: context,
      baseIRI: baseIRI ?? document.documentURL,
      compactArrays: compactArrays
    )
  }

  /// Flattens and compacts a collection of JSON-LD values.
  public func flatten(
    _ values: JSONLDValues<Unresolved>,
    context: JSONLDDocument<Unresolved>,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Compacted> {
    let flattened = try await self.flatten(values, baseIRI: baseIRI)
    let algorithm = try CompactionAlgorithm(
      context: context,
      options: .init(baseIRI: baseIRI, compactArrays: compactArrays, compactToRelative: true)
    )
    return try algorithm.compact(try .init(from: flattened.jsonValue))
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
