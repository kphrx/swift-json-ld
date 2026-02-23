// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

@testable import JSONLD

@Suite(
  .disabled(if: TestCaseLoader.compactionTestsManifest == nil, "Missing compaction test manifest"))
struct CompactionTests {
  @Test(
    "[Compaction] Positive Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.compactionTestsPositiveCases(version: .v1p0))
  func positiveEvaluationTestOneZero(testCase: CompactTest.PositiveCase) throws {
    let document = try TestCaseLoader.load(testCase.input, type: JSONLDDocument.self)
    let context = try TestCaseLoader.load(
      testCase.options.contextFilename, type: JSONLDDocument.self)
    let actual = document.compact(
      context: context,
      baseIRI: testCase.options.base,
      compactArrays: testCase.options.compactArrays,
      compactToRelative: testCase.options.compactToRelative
    )
    let expect = try TestCaseLoader.load(testCase.expectFilename, type: JSONValue.self)
    #expect(actual == expect)
  }

  @Test(
    "[Compaction] Positive Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.compactionTestsPositiveCases(version: .v1p1))
  func positiveEvaluationTestOneOne(testCase: CompactTest.PositiveCase) {}

  @Test(
    "[Compaction] Negative Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.compactionTestsNegativeCases(version: .v1p0))
  func negativeEvaluationTestOneZero(testCase: CompactTest.NegativeCase) throws {
    guard let expectError = JSONLDError.Code(rawValue: testCase.expectErrorCode) else {
      Issue.record(
        "Missing JSONLDError case for expected error code: '\(testCase.expectErrorCode)'")
      return
    }

    #expect(throws: JSONLDError.code(expectError)) {
      let document = try TestCaseLoader.load(testCase.input, type: JSONLDDocument.self)
      let context = try TestCaseLoader.load(
        testCase.options.contextFilename, type: JSONLDDocument.self)
      _ = document.compact(
        context: context,
        baseIRI: testCase.options.base,
        compactArrays: testCase.options.compactArrays,
        compactToRelative: testCase.options.compactToRelative
      )
    }
  }

  @Test(
    "[Compaction] Negative Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.compactionTestsNegativeCases(version: .v1p1))
  func negativeEvaluationTestOneOne(testCase: CompactTest.NegativeCase) {}
}
