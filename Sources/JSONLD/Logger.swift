// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

/// A simple logging protocol for the JSON-LD processor.
///
/// Implementations of this protocol can be used to capture internal processor events
/// and underlying errors from the `JSONLDDocumentLoader`.
public protocol JSONLDLogger: Sendable {
  /// Logs a message with a specific severity level.
  ///
  /// - Parameters:
  ///   - message: The message to log.
  ///   - level: The severity of the log entry.
  func log(_ message: String, level: JSONLDLogLevel)
}

/// Severity levels for JSON-LD logging.
public enum JSONLDLogLevel: Sendable {
  case debug
  case info
  case error
}
