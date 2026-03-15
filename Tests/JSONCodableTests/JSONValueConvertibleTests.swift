// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Testing

@testable import JSONCodable

struct JSONValueConvertibleTests {
  @Test("String to JSONValue.string")
  func string() throws {
    let value: String = "Hello, World!"

    #expect(value.jsonValue == .string("Hello, World!"))
  }

  @Test("Int to JSONValue.integer")
  func integer() throws {
    let value: Int = 65535

    #expect(value.jsonValue == .integer(65535))
  }

  @Test("Double to JSONValue.float")
  func float() throws {
    let value: Double = 3.14159

    #expect(value.jsonValue == .float(3.14159))
  }

  @Test("Bool to JSONValue.boolean")
  func boolean() throws {
    let value: Bool = true

    #expect(value.jsonValue == .boolean(true))
  }

  @Test("[String: Int] conforms to LosslessJSONObjectConvertible")
  func jsonObjectConvertible() throws {
    let value: [String: Int] = ["one": 1, "two": 2, "three": 3]

    #expect(value.jsonObject == ["one": .integer(1), "two": .integer(2), "three": .integer(3)])
  }

  @Test("CustomJSONArrayConvertible to JSONValue.array")
  func jsonArrayConvertible() throws {
    struct KeyValueSequence: CustomJSONArrayConvertible {
      let keys: [String]
      let values: [Int]

      init(data: [String: Int]) {
        let (keys, values) = data.sorted { $0.key < $1.key }.reduce(
          into: (keys: [String](), values: [Int]())
        ) {
          $0.keys.append($1.key)
          $0.values.append($1.value)
        }

        self.keys = keys
        self.values = values
      }

      var jsonArray: JSONArray {
        zip(self.keys, self.values).flatMap { [$0.jsonValue, $1.jsonValue] }
      }
    }

    let value = KeyValueSequence(data: ["start": 1_609_459_200, "end": 1_612_137_600])

    #expect(
      value.jsonValue
        == .array([
          .string("end"), .integer(1_612_137_600), .string("start"), .integer(1_609_459_200),
        ])
    )
  }

  @Test("[CustomJSONObjectConvertible] to [JSONValue.object]")
  func arrayJsonObjectConvertible() throws {
    struct Planet: CustomJSONObjectConvertible {
      let name: String
      let mass: Double

      var jsonObject: JSONObject {
        [
          "name": name.jsonValue,
          "mass": mass.jsonValue,
        ]
      }
    }

    let value = [Planet(name: "Earth", mass: 5.972e24), .init(name: "Mars", mass: 6.39e23)]

    #expect(
      value.jsonArray == [
        .object(["name": .string("Earth"), "mass": .float(5.972e24)]),
        .object(["name": .string("Mars"), "mass": .float(6.39e23)]),
      ]
    )
  }
}
