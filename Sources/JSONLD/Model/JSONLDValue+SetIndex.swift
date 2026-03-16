// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension JSONLDValue {
  init(_ value: SetOrListObject.Element) {
    self =
      switch value {
      case .string(let s): .iriOrTerm(s)
      case .integer(let i): .value(.init(value: .integer(i)))
      case .float(let f): .value(.init(value: .float(f)))
      case .boolean(let b): .value(.init(value: .boolean(b)))
      case .null: .invalid(.notJSONLDValue)
      case .nodeObject(let n): .node(n)
      case .valueObject(let v): .value(v)
      }
  }

  init(_ value: IndexMap.Value) {
    self =
      switch value {
      case .string(let s): .iriOrTerm(s)
      case .integer(let i): .value(.init(value: .integer(i)))
      case .float(let f): .value(.init(value: .float(f)))
      case .boolean(let b): .value(.init(value: .boolean(b)))
      case .null: .invalid(.notJSONLDValue)
      case .nodeObject(let n): .node(n)
      case .valueObject(let v): .value(v)
      case .setOrListObject(let s): .setOrList(s)
      }
  }
}
