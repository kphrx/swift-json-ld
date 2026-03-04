// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import class Foundation.JSONEncoder

/// A JSON array represented with ``JSONValue`` elements.
public typealias JSONArray = [JSONValue]
/// A JSON object represented as a string-keyed dictionary of ``JSONValue``.
public typealias JSONObject = [String: JSONValue]

/// A strongly typed representation of any JSON value.
public enum JSONValue: Sendable, Equatable {
  /// A JSON string value.
  case string(String)
  /// A JSON integer number value.
  case integer(Int)
  /// A JSON floating-point number value.
  case float(Double)
  /// A JSON boolean value.
  case boolean(Bool)
  /// A JSON null value.
  case null
  /// A JSON array value.
  case array(JSONArray)
  /// A JSON object value.
  case object(JSONObject)
}

extension JSONValue: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    self =
      if container.decodeNil() {
        .null
      } else if let value = try? container.decode(String.self) {
        .string(value)
      } else if let value = try? container.decode(Int.self) {
        .integer(value)
      } else if let value = try? container.decode(Double.self) {
        .float(value)
      } else if let value = try? container.decode(Bool.self) {
        .boolean(value)
      } else if let value = try? container.decode(JSONArray.self) {
        .array(value)
      } else {
        .object(try container.decode(JSONObject.self))
      }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .null: try container.encodeNil()
    case .boolean(let value): try container.encode(value)
    case .integer(let value): try container.encode(value)
    case .float(let value): try container.encode(value.toJSONEncodable())
    case .string(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }
}

extension JSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral,
  ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral,
  ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
  /// Creates `.null`.
  public init(nilLiteral: ()) {
    self = .null
  }

  /// Creates `.boolean(value)`.
  public init(booleanLiteral value: BooleanLiteralType) {
    self = .boolean(value)
  }

  /// Creates `.integer(value)`.
  public init(integerLiteral value: IntegerLiteralType) {
    self = .integer(value)
  }

  /// Creates `.float(value)`.
  public init(floatLiteral value: FloatLiteralType) {
    self = .float(value)
  }

  /// Creates `.string(value)`.
  public init(stringLiteral value: StringLiteralType) {
    self = .string(value)
  }

  /// Creates `.array(elements)`.
  public init(arrayLiteral elements: Self...) {
    self = .array(elements)
  }

  /// Creates `.object` from key-value pairs.
  public init(dictionaryLiteral elements: (String, Self)...) {
    self = .object(.init(uniqueKeysWithValues: elements))
  }
}

extension JSONValue {
  subscript(_ index: Int) -> JSONValue? {
    if case .array(let array) = self, array.indices.contains(index) {
      array[index]
    } else {
      nil
    }
  }

  subscript(_ key: String) -> JSONValue? {
    if case .object(let object) = self {
      object[key]
    } else {
      nil
    }
  }
}

extension JSONValue: CustomDebugStringConvertible {
  /// A pretty-printed JSON string for debugging.
  public var debugDescription: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
      encoder.outputFormatting.insert(.withoutEscapingSlashes)
    }

    return .init(data: try! encoder.encode(self), encoding: .utf8)!
  }
}
