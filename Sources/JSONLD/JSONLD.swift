// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

@_exported import JSONCodable

public typealias JSONLDDocument = NodeObjects

extension JSONLDDocument: Decodable {
  public init(from decoder: Decoder) throws {
    try self.init(from: JSONValue(from: decoder))
  }
}
