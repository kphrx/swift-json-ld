// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Testing

@testable import JSONLD

@Suite(
  .disabled(if: TestCaseLoader.flatteningTestsManifest == nil, "Missing flatten test manifest")
)
struct FlatteningTests {
  @Test(
    "[Flattening] Positive Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.flatteningTestsPositiveCases(version: .v1p0)
  )
  func positiveEvaluationTestOneZero(testCase: FlattenTest.PositiveCase) async throws {
    let processor = JSONLDProcessor()
    processor.loader = TestDocumentLoader()
    let input = try TestCaseLoader.load(testCase.input, type: JSONLDValues<Unresolved>.self)
    let context = try TestCaseLoader.loadContexts(testCase.options.contextFilename)
    let manifestBase = "https://w3c.github.io/json-ld-api/tests/"
    let documentIRI = manifestBase + testCase.input

    let actual: JSONValue =
      if let context {
        try await processor.flatten(
          input,
          context: context,
          baseIRI: testCase.options.base ?? documentIRI,
          compactArrays: testCase.options.compactArrays
        ).jsonValue
      } else {
        try await processor.flatten(
          input,
          baseIRI: testCase.options.base ?? documentIRI
        ).jsonValue
      }
    let expect = try TestCaseLoader.load(
      testCase.expectFilename,
      type: JSONLDDocument<Unresolved>.self
    )
    #expect(actual == expect.jsonValue)
  }

  @Test(
    "[Flattening] Positive Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.flatteningTestsPositiveCases(version: .v1p1)
  )
  func positiveEvaluationTestOneOne(testCase: FlattenTest.PositiveCase) {}

  @Test(
    "[Flattening] Negative Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.flatteningTestsNegativeCases(version: .v1p0)
  )
  func negativeEvaluationTestOneZero(testCase: FlattenTest.NegativeCase) async throws {
    guard let expectError = JSONLDError.Code(rawValue: testCase.expectErrorCode) else {
      Issue.record(
        "Missing JSONLDError case for expected error code: '\(testCase.expectErrorCode)'"
      )
      return
    }

    let processor = JSONLDProcessor()
    processor.loader = TestDocumentLoader()
    let manifestBase = "https://w3c.github.io/json-ld-api/tests/"
    let documentIRI = manifestBase + testCase.input

    await #expect(throws: JSONLDError.code(expectError)) {
      let input = try TestCaseLoader.load(testCase.input, type: JSONLDValues<Unresolved>.self)
      let context = try TestCaseLoader.loadContexts(testCase.options.contextFilename)
      if let context {
        _ = try await processor.flatten(
          input,
          context: context,
          baseIRI: testCase.options.base ?? documentIRI,
          compactArrays: testCase.options.compactArrays
        )
      } else {
        _ = try await processor.flatten(
          input,
          baseIRI: testCase.options.base ?? documentIRI
        )
      }
    }
  }

  @Test(
    "[Flattening] Negative Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.flatteningTestsNegativeCases(version: .v1p1)
  )
  func negativeEvaluationTestOneOne(testCase: FlattenTest.NegativeCase) {}
}
