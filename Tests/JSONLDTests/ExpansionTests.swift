// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Testing

@testable import JSONLD

@Suite(
  .disabled(if: TestCaseLoader.expansionTestsManifest == nil, "Missing expansion test manifest"))
struct ExpansionTests {
  @Test(
    "[Expansion] Positive Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.expansionTestsPositiveCases(version: .v1p0))
  func positiveEvaluationTestOneZero(testCase: ExpandTest.PositiveCase) async throws {
    let processor = JSONLDProcessor()
    processor.loader = TestDocumentLoader()

    let input = try TestCaseLoader.load(testCase.input, type: JSONLDValues<Unresolved>.self)
    let expandContext = try TestCaseLoader.loadContexts(testCase.options.expandContextFilename)
    // JSON-LD Test Suite base URL
    let manifestBase = "https://w3c.github.io/json-ld-api/tests/"
    let documentIRI = manifestBase + testCase.input

    let actual = try await processor.expand(
      input,
      expandContext: expandContext,
      baseIRI: testCase.options.base ?? documentIRI,
      normative: testCase.options.normative
    )

    let expect = try TestCaseLoader.load(
      testCase.expectFilename, type: JSONLDDocument<Unresolved>.self)
    #expect(actual.jsonValue == expect.jsonValue)
  }

  @Test(
    "[Expansion] Positive Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.expansionTestsPositiveCases(version: .v1p1))
  func positiveEvaluationTestOneOne(testCase: ExpandTest.PositiveCase) {}

  @Test(
    "[Expansion] Negative Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.expansionTestsNegativeCases(version: .v1p0))
  func negativeEvaluationTestOneZero(testCase: ExpandTest.NegativeCase) async throws {
    guard let expectError = JSONLDError.Code(rawValue: testCase.expectErrorCode) else {
      Issue.record(
        "Missing JSONLDError case for expected error code: '\(testCase.expectErrorCode)'")
      return
    }

    let processor = JSONLDProcessor()
    processor.loader = TestDocumentLoader()

    // JSON-LD Test Suite base URL
    let manifestBase = "https://w3c.github.io/json-ld-api/tests/"
    let documentIRI = manifestBase + testCase.input

    await #expect(throws: JSONLDError.code(expectError)) {
      let input = try TestCaseLoader.load(testCase.input, type: JSONLDValues<Unresolved>.self)
      let expandContext = try TestCaseLoader.loadContexts(testCase.options.expandContextFilename)
      _ = try await processor.expand(
        input,
        expandContext: expandContext,
        baseIRI: testCase.options.base ?? documentIRI,
        normative: testCase.options.normative
      )
    }
  }

  @Test(
    "[Expansion] Negative Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.expansionTestsNegativeCases(version: .v1p1))
  func negativeEvaluationTestOneOne(testCase: ExpandTest.NegativeCase) {}
}
