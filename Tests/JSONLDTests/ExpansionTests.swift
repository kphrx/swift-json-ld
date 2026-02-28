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
    let input = try TestCaseLoader.load(testCase.input, type: JSONLDValues<Unresolved>.self)
    let expandContext = try testCase.options.expandContextFilename.map { filename in
      try TestCaseLoader.load(filename, type: JSONLDDocument<Unresolved>.self)
    }
    let actual = try await input.expand(
      expandContext: expandContext,
      baseIRI: testCase.options.base,
      normative: testCase.options.normative,
      loader: TestDocumentLoader()
    )
    let expect = try TestCaseLoader.load(
      testCase.expectFilename, type: JSONLDDocument<Expanded>.self)
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

    await #expect(throws: JSONLDError.code(expectError)) {
      let input = try TestCaseLoader.load(testCase.input, type: JSONLDValues<Unresolved>.self)
      let expandContext = try testCase.options.expandContextFilename.map { filename in
        try TestCaseLoader.load(filename, type: JSONLDDocument<Unresolved>.self)
      }
      _ = try await input.expand(
        expandContext: expandContext,
        baseIRI: testCase.options.base,
        normative: testCase.options.normative,
        loader: TestDocumentLoader()
      )
    }
  }

  @Test(
    "[Expansion] Negative Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.expansionTestsNegativeCases(version: .v1p1))
  func negativeEvaluationTestOneOne(testCase: ExpandTest.NegativeCase) {}
}
