// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

public protocol JSONLDPhase: Equatable, Sendable {
  associatedtype UnknownContent: Equatable
}

public enum Unresolved: JSONLDPhase {
  public typealias UnknownContent = [String: SingleOrMany<JSONLDValue<Unresolved>>]
}

public enum Expanded: JSONLDPhase {
  public typealias UnknownContent = Never
}
