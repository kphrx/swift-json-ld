// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public enum NodeObjects {
  case single(NodeObject)
  case array([NodeObject])

  init(from jsonObject: JSONObject) {
    self = .single(.init(from: jsonObject))
  }

  init(from jsonArray: JSONArray) throws(JSONLDError) {
    self = .array(try jsonArray.map(NodeObject.init(from:)))
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    switch jsonValue {
    case .object(let jsonObject): self.init(from: jsonObject)
    case .array(let jsonArray): try self.init(from: jsonArray)
    default: throw .notObject
    }
  }
}

public struct NodeObject {
  private let rawValue: JSONObject
  let context: Contexts?

  init(from jsonObject: JSONObject) {
    self.rawValue = jsonObject
    self.context = jsonObject["@context"].flatMap { try? Contexts(from: $0) }
  }

  init(from jsonValue: JSONValue) throws(JSONLDError) {
    if case .object(let jsonObject) = jsonValue {
      self.init(from: jsonObject)
    } else {
      throw .notObject
    }
  }
}
