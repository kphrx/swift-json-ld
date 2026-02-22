// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

@testable import JSONLD

@Suite(
  .disabled(if: TestCaseLoader.expansionTestsManifest == nil, "Missing expansion test manifest"))
struct ExpansionTests {
  @Test(
    "[Expansion] Positive Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.expansionTestsPositiveCases(version: .v1p0))
  func positiveEvaluationTestOneZero(testCase: ExpandTest.PositiveCase) throws {
    let document = try TestCaseLoader.load(testCase.input, type: JSONLDDocument.self)
    let expandContext = try testCase.options.expandContextFilename.map { filename in
      try TestCaseLoader.load(filename, type: JSONLDDocument.self)
    }
    let actual = try document.expand(
      expandContext: expandContext,
      baseIRI: testCase.options.base,
      normative: testCase.options.normative
    )
    let expect = try TestCaseLoader.load(testCase.expectFilename, type: JSONValue.self)
    #expect(actual == expect)
  }

  @Test(
    "[Expansion] Positive Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.expansionTestsPositiveCases(version: .v1p1))
  func positiveEvaluationTestOneOne(testCase: ExpandTest.PositiveCase) {}

  @Test(
    "[Expansion] Negative Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.expansionTestsNegativeCases(version: .v1p0))
  func negativeEvaluationTestOneZero(testCase: ExpandTest.NegativeCase) throws {
    guard let expectError = JSONLDError(rawValue: testCase.expectErrorCode) else {
      Issue.record(
        "Missing JSONLDError case for expected error code: '\(testCase.expectErrorCode)'")
      return
    }

    #expect(throws: expectError) {
      let document = try TestCaseLoader.load(testCase.input, type: JSONLDDocument.self)
      let expandContext = try testCase.options.expandContextFilename.map { filename in
        try TestCaseLoader.load(filename, type: JSONLDDocument.self)
      }
      _ = try document.expand(
        expandContext: expandContext,
        baseIRI: testCase.options.base,
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
