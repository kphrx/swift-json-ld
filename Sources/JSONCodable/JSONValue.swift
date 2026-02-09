public typealias JSONArray = [JSONValue]
public typealias JSONObject = [String: JSONValue]

public enum JSONValue: Sendable, Equatable {
  case string(String)
  case integer(Int)
  case float(Double)
  case boolean(Bool)
  case null
  case array(JSONArray)
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
  public init(nilLiteral: ()) {
    self = .null
  }

  public init(booleanLiteral value: BooleanLiteralType) {
    self = .boolean(value)
  }

  public init(integerLiteral value: IntegerLiteralType) {
    self = .integer(value)
  }

  public init(floatLiteral value: FloatLiteralType) {
    self = .float(value)
  }

  public init(stringLiteral value: StringLiteralType) {
    self = .string(value)
  }

  public init(arrayLiteral elements: Self...) {
    self = .array(elements)
  }

  public init(dictionaryLiteral elements: (String, Self)...) {
    self = .object(.init(uniqueKeysWithValues: elements))
  }
}
