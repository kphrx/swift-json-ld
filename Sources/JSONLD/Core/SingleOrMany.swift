// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A JSON-LD value that can be either a single item or an array of items.
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

extension SingleOrMany: CustomJSONValueConvertible where T: CustomJSONValueConvertible {
  /// Returns this value as a JSON value.
  public var jsonValue: JSONValue {
    switch self {
    case .single(let value): value.jsonValue
    case .many(let values): values.jsonValue
    }
  }
}

extension SingleOrMany: Sequence {
  /// Returns an iterator over the elements.
  public func makeIterator() -> AnyIterator<T> {
    switch self {
    case .single(let value): .init([value].makeIterator())
    case .many(let values): .init(values.makeIterator())
    }
  }
}
