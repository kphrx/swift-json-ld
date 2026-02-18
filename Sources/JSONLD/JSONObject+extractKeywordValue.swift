// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONObject {
  mutating func extractContext() throws(JSONLDError) -> Contexts? {
    if let context = self.removeValue(forKey: "@context") {
      try .init(from: context)
    } else { nil }
  }

  mutating func extractIndex() throws(JSONLDError) -> String? {
    if let index = self.removeValue(forKey: "@index") {
      if case .string(let value) = index {
        value
      } else {
        throw .invalidIndex
      }
    } else { nil }
  }
}
