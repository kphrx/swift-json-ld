// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A processor for JSON-LD documents.
///
/// This class handles operations like expansion, compaction, and flattening.
/// It maintains configuration settings like the document loader.
public class JSONLDProcessor {
  /// A JSON-LD processing mode supported by ``JSONLDProcessor``.
  ///
  /// Processing mode selects the version-specific behavior used by JSON-LD algorithms.
  /// The processor currently supports only JSON-LD 1.0, and callers must choose that
  /// mode explicitly so future JSON-LD 1.1 support can be introduced without changing
  /// the meaning of existing initializers.
  public enum ProcessingMode: String {
    /// JSON-LD 1.0 processing mode.
    case v1p0 = "json-ld-1.0"

    /// JSON-LD 1.1 processing mode.
    ///
    /// This case is reserved for the future and is unavailable until JSON-LD 1.1
    /// algorithms are implemented.
    @available(*, unavailable, message: "Unsupported JSON-LD 1.1 processing mode")
    case v1p1 = "json-ld-1.1"
  }

  /// The processing mode changes the behavior of processing algorithms.
  public let mode: ProcessingMode

  /// The loader used to resolve remote documents and contexts.
  public let loader: (any JSONLDDocumentLoader)?

  /// Creates a JSON-LD processor.
  ///
  /// - Parameters:
  ///   - mode: The JSON-LD processing mode to use. Pass ``ProcessingMode/v1p0`` to run the
  ///     currently supported JSON-LD 1.0 algorithms.
  ///   - loader: The document loader used to resolve remote documents and contexts. If no
  ///     loader is provided, remote loading is disabled.
  public init(mode: ProcessingMode, loader: (any JSONLDDocumentLoader)? = nil) {
    self.mode = mode
    self.loader = loader
  }

  /// Expands the specified JSON-LD document.
  public func expand(
    _ document: JSONLDDocument<Unresolved>,
    expandContext: Contexts? = nil,
    baseIRI: String? = nil,
    normative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Expanded> {
    try await self.expand(
      document.values,
      expandContext: expandContext,
      baseIRI: baseIRI ?? document.documentURL,
      normative: normative
    )
  }

  /// Expands a collection of JSON-LD values.
  public func expand(
    _ values: JSONLDValues<Unresolved>,
    expandContext: Contexts? = nil,
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
    expandContext: Contexts? = nil,
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
    context: Contexts,
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
    context: Contexts,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Compacted> {
    try CompactionAlgorithm.validateInvalidCompactionInputs(values)
    let expanded = try await self.expandValues(values, baseIRI: baseIRI)
    let activeContext = try await self.resolveActiveContext(context: context, baseIRI: baseIRI)
    let algorithm = CompactionAlgorithm(
      activeContext: activeContext,
      contextValue: context.jsonValue,
      options: .init(
        baseIRI: baseIRI,
        compactArrays: compactArrays,
        compactToRelative: compactToRelative
      )
    )
    return try algorithm.compact(expanded)
  }

  /// Compacts expanded JSON-LD values.
  public func compact(
    _ values: JSONLDValues<Expanded>,
    context: Contexts,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Compacted> {
    let activeContext = try await self.resolveActiveContext(context: context, baseIRI: baseIRI)
    let algorithm = CompactionAlgorithm(
      activeContext: activeContext,
      contextValue: context.jsonValue,
      options: .init(
        baseIRI: baseIRI,
        compactArrays: compactArrays,
        compactToRelative: compactToRelative
      )
    )
    return try algorithm.compact(values)
  }

  /// Compacts flattened JSON-LD values.
  public func compact(
    _ values: JSONLDValues<Flattened>,
    context: Contexts,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Compacted> {
    let activeContext = try await self.resolveActiveContext(context: context, baseIRI: baseIRI)
    let algorithm = CompactionAlgorithm(
      activeContext: activeContext,
      contextValue: context.jsonValue,
      options: .init(
        baseIRI: baseIRI,
        compactArrays: compactArrays,
        compactToRelative: compactToRelative
      )
    )
    return try algorithm.compact(values)
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
    return try self.flatten(.init(normalizing: expanded, documentURL: baseIRI))
  }

  /// Flattens the specified expanded JSON-LD document.
  public func flatten(
    _ document: JSONLDDocument<Expanded>
  ) throws(JSONLDError) -> JSONLDDocument<Flattened> {
    try FlatteningAlgorithm.run(document)
  }

  /// Flattens and compacts the specified JSON-LD document.
  public func flatten(
    _ document: JSONLDDocument<Unresolved>,
    context: Contexts,
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
    context: Contexts,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Compacted> {
    let flattened = try await self.flatten(values, baseIRI: baseIRI)
    return try await self.compact(
      flattened.values,
      context: context,
      baseIRI: baseIRI,
      compactArrays: compactArrays,
      compactToRelative: true
    )
  }

  /// Fetches a document from a URL and expands it.
  public func expand(
    url: String,
    expandContext: Contexts? = nil,
    normative: Bool = true
  ) async throws(JSONLDError) -> JSONLDDocument<Expanded> {
    guard let loader = self.loader else {
      throw .code(
        .loadingDocumentFailed,
        debugInfo: .init(url: url, message: "document loader is not configured")
      )
    }

    let remoteDocument = try await RemoteDocument.load(
      url: url,
      using: loader,
      failureCode: .loadingDocumentFailed
    )

    let document = try JSONLDDocument<Unresolved>(from: remoteDocument.document)
    let remoteContext: Contexts? =
      if let contextURL = remoteDocument.contextURL {
        if let expandContext {
          .single(.init(iri: contextURL)) + expandContext
        } else {
          .single(.init(iri: contextURL))
        }
      } else {
        expandContext
      }
    return try await self.expand(
      document,
      expandContext: remoteContext,
      baseIRI: remoteDocument.documentURL,
      normative: normative
    )
  }
}

extension JSONLDProcessor {
  private func resolveActiveContext(
    context: Contexts,
    baseIRI: String?
  ) async throws(JSONLDError) -> ActiveContext {
    var activeContext = ActiveContext.empty
    if let baseIRI {
      activeContext.baseIRI = baseIRI
      activeContext.originalBaseIRI = baseIRI
    }
    return try await ContextResolver(
      loader: self.loader,
      allowEmptyVocabMapping: true,
      allowRelativeVocabMapping: true
    ).process(
      contexts: context,
      activeContext: activeContext
    )
  }
}
