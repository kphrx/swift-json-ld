// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

@_exported import JSONCodable

public typealias JSONLDDocument = SingleOrMany<NodeObject>

extension JSONLDDocument: Decodable {
  public init(from decoder: Decoder) throws {
    try self.init(from: JSONValue(from: decoder))
  }
}

extension JSONLDDocument {
  public func expand(
    expandContext: JSONLDDocument? = nil,
    baseIRI: String? = nil,
    normative: Bool = true
  ) throws(JSONLDError) -> JSONValue {
    _ = (expandContext, baseIRI, normative)
    return self.jsonValue
  }

  public func compact(
    context: JSONLDDocument,
    baseIRI: String? = nil,
    compactArrays: Bool = true,
    compactToRelative: Bool = true
  ) -> JSONValue {
    _ = (context, baseIRI, compactArrays, compactToRelative)
    return self.jsonValue
  }

  public func flatten(
    context: JSONLDDocument? = nil,
    baseIRI: String? = nil,
    compactArrays: Bool = true
  ) -> JSONValue {
    _ = (context, baseIRI, compactArrays)
    return self.jsonValue
  }
}
