// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Testing

@testable import JSONLD

@Suite(
  .disabled(
    if: TestCaseLoader.remoteDocumentTestsManifest == nil,
    "Missing remote document test manifest"
  )
)
struct RemoteDocumentTests {
  @Test(
    "[Remote document] Positive Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.remoteDocumentTestsPositiveCases(version: .v1p0)
  )
  func positiveEvaluationTestOneZero(testCase: RemoteDocumentTest.PositiveCase) async throws {
    let manifestBase = "https://w3c.github.io/json-ld-api/tests/"
    let documentIRI = manifestBase + testCase.input
    let processor = JSONLDProcessor()
    processor.loader = TestDocumentLoader(optionsByURL: [documentIRI: testCase.options])

    let actual = try await processor.expand(url: documentIRI)
    let expect = try TestCaseLoader.load(
      testCase.expectFilename,
      type: JSONLDDocument<Unresolved>.self
    )
    #expect(actual.jsonValue == expect.jsonValue)
  }

  @Test(
    "[Remote document] Positive Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.remoteDocumentTestsPositiveCases(version: .v1p1)
  )
  func positiveEvaluationTestOneOne(testCase: RemoteDocumentTest.PositiveCase) {}

  @Test(
    "[Remote document] Negative Evaluation Test with processingMode 1.0",
    arguments: TestCaseLoader.remoteDocumentTestsNegativeCases(version: .v1p0)
  )
  func negativeEvaluationTestOneZero(testCase: RemoteDocumentTest.NegativeCase) async throws {
    guard let expectError = JSONLDError.Code(rawValue: testCase.expectErrorCode) else {
      Issue.record(
        "Missing JSONLDError case for expected error code: '\(testCase.expectErrorCode)'"
      )
      return
    }

    let manifestBase = "https://w3c.github.io/json-ld-api/tests/"
    let documentIRI = manifestBase + testCase.input
    let processor = JSONLDProcessor()
    processor.loader = TestDocumentLoader(optionsByURL: [documentIRI: testCase.options])

    await #expect(throws: JSONLDError.code(expectError)) {
      _ = try await processor.expand(url: documentIRI)
    }
  }

  @Test(
    "[Remote document] Negative Evaluation Test with processingMode 1.1",
    .disabled("Unsupported JSON-LD 1.1"),
    arguments: TestCaseLoader.remoteDocumentTestsNegativeCases(version: .v1p1)
  )
  func negativeEvaluationTestOneOne(testCase: RemoteDocumentTest.NegativeCase) {}
}
