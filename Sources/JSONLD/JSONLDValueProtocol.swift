// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public protocol JSONLDValueProtocol: CustomJSONValueConvertible {
  init(from jsonValue: JSONValue) throws(JSONLDError)
}

protocol JSONLDArrayProtocol: JSONLDValueProtocol, CustomJSONArrayConvertible {
  init(from jsonArray: JSONArray) throws(JSONLDError)
}

protocol JSONLDObjectProtocol: JSONLDValueProtocol, CustomJSONObjectConvertible {
  init(from jsonObject: JSONObject) throws(JSONLDError)
}

extension JSONLDValueProtocol where Self: JSONLDObjectProtocol {
  init(from jsonValue: JSONValue) throws(JSONLDError) {
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
