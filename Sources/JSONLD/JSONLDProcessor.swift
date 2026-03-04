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
  ) async throws(JSONLDError) -> JSONLDDocument<Unresolved> {
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
  ) async throws(JSONLDError) -> JSONLDDocument<Unresolved> {
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
    let expanded = try await self.expandValues(values, baseIRI: baseIRI)
    let expandedDocument = JSONLDDocument<Expanded>(normalizing: expanded, documentURL: baseIRI)
    let flattened = try FlatteningAlgorithm.run(expandedDocument)
    if let context {
      return try self.compactFlattenedDocument(
        flattened,
        with: context,
        compactArrays: compactArrays
      )
    }
    return flattened
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

extension JSONLDProcessor {
  private func compactFlattenedDocument(
    _ document: JSONLDDocument<Unresolved>,
    with contextDocument: JSONLDDocument<Unresolved>,
    compactArrays: Bool
  ) throws(JSONLDError) -> JSONLDDocument<Unresolved> {
    let firstContextNode = Array(contextDocument.value).first
    guard
      let context = firstContextNode?.context,
      case .object(let contextObject) = context.jsonValue,
      case .array(let graphArray) = document.jsonValue
    else {
      return document
    }

    var iriToTerm: [String: String] = [:]
    for (term, value) in contextObject {
      if let iri = self.termIRI(from: value) {
        iriToTerm[iri] = term
      }
    }

    let compactedGraph = graphArray.map { item in
      if case .object(let node) = item {
        return JSONValue.object(
          self.compactNode(node, iriToTerm: iriToTerm, compactArrays: compactArrays))
      }
      return item
    }

    let compacted: JSONValue = .object([
      JSONLDKeyword.context.rawValue: context.jsonValue,
      JSONLDKeyword.graph.rawValue: .array(compactedGraph),
    ])
    return try .init(from: compacted)
  }

  private func compactNode(
    _ node: JSONObject,
    iriToTerm: [String: String],
    compactArrays: Bool
  ) -> JSONObject {
    var result: JSONObject = [:]
    for (key, value) in node {
      let compactedKey = iriToTerm[key] ?? key
      result[compactedKey] = self.compactValue(value, compactArrays: compactArrays)
    }
    return result
  }

  private func compactValue(_ value: JSONValue, compactArrays: Bool) -> JSONValue {
    switch value {
    case .array(let array):
      let compacted = array.map { item in
        if case .object(let object) = item,
          object.count == 1,
          let value = object[JSONLDKeyword.value.rawValue]
        {
          return value
        }
        return item
      }
      if compactArrays, compacted.count == 1 {
        return compacted[0]
      }
      return .array(compacted)
    default:
      return value
    }
  }

  private func termIRI(from value: JSONValue) -> String? {
    if case .string(let iri) = value {
      return iri
    }
    if case .object(let object) = value,
      let id = object[JSONLDKeyword.id.rawValue],
      case .string(let iri) = id
    {
      return iri
    }
    return nil
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
