// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Testing

@testable import JSONLD

@Suite(
  .disabled(if: TestCaseLoader.compactionTestsManifest == nil, "Missing compaction test manifest"))
struct CompactionTests {
  @Test(
    "[Compaction] Positive Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.compactionTestsPositiveCases(version: .v1p0))
  func positiveEvaluationTestOneZero(testCase: CompactTest.PositiveCase) throws {
    let processor = JSONLDProcessor()
    processor.loader = TestDocumentLoader()
    let input = try TestCaseLoader.load(testCase.input, type: JSONLDValues<Unresolved>.self)
    let context = try TestCaseLoader.load(
      testCase.options.contextFilename, type: JSONLDDocument<Unresolved>.self)
    let actual = try processor.compact(
      input,
      context: context,
      baseIRI: testCase.options.base,
      compactArrays: testCase.options.compactArrays,
      compactToRelative: testCase.options.compactToRelative
    )
    let expect = try TestCaseLoader.load(
      testCase.expectFilename, type: JSONLDDocument<Unresolved>.self)
    #expect(actual.jsonValue == expect.jsonValue)
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

    let processor = JSONLDProcessor()
    processor.loader = TestDocumentLoader()

    #expect(throws: JSONLDError.code(expectError)) {
      let input = try TestCaseLoader.load(testCase.input, type: JSONLDValues<Unresolved>.self)
      let context = try TestCaseLoader.load(
        testCase.options.contextFilename, type: JSONLDDocument<Unresolved>.self)
      _ = try processor.compact(
        input,
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
