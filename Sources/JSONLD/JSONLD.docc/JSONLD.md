# ``JSONLD``

A Swift-native JSON-LD processor focused on JSON-LD 1.0, with phase-typed APIs to prevent illegal states.

## Overview

The `JSONLD` module provides a comprehensive implementation of the JSON-LD 1.0 specification. It leverages Swift's strong type system to ensure document validity across different processing phases using phantom types.

### Key Features

- **Phase-based Safety**: Documents are typed by their processing phase (``Unresolved``, ``Expanded``, etc.), preventing invalid operations at compile time.
- **Type-safe Errors**: Uses typed throws (``JSONLDError``) for precise error handling.
- **JSON-LD 1.0 Compliant**: Supports Expansion, Compaction, and Flattening algorithms.

### Basic Usage

To process a JSON-LD document, start by wrapping your raw JSON in a ``JSONLDDocument`` with the ``Unresolved`` phase.

```swift
import JSONLD
import JSONCodable

let processor = JSONLDProcessor()

// 1. Prepare raw input (Unresolved)
let document = try JSONLDDocument<Unresolved>(from: [
    "@context": ["name": "https://example.com/name"],
    "@id": "https://example.com/alice",
    "name": "Alice"
])

// 2. Expand the document
// Returns JSONLDDocument<Expanded>
let expanded = try await processor.expand(document)

// 3. Compact the document back to a specific context
let context = try Contexts(from: ["name": "https://example.com/name"])
// Returns JSONLDDocument<Compacted>
let compacted = try await processor.compact(expanded.values, context: context)

// 4. Flatten the document
// Returns JSONLDDocument<Flattened>
let flattened = try await processor.flatten(expanded)
```

### Processing Phases

The processor transitions documents through various phases, each providing structural guarantees at the type level:

- ``Unresolved``: Raw, unverified JSON-LD input. Used for initial document wrapping.
- ``Expanded``: All keywords and terms are expanded to absolute IRIs. This is the foundation for other algorithms.
- ``Flattened``: The document is flattened into a single graph with all blank nodes identified.
- ``Compacted``: The document is compacted using a specific context for improved readability and efficiency.

The type ``JSONLDDocument`` and ``JSONLDValues`` use these phases as phantom types to ensure that you only call algorithms on documents in the correct state (e.g., flattening an already expanded document).

The transitions are as follows:
- `expand(...)`: ``Unresolved`` → ``Expanded``
- `compact(...)`: ``Unresolved``/``Expanded``/``Flattened`` → ``Compacted``
- `flatten(...)`: ``Unresolved``/``Expanded`` → ``Flattened``
- `flatten(..., context:)`: ``Unresolved`` → ``Compacted`` (Flattened then Compacted)
