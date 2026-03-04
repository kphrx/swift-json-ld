// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

extension Dictionary {
  // NOTE: This extension is a temporary workaround and will be fixed in a future Swift release.
  //       Fixed in swiftlang/swift#86894 "Typed Throws Adoption for Several Dictionary APIs"
  public func mapValuesWithTypedThrows<T, E: Error>(
    _ transform: (Value) throws(E) -> T
  ) throws(E) -> [Key: T] {
    try .init(
      uniqueKeysWithValues: self.map { (key, value) throws(E) in (key, try transform(value)) })
  }
}
