// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A type that can provide a ``JSONValue`` representation.
public protocol CustomJSONValueConvertible {
  /// Returns this value as a ``JSONValue``.
  var jsonValue: JSONValue { get }
}

/// A type that can provide a JSON array representation.
///
/// Types conforming to this protocol automatically provide a ``JSONValue/array(_:)``
/// representation via the ``CustomJSONValueConvertible/jsonValue`` property.
public protocol CustomJSONArrayConvertible: CustomJSONValueConvertible {
  /// Returns this value as a ``JSONArray``.
  var jsonArray: JSONArray { get }
}

/// A type that can provide a JSON object representation.
///
/// Types conforming to this protocol automatically provide a ``JSONValue/object(_:)``
/// representation via the ``CustomJSONValueConvertible/jsonValue`` property.
public protocol CustomJSONObjectConvertible: CustomJSONValueConvertible {
  /// Returns this value as a ``JSONObject``.
  var jsonObject: JSONObject { get }
}

/// A type that can be losslessly converted from and to ``JSONValue``.
///
/// Use this protocol to provide a two-way conversion between a custom type and a ``JSONValue``.
/// Conforming types can be used to extract values from a ``JSONValue`` using their initializers:
///
/// ```swift
/// let url = URL(jsonValue ?? .null)
/// ```
///
/// ```swift
/// extension URL: LosslessJSONValueConvertible {
///   public init?(_ jsonValue: JSONValue) {
///     guard case .string(let string) = jsonValue else { return nil }
///     self.init(string: string)
///   }
///
///   public var jsonValue: JSONValue { .string(absoluteString) }
/// }
/// ```
public protocol LosslessJSONValueConvertible: CustomJSONValueConvertible {
  /// Creates an instance from a ``JSONValue`` if conversion is possible.
  init?(_ jsonValue: JSONValue)
}

extension String: LosslessJSONValueConvertible {
  /// Creates a string from `.string` JSON values.
  public init?(_ jsonValue: JSONValue) {
    guard case .string(let value) = jsonValue else { return nil }
    self = value
  }

  /// Returns `.string(self)`.
  public var jsonValue: JSONValue {
    .string(self)
  }
}

extension Int: LosslessJSONValueConvertible {
  /// Creates an integer from `.integer` JSON values.
  public init?(_ jsonValue: JSONValue) {
    guard case .integer(let value) = jsonValue else { return nil }
    self = value
  }

  /// Returns `.integer(self)`.
  public var jsonValue: JSONValue {
    .integer(self)
  }
}

extension Double: LosslessJSONValueConvertible {
  /// Creates a double from `.float` JSON values.
  public init?(_ jsonValue: JSONValue) {
    guard case .float(let value) = jsonValue else { return nil }
    self = value
  }

  /// Returns `.float(self)`.
  public var jsonValue: JSONValue {
    .float(self)
  }
}

extension Bool: LosslessJSONValueConvertible {
  /// Creates a boolean from `.boolean` JSON values.
  public init?(_ jsonValue: JSONValue) {
    guard case .boolean(let value) = jsonValue else { return nil }
    self = value
  }

  /// Returns `.boolean(self)`.
  public var jsonValue: JSONValue {
    .boolean(self)
  }
}

extension CustomJSONValueConvertible where Self: CustomJSONArrayConvertible {
  /// Wraps ``jsonArray`` as `.array`.
  public var jsonValue: JSONValue {
    .array(self.jsonArray)
  }
}

extension CustomJSONValueConvertible where Self: CustomJSONObjectConvertible {
  /// Wraps ``jsonObject`` as `.object`.
  public var jsonValue: JSONValue {
    .object(self.jsonObject)
  }
}

extension Array: CustomJSONArrayConvertible, CustomJSONValueConvertible
where Element: CustomJSONValueConvertible {
  /// Maps each element into ``JSONValue`` and returns an array.
  public var jsonArray: JSONArray {
    self.map { $0.jsonValue }
  }
}

extension Dictionary: CustomJSONObjectConvertible, CustomJSONValueConvertible
where Key == String, Value: CustomJSONValueConvertible {
  /// Maps each dictionary value into ``JSONValue``.
  public var jsonObject: JSONObject {
    self.mapValues { $0.jsonValue }
  }
}

private enum LosslessConvertibleError: Error {
  case invalidElement
}

extension Array: LosslessJSONValueConvertible where Element: LosslessJSONValueConvertible {
  /// Creates an array from `.array` JSON values when all elements convert.
  public init?(_ jsonValue: JSONValue) {
    guard case .array(let jsonArray) = jsonValue else { return nil }
    do {
      self = try jsonArray.map { jsonValue throws(LosslessConvertibleError) in
        if let value = Element(jsonValue) {
          value
        } else {
          throw .invalidElement
        }
      }
    } catch {
      return nil
    }
  }
}

extension Dictionary: LosslessJSONValueConvertible
where Key == String, Value: LosslessJSONValueConvertible {
  /// Creates a dictionary from `.object` JSON values when all values convert.
  public init?(_ jsonValue: JSONValue) {
    guard case .object(let jsonObject) = jsonValue else { return nil }
    do {
      self = try jsonObject.mapValues { jsonValue throws(LosslessConvertibleError) in
        if let value = Value(jsonValue) {
          value
        } else {
          throw .invalidElement
        }
      }
    } catch {
      return nil
    }
  }
}
