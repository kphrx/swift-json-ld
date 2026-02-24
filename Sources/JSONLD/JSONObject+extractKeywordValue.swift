// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONObject {
  mutating func extractContext() throws(JSONLDError) -> Contexts? {
    try self.removeValue(for: .context).map { contextValue throws(JSONLDError) in
      try .init(from: contextValue)
    }
  }

  mutating func extractIndex() throws(JSONLDError) -> String? {
    try self.removeValue(for: .index).map { indexValue throws(JSONLDError) in
      if case .string(let value) = indexValue {
        value
      } else {
        throw .code(.invalidIndexValue)
      }
    }
  }
}
