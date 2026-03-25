// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

@testable import JSONLD

enum TestCaseLoader {
  enum JsonLdVersion: String, Decodable {
    case v1p0 = "json-ld-1.0"
    case v1p1 = "json-ld-1.1"
  }

  struct Manifest: Decodable {
    struct Sequence: Decodable {
      enum CodingKeys: String, CodingKey {
        case id = "@id"
        case type = "@type"
        case name, purpose, input, context, expect, expectErrorCode, option
      }

      struct Option: Decodable {
        let processingMode: JsonLdVersion?
        let specVersion: JsonLdVersion?
        let base: String?
        let compactArrays: Bool?
        let compactToRelative: Bool?
        let expandContext: String?
        let normative: Bool?
      }

      let id: String
      let type: [String]
      let name: String
      let purpose: String
      let input: String
      let context: String?
      let expect: String?
      let expectErrorCode: String?
      let option: Option?

      var processingModes: [JsonLdVersion] {
        if let mode = self.option?.processingMode {
          [mode]
        } else if self.option?.specVersion == .v1p1 {
          [.v1p1]
        } else {
          [.v1p0, .v1p1]
        }
      }
    }

    let sequence: [Sequence]
  }

  private static var testCasePath: URL? {
    ProcessInfo.processInfo.environment["JSONLD_TEST_FIXTURES"].map { URL(fileURLWithPath: $0) }
  }

  static var expansionTestsManifest: Manifest? {
    try? self.load("expand-manifest.jsonld")
  }

  private static var expansionTestsCases: [Manifest.Sequence] {
    self.expansionTestsManifest?.sequence ?? []
  }

  static var compactionTestsManifest: Manifest? {
    try? self.load("compact-manifest.jsonld")
  }

  private static var compactionTestsCases: [Manifest.Sequence] {
    self.compactionTestsManifest?.sequence ?? []
  }

  static var flatteningTestsManifest: Manifest? {
    try? self.load("flatten-manifest.jsonld")
  }

  private static var flatteningTestsCases: [Manifest.Sequence] {
    self.flatteningTestsManifest?.sequence ?? []
  }

  static func load<T: Decodable>(_ name: String, type: T.Type = T.self) throws -> T {
    try Util.loadFixture(name, from: self.testCasePath, type: type)
  }

  static func loadContexts(_ name: String?) throws -> Contexts? {
    guard let name else { return nil }
    let jsonValue: JSONValue = try self.load(name, type: JSONValue.self)
    if case .object(let object) = jsonValue,
      let localContext = object[.context]
    {
      return try Contexts(from: localContext)
    }
    return nil
  }

  static func expansionTestsPositiveCases(version: JsonLdVersion) -> [ExpandTest.PositiveCase] {
    self.expansionTestsCases.compactMap { seq in
      if seq.type.contains("jld:PositiveEvaluationTest"),
        seq.processingModes.contains(version),
        let expect = seq.expect
      {
        ExpandTest.PositiveCase(
          meta: .init(id: seq.id, name: seq.name),
          input: seq.input,
          expectFilename: expect,
          options: .init(
            base: seq.option?.base,
            expandContextFilename: seq.option?.expandContext,
            normative: seq.option?.normative ?? true
          )
        )
      } else {
        nil
      }
    }
  }

  static func expansionTestsNegativeCases(version: JsonLdVersion) -> [ExpandTest.NegativeCase] {
    self.expansionTestsCases.compactMap { seq in
      if seq.type.contains("jld:NegativeEvaluationTest"),
        seq.processingModes.contains(version),
        let expectErrorCode = seq.expectErrorCode
      {
        ExpandTest.NegativeCase(
          meta: .init(id: seq.id, name: seq.name),
          input: seq.input,
          expectErrorCode: expectErrorCode,
          options: .init(
            base: seq.option?.base,
            expandContextFilename: seq.option?.expandContext,
            normative: seq.option?.normative ?? true
          )
        )
      } else {
        nil
      }
    }
  }

  static func compactionTestsPositiveCases(version: JsonLdVersion) -> [CompactTest.PositiveCase] {
    self.compactionTestsCases.compactMap { seq in
      if seq.type.contains("jld:PositiveEvaluationTest"),
        seq.processingModes.contains(version),
        let expect = seq.expect,
        let context = seq.context
      {
        CompactTest.PositiveCase(
          meta: .init(id: seq.id, name: seq.name),
          input: seq.input,
          expectFilename: expect,
          options: .init(
            contextFilename: context,
            base: seq.option?.base,
            compactArrays: seq.option?.compactArrays ?? true,
            compactToRelative: seq.option?.compactToRelative ?? true
          )
        )
      } else {
        nil
      }
    }
  }

  static func compactionTestsNegativeCases(version: JsonLdVersion) -> [CompactTest.NegativeCase] {
    self.compactionTestsCases.compactMap { seq in
      if seq.type.contains("jld:NegativeEvaluationTest"),
        seq.processingModes.contains(version),
        let expectErrorCode = seq.expectErrorCode,
        let context = seq.context
      {
        CompactTest.NegativeCase(
          meta: .init(id: seq.id, name: seq.name),
          input: seq.input,
          expectErrorCode: expectErrorCode,
          options: .init(
            contextFilename: context,
            base: seq.option?.base,
            compactArrays: seq.option?.compactArrays ?? true,
            compactToRelative: seq.option?.compactToRelative ?? true
          )
        )
      } else {
        nil
      }
    }
  }

  static func flatteningTestsPositiveCases(version: JsonLdVersion) -> [FlattenTest.PositiveCase] {
    self.flatteningTestsCases.compactMap { seq in
      if seq.type.contains("jld:PositiveEvaluationTest"),
        seq.processingModes.contains(version),
        let expect = seq.expect
      {
        FlattenTest.PositiveCase(
          meta: .init(id: seq.id, name: seq.name),
          input: seq.input,
          expectFilename: expect,
          options: .init(
            contextFilename: seq.context,
            base: seq.option?.base,
            compactArrays: seq.option?.compactArrays ?? true
          )
        )
      } else {
        nil
      }
    }
  }

  static func flatteningTestsNegativeCases(version: JsonLdVersion) -> [FlattenTest.NegativeCase] {
    self.flatteningTestsCases.compactMap { seq in
      if seq.type.contains("jld:NegativeEvaluationTest"),
        seq.processingModes.contains(version),
        let expectErrorCode = seq.expectErrorCode
      {
        FlattenTest.NegativeCase(
          meta: .init(id: seq.id, name: seq.name),
          input: seq.input,
          expectErrorCode: expectErrorCode,
          options: .init(
            contextFilename: seq.context,
            base: seq.option?.base,
            compactArrays: seq.option?.compactArrays ?? true
          )
        )
      } else {
        nil
      }
    }
  }
}
