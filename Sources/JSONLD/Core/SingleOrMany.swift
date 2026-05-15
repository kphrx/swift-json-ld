// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A JSON-LD value that can be either a single item or an array of items.
public indirect enum SingleOrMany<T: Equatable>: Equatable {
  typealias Mapper<E: Error> = (JSONValue) throws(E) -> T

  case single(T)
  case many([T])

  init(_ values: T...) {
    self =
      if values.count > 1 {
        .many(values)
      } else {
        .single(values[0])
      }
  }

  init(_ values: [T]) {
    self = .many(values)
  }

  init<E>(from jsonArray: JSONArray, mapper: Mapper<E>) throws(E) {
    self.init(try jsonArray.map(mapper))
  }

  init<E>(from jsonValue: JSONValue, mapper: Mapper<E>) throws(E) {
    if case .array(let array) = jsonValue {
      try self.init(from: array, mapper: mapper)
    } else {
      self.init(try mapper(jsonValue))
    }
  }

  /// Applies a transform to each element while preserving the single-or-many shape.
  ///
  /// - Parameter transform: The mapping function to apply to each element.
  /// - Returns: A new `SingleOrMany` with transformed elements.
  /// - Throws: Rethrows any error thrown by `transform`.
  public func map<U, E>(_ transform: (T) throws(E) -> U) throws(E) -> SingleOrMany<U> {
    switch self {
    case .single(let value): .single(try transform(value))
    case .many(let values): .many(try values.map(transform))
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

extension SingleOrMany: Collection {
  /// Returns the element at the given position.
  public subscript(position: Int) -> T {
    precondition(position < self.endIndex, "Index out of range.")
    return switch self {
    case .single(let value): value
    case .many(let values): values[position]
    }
  }

  /// The position of the first element.
  public var startIndex: Int {
    switch self {
    case .single: 0
    case .many(let values): values.startIndex
    }
  }

  /// The position one past the last element.
  public var endIndex: Int {
    switch self {
    case .single: 1
    case .many(let values): values.endIndex
    }
  }

  /// Returns the position immediately after the given index.
  public func index(after i: Int) -> Int {
    switch self {
    case .single: 1
    case .many(let values): values.index(after: i)
    }
  }
}

extension SingleOrMany: ExpressibleByArrayLiteral {
  /// Creates a value from an array literal, preserving the `.many` shape.
  public init(arrayLiteral elements: T...) {
    self.init(elements)
  }
}
