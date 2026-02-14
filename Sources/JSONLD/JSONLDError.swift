// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum JSONLDError: Error, Equatable {
  case notObject
  case invalidContextValue
  case invalidIRI(String)
}
