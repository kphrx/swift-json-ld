// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

enum LinkHeaderContextParser {
  private static let contextRelation = "http://www.w3.org/ns/json-ld#context"

  static func contextURL(from linkHeader: String?) throws(JSONLDError) -> String? {
    guard let linkHeader, !linkHeader.isEmpty else { return nil }

    var contextURL: String?
    var matches = 0

    for value in Self.splitLinkValues(linkHeader) {
      guard let link = Self.parseLinkValue(value) else { continue }
      guard link.relations.contains(Self.contextRelation) else { continue }
      matches += 1
      if matches > 1 {
        throw .code(.multipleContextLinkHeaders)
      }
      contextURL = link.uri
    }

    return contextURL
  }

  private struct LinkValue {
    let uri: String
    let relations: [String]
  }

  private static func splitLinkValues(_ header: String) -> [Substring] {
    var values: [Substring] = []
    var start = header.startIndex
    var index = header.startIndex
    var inQuotes = false

    while index < header.endIndex {
      let character = header[index]
      if character == "\"" {
        inQuotes.toggle()
      } else if character == "\\" && inQuotes {
        index = header.index(after: index)
        if index == header.endIndex { break }
      } else if character == "," && !inQuotes {
        values.append(header[start..<index])
        start = header.index(after: index)
      }
      index = header.index(after: index)
    }

    if start < header.endIndex {
      values.append(header[start..<header.endIndex])
    }

    return values
  }

  private static func parseLinkValue(_ rawValue: Substring) -> LinkValue? {
    var index = rawValue.startIndex
    Self.skipOWS(rawValue, index: &index)
    guard index < rawValue.endIndex, rawValue[index] == "<" else { return nil }

    let uriStart = rawValue.index(after: index)
    guard let uriEnd = rawValue[uriStart...].firstIndex(of: ">") else { return nil }
    let uri = rawValue[uriStart..<uriEnd].trimmingCharacters(in: .whitespacesAndNewlines)

    index = rawValue.index(after: uriEnd)

    var relations: [String] = []
    while true {
      Self.skipOWS(rawValue, index: &index)
      guard index < rawValue.endIndex, rawValue[index] == ";" else { break }
      index = rawValue.index(after: index)
      Self.skipOWS(rawValue, index: &index)

      guard let name = Self.parseToken(rawValue, index: &index) else {
        break
      }
      let lowercasedName = name.lowercased()

      Self.skipOWS(rawValue, index: &index)
      if index < rawValue.endIndex, rawValue[index] == "=" {
        index = rawValue.index(after: index)
        Self.skipOWS(rawValue, index: &index)
        let value = Self.parseParameterValue(rawValue, index: &index)
        if lowercasedName == "rel", let value {
          relations.append(contentsOf: Self.parseRelationTypes(value))
        }
      }
    }

    return LinkValue(uri: String(uri), relations: relations)
  }

  private static func parseRelationTypes(_ value: String) -> [String] {
    value
      .split(whereSeparator: { $0.isWhitespace })
      .map { String($0) }
  }

  private static func parseParameterValue(
    _ input: Substring,
    index: inout Substring.Index
  ) -> String? {
    guard index < input.endIndex else { return nil }
    if input[index] == "\"" {
      return Self.parseQuotedString(input, index: &index)
    }
    return Self.parseToken(input, index: &index).map(String.init)
  }

  private static func parseQuotedString(
    _ input: Substring,
    index: inout Substring.Index
  ) -> String? {
    guard input[index] == "\"" else { return nil }
    var current = input.index(after: index)
    var result = ""
    var start = current

    while current < input.endIndex {
      let character = input[current]
      if character == "\\" {
        result += input[start..<current]
        current = input.index(after: current)
        if current == input.endIndex { break }
        result.append(input[current])
        current = input.index(after: current)
        start = current
        continue
      }
      if character == "\"" {
        result += input[start..<current]
        index = input.index(after: current)
        return result
      }
      current = input.index(after: current)
    }

    return nil
  }

  private static func parseToken(_ input: Substring, index: inout Substring.Index) -> Substring? {
    guard index < input.endIndex, Self.isTokenChar(input[index]) else { return nil }
    let start = index
    var current = index
    while current < input.endIndex, Self.isTokenChar(input[current]) {
      current = input.index(after: current)
    }
    index = current
    return input[start..<current]
  }

  private static func skipOWS(_ input: Substring, index: inout Substring.Index) {
    while index < input.endIndex, input[index].isWhitespace {
      index = input.index(after: index)
    }
  }

  private static func isTokenChar(_ character: Character) -> Bool {
    guard let scalar = character.unicodeScalars.first, scalar.isASCII else { return false }
    switch scalar {
    case "!", "#", "$", "%", "&", "'", "*", "+", "-", ".", "^", "_", "`", "|", "~":
      return true
    default:
      return scalar.properties.isAlphabetic || scalar.properties.isASCIIHexDigit
    }
  }
}
