// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A JSON-LD keyword.
public enum JSONLDKeyword: String, CaseIterable, CustomJSONValueConvertible, Sendable {
  case base = "@base"
  case container = "@container"
  case context = "@context"
  case direction = "@direction"
  case graph = "@graph"
  case id = "@id"
  case `import` = "@import"
  case included = "@included"
  case index = "@index"
  case json = "@json"
  case language = "@language"
  case list = "@list"
  case nest = "@nest"
  case none = "@none"
  case prefix = "@prefix"
  case propagate = "@propagate"
  case protected = "@protected"
  case reverse = "@reverse"
  case set = "@set"
  case type = "@type"
  case value = "@value"
  case version = "@version"
  case vocab = "@vocab"

  /// Returns this keyword as a JSON value.
  public var jsonValue: JSONValue {
    .string(self.rawValue)
  }

  /// Creates a keyword from a JSON value.
  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    guard case .string(let value) = jsonValue,
      let keyword = JSONLDKeyword(rawValue: value)
    else {
      throw .internalError(.notKeyword)
    }
    self = keyword
  }
}
