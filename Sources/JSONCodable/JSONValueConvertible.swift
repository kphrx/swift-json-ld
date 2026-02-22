// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public protocol CustomJSONValueConvertible {
  var jsonValue: JSONValue { get }
}

public protocol CustomJSONArrayConvertible: CustomJSONValueConvertible {
  var jsonArray: JSONArray { get }
}

public protocol CustomJSONObjectConvertible: CustomJSONValueConvertible {
  var jsonObject: JSONObject { get }
}

public protocol LosslessJSONValueConvertible: CustomJSONValueConvertible {
  init?(_ jsonValue: JSONValue)
}

extension String: LosslessJSONValueConvertible {
  public init?(_ jsonValue: JSONValue) {
    guard case .string(let value) = jsonValue else { return nil }
    self = value
  }

  public var jsonValue: JSONValue {
    .string(self)
  }
}

extension Int: LosslessJSONValueConvertible {
  public init?(_ jsonValue: JSONValue) {
    guard case .integer(let value) = jsonValue else { return nil }
    self = value
  }

  public var jsonValue: JSONValue {
    .integer(self)
  }
}

extension Double: LosslessJSONValueConvertible {
  public init?(_ jsonValue: JSONValue) {
    guard case .float(let value) = jsonValue else { return nil }
    self = value
  }

  public var jsonValue: JSONValue {
    .float(self)
  }
}

extension Bool: LosslessJSONValueConvertible {
  public init?(_ jsonValue: JSONValue) {
    guard case .boolean(let value) = jsonValue else { return nil }
    self = value
  }

  public var jsonValue: JSONValue {
    .boolean(self)
  }
}

extension CustomJSONArrayConvertible {
  public var jsonValue: JSONValue {
    .array(self.jsonArray)
  }
}

extension CustomJSONObjectConvertible {
  public var jsonValue: JSONValue {
    .object(self.jsonObject)
  }
}

extension Array: CustomJSONArrayConvertible, CustomJSONValueConvertible
where Element: CustomJSONValueConvertible {
  public var jsonArray: JSONArray {
    self.map { $0.jsonValue }
  }
}

extension Dictionary: CustomJSONObjectConvertible, CustomJSONValueConvertible
where Key == String, Value: CustomJSONValueConvertible {
  public var jsonObject: JSONObject {
    self.mapValues { $0.jsonValue }
  }
}

private enum LosslessConvertibleError: Error {
  case invalidElement
}

extension Array: LosslessJSONValueConvertible where Element: LosslessJSONValueConvertible {
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
