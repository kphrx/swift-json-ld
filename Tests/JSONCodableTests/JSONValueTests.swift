// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Testing

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

@testable import JSONCodable

struct JSONValueTests {
  @Test("Decode JSON strings") func decoding() throws {
    let payload =
      #"{"version":"2.1","protocols":["activitypub"],"usage":{"users":{"total":4,"activeHalfyear":1,"activeMonth":1},"localPosts":32842},"services":{"inbound":[],"outbound":[]},"software":{"name":"pleroma","version":"2.7.0-0-g4139864","repository":"https://git.pleroma.social/pleroma/pleroma"},"openRegistrations":false,"metadata":{"empty":null,"floating":3.14}}"#
    let data = Data(payload.utf8)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

    #expect(
      decoded == [
        "version": "2.1",
        "protocols": ["activitypub"],
        "usage": [
          "users": [
            "total": 4,
            "activeHalfyear": 1,
            "activeMonth": 1,
          ],
          "localPosts": 32842,
        ],
        "services": [
          "inbound": [],
          "outbound": [],
        ],
        "software": [
          "name": "pleroma",
          "version": "2.7.0-0-g4139864",
          "repository": "https://git.pleroma.social/pleroma/pleroma",
        ],
        "openRegistrations": false,
        "metadata": [
          "empty": nil,
          "floating": 3.14,
        ],
      ])
  }

  @Test("Encode to JSON strings") func encoding() throws {
    let json: JSONValue = [
      "version": "2.1",
      "protocols": ["activitypub"],
      "usage": [
        "users": [
          "total": 4,
          "activeHalfyear": 1,
          "activeMonth": 1,
        ],
        "localPosts": 32842,
      ],
      "services": [
        "inbound": [],
        "outbound": [],
      ],
      "software": [
        "name": "pleroma",
        "version": "2.7.0-0-g4139864",
        "repository": "https://git.pleroma.social/pleroma/pleroma",
      ],
      "openRegistrations": false,
      "metadata": [
        "empty": nil,
        "floating": 3.14,
      ],
    ]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

    let encoded = try encoder.encode(json)
    #expect(
      String(data: encoded, encoding: .utf8)
        == #"{"metadata":{"empty":null,"floating":3.14},"openRegistrations":false,"protocols":["activitypub"],"services":{"inbound":[],"outbound":[]},"software":{"name":"pleroma","repository":"https://git.pleroma.social/pleroma/pleroma","version":"2.7.0-0-g4139864"},"usage":{"localPosts":32842,"users":{"activeHalfyear":1,"activeMonth":1,"total":4}},"version":"2.1"}"#
    )
  }

  @Test("Access via subscript for Array and Dictionary") func accessViaSubscript() {
    let json: JSONValue = [
      "version": "2.1",
      "protocols": ["activitypub"],
      "usage": [
        "users": [
          "total": 4,
          "activeHalfyear": 1,
          "activeMonth": 1,
        ],
        "localPosts": 32842,
      ],
      "services": [
        "inbound": [],
        "outbound": [],
      ],
      "software": [
        "name": "pleroma",
        "version": "2.7.0-0-g4139864",
        "repository": "https://git.pleroma.social/pleroma/pleroma",
      ],
      "openRegistrations": false,
      "metadata": [
        "empty": nil,
        "floating": 3.14,
      ],
    ]

    #expect(json["version"] == .string("2.1"))
    #expect(json["protocols"]?[0] == .string("activitypub"))
    #expect(json["usage"]?["users"]?["total"] == .integer(4))
    #expect(json["openRegistrations"] == .boolean(false))
    #expect(json["metadata"]?["empty"] == .null)
    #expect(json["metadata"]?["floating"] == .float(3.14))
  }
}
