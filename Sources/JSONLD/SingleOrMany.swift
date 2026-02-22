// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public indirect enum SingleOrMany<T: Equatable>: Equatable {
  typealias Mapper = (JSONValue) throws(JSONLDError) -> T

  case single(T)
  case many([T])

  init(_ value: T) {
    self = .single(value)
  }

  init(_ values: T...) {
    self = .many(values)
  }

  init(_ values: [T]) {
    self = .many(values)
  }

  init(from jsonArray: JSONArray, mapper: Mapper) throws(JSONLDError) {
    self.init(try jsonArray.map(mapper))
  }

  init(from jsonValue: JSONValue, mapper: Mapper) throws(JSONLDError) {
    if case .array(let array) = jsonValue {
      try self.init(from: array, mapper: mapper)
    } else {
      self.init(try mapper(jsonValue))
    }
  }
}

extension SingleOrMany: JSONLDValueProtocol, CustomJSONValueConvertible
where T: JSONLDValueProtocol {
  public var jsonValue: JSONValue {
    switch self {
    case .single(let value): value.jsonValue
    case .many(let values): values.jsonValue
    }
  }

  init(from jsonArray: JSONArray) throws(JSONLDError) {
    try self.init(from: jsonArray, mapper: T.init(from:))
  }

  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    try self.init(from: jsonValue, mapper: T.init(from:))
  }
}
