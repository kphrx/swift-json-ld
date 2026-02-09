// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

#if os(macOS) || os(tvOS) || os(iOS) || os(watchOS)
import struct Foundation.Decimal
#endif

extension Double {
  #if os(macOS) || os(tvOS) || os(iOS) || os(watchOS)
  @available(macOS, obsoleted: 14.0)
  @available(iOS, obsoleted: 17.0)
  @available(watchOS, obsoleted: 10.0)
  @available(tvOS, obsoleted: 17.0)
  func toJSONEncodable() -> Decimal {
    Decimal(self)
  }
  #endif

  // @available(SwiftStdlib 5.9, *)
  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  func toJSONEncodable() -> Double {
    self
  }
}
