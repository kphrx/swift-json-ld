// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

enum JSONLDError: Error, Equatable {
  case notObject

  case invalidIndex

  // `@context`s errors
  case invalidContextValue
  case invalidIRI(String)

  // Node Objects errors
  case invalidNodeID
  case invalidNodeType
  case invalidReverse

  // Value Objects errors
  case missingValue
  case invalidValue
  case invalidValueType
  case invalidLanguage
  case mustNotContainBothTypeAndLanguage
  case mustNotContainAnyOtherKeys

  // Lists and Sets errors
  case invalidSetValue
}
