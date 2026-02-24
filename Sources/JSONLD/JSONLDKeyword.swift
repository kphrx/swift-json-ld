// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum JSONLDKeyword: String, CaseIterable {
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
}

extension JSONObject {
  mutating func removeValue(for keyword: JSONLDKeyword) -> JSONValue? {
    self.removeValue(forKey: keyword.rawValue)
  }

  subscript(_ keyword: JSONLDKeyword) -> JSONValue? {
    get { self[keyword.rawValue] }
    set { self[keyword.rawValue] = newValue }
  }

  func contains(_ keyword: JSONLDKeyword) -> Bool {
    self.keys.contains(keyword.rawValue)
  }
}
