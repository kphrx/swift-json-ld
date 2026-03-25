// Copyright 2026 kPherox
// SPDX-License-Identifier: Apache-2.0

import Foundation

enum Util {
  enum Error: Swift.Error {
    case missingFixture(String)
  }

  static func loadFixture<T: Decodable>(
    _ name: String,
    from url: URL? = nil,
    type: T.Type = T.self
  ) throws -> T {
    try JSONDecoder().decode(
      type,
      from: Data(contentsOf: self.findResourceURL(for: name, from: url))
    )
  }

  private static func findResourceURL(for name: String, from url: URL?) throws(Error) -> URL {
    if let url = url?.appendingPathComponent(name), FileManager.default.fileExists(atPath: url.path)
    {
      url
    } else if let url = Bundle.module.url(
      forResource: name,
      withExtension: nil,
      subdirectory: "Fixtures/json-ld-api-tests"
    ) {
      url
    } else {
      throw .missingFixture(name)
    }
  }
}
