// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONObject {
  mutating func set<T: CustomJSONValueConvertible>(
    _ value: T?,
    for keyword: JSONLDKeyword,
    term: String?
  ) {
    guard let value else {
      return
    }
    self[term ?? keyword.rawValue] = value.jsonValue
  }

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

extension JSONValue {
  subscript(_ keyword: JSONLDKeyword) -> JSONValue? {
    self[keyword.rawValue]
  }
}
