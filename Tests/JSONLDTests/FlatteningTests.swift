// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

@testable import JSONLD

@Suite(
  .disabled(if: TestCaseLoader.flatteningTestsManifest == nil, "Missing flatten test manifest"))
struct FlatteningTests {
  @Test(
    "[Flattening] Positive Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.flatteningTestsPositiveCases(version: .v1p0))
  func positiveEvaluationTestOneZero(testCase: FlattenTest.PositiveCase) throws {
    let document = try TestCaseLoader.load(testCase.input, type: JSONLDDocument.self)
    let context = try testCase.options.contextFilename.map { filename in
      try TestCaseLoader.load(filename, type: JSONLDDocument.self)
    }
    let actual = document.flatten(
      context: context,
      baseIRI: testCase.options.base,
      compactArrays: testCase.options.compactArrays
    )
    let expect = try TestCaseLoader.load(testCase.expectFilename, type: JSONValue.self)
    #expect(actual == expect)
  }

  @Test(
    "[Flattening] Positive Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.flatteningTestsPositiveCases(version: .v1p1))
  func positiveEvaluationTestOneOne(testCase: FlattenTest.PositiveCase) {}

  @Test(
    "[Flattening] Negative Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.flatteningTestsNegativeCases(version: .v1p0))
  func negativeEvaluationTestOneZero(testCase: FlattenTest.NegativeCase) throws {
    guard let expectError = JSONLDError(rawValue: testCase.expectErrorCode) else {
      Issue.record(
        "Missing JSONLDError case for expected error code: '\(testCase.expectErrorCode)'")
      return
    }

    #expect(throws: expectError) {
      let document = try TestCaseLoader.load(testCase.input, type: JSONLDDocument.self)
      let context = try testCase.options.contextFilename.map { filename in
        try TestCaseLoader.load(filename, type: JSONLDDocument.self)
      }
      _ = document.flatten(
        context: context,
        baseIRI: testCase.options.base,
        compactArrays: testCase.options.compactArrays
      )
    }
  }

  @Test(
    "[Flattening] Negative Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.flatteningTestsNegativeCases(version: .v1p1))
  func negativeEvaluationTestOneOne(testCase: FlattenTest.NegativeCase) {}
}
