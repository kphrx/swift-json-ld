// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A type that can be converted from a JSON value as a JSON-LD value.
public protocol JSONLDValueProtocol: CustomJSONValueConvertible {
  /// Creates an instance from a JSON value.
  init(from jsonValue: JSONValue) throws(JSONLDError)
}

protocol JSONLDArrayProtocol: JSONLDValueProtocol, CustomJSONArrayConvertible {
  init(from jsonArray: JSONArray) throws(JSONLDError)
}

/// A JSON-LD value backed by a JSON object.
public protocol JSONLDObjectProtocol: JSONLDValueProtocol, CustomJSONObjectConvertible {
  /// Creates an instance from a JSON object.
  init(from jsonObject: JSONObject) throws(JSONLDError)
}

extension JSONLDValueProtocol where Self: JSONLDObjectProtocol {
  /// Creates an instance from a JSON value containing a JSON object.
  public init(from jsonValue: JSONValue) throws(JSONLDError) {
    if case .object(let jsonObject) = jsonValue {
      try self.init(from: jsonObject)
    } else {
      throw .internalError(.notObject)
    }
  }
}

extension JSONLDValueProtocol where Self: JSONLDArrayProtocol {
  init(from jsonValue: JSONValue) throws(JSONLDError) {
    if case .array(let jsonArray) = jsonValue {
      try self.init(from: jsonArray)
    } else {
      throw .internalError(.notObject)
    }
  }
}
