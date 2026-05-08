// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Testing

struct EvalutionTestMeta {
  let id: String
  let name: String
}

protocol EvalutionTest: CustomTestArgumentEncodable, CustomTestStringConvertible {
  associatedtype TestOptions

  var meta: EvalutionTestMeta { get }
  var input: String { get }
  var options: TestOptions { get }
}

extension EvalutionTest {
  var testDescription: String {
    "\(self.meta.id) \(self.meta.name)"
  }

  func encodeTestArgument(to encoder: some Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.meta.id)
  }
}

struct PositiveEvalutionTest<Options: Sendable>: EvalutionTest {
  let meta: EvalutionTestMeta
  let input: String
  let expectFilename: String
  let options: Options
}

struct NegativeEvalutionTest<Options: Sendable>: EvalutionTest {
  let meta: EvalutionTestMeta
  let input: String
  let expectErrorCode: String
  let options: Options
}

enum CompactTest {
  struct Options {
    let contextFilename: String
    private(set) var base: String? = nil
    private(set) var compactArrays = true
    private(set) var compactToRelative = true
  }

  typealias PositiveCase = PositiveEvalutionTest<Options>
  typealias NegativeCase = NegativeEvalutionTest<Options>
}

enum ExpandTest {
  struct Options {
    private(set) var base: String? = nil
    private(set) var expandContextFilename: String? = nil
    private(set) var normative = true
  }

  typealias PositiveCase = PositiveEvalutionTest<Options>
  typealias NegativeCase = NegativeEvalutionTest<Options>
}

struct FlattenTest {
  struct Options {
    private(set) var contextFilename: String? = nil
    private(set) var base: String? = nil
    private(set) var compactArrays = true
  }

  typealias PositiveCase = PositiveEvalutionTest<Options>
  typealias NegativeCase = NegativeEvalutionTest<Options>
}

enum RemoteDocumentTest {
  struct Options {
    private(set) var contentType: String? = nil
    private(set) var httpLink: [String] = []
    private(set) var redirectTo: String? = nil
    private(set) var httpStatus: Int? = nil
  }

  typealias PositiveCase = PositiveEvalutionTest<Options>
  typealias NegativeCase = NegativeEvalutionTest<Options>
}
