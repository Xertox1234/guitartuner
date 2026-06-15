---
name: lsp-intelligence
description: Use when doing symbol lookups, call graph tracing, or type verification in Swift — provides LSP operation catalogue and usage rules for SourceKit-LSP across TunerEngine, LumaDesignSystem, and App
---

# LSP Intelligence

Shared reference for Language Server Protocol operations. Prefer LSP over grep
when the goal is symbol-level intelligence (types, call graphs, reference sites)
rather than text pattern matching.

**Available LSPs in this project:**

- Swift → SourceKit-LSP (TunerEngine, LumaDesignSystem, App — all packages)

## Critical Constraint

LSP operations require `filePath` + `line` + `character` (1-based integers). You
**cannot** query by symbol name alone. Always obtain position first:

1. Call `workspaceSymbol(query:)` → get the file path and line → use as the anchor.
2. Or call `documentSymbol` on the file → find the symbol name in the result →
   extract its `line` and `character` values.
3. Or use a prior `Read` output — the line number in the left column is `line`;
   `character` is the 1-based column of the first character of the symbol name
   (count from 1 at the start of the line).

When using positions from `documentSymbol` or `workspaceSymbol` results, pass the
returned values through directly without adjustment.

## Operation Catalogue

| Operation | Returns | Beats grep when... |
|---|---|---|
| `workspaceSymbol` | Matching symbols across workspace | Finding a type/function when you don't know which file it lives in |
| `documentSymbol` | All symbols in file with positions | Enumerating a file's full API — no false matches from comments or strings |
| `hover` | Resolved type + docstring at position | You need the *resolved* type, not just the annotation text |
| `findReferences` | All reference locations workspace-wide | Finding call sites — grep misses protocol-dispatched and type-aliased callers |
| `goToDefinition` | Definition location | Following a type reference to its declaration |
| `goToImplementation` | Concrete implementation locations | Verifying a protocol method is implemented |
| `prepareCallHierarchy` | Call hierarchy item at position | Entry point required before `incomingCalls`/`outgoingCalls` |
| `incomingCalls` | All functions that call this function | Tracing "who calls this?" without text noise |
| `outgoingCalls` | All functions called by this function | Detecting unexpected dependencies in a method |

## Usage Rules

**LSP-primary** (always prefer over grep):

- Locate a type or function across packages → `workspaceSymbol`
- Enumerate all methods/properties in a file → `documentSymbol`
- Verify resolved type of a field or return value → `hover`
- Find all call sites of a changed/renamed symbol → `findReferences`
- Trace a call chain → `prepareCallHierarchy` → `incomingCalls` / `outgoingCalls`
- Follow a type reference to its declaration → `goToDefinition`

**Grep-primary** (LSP cannot help):

- Text patterns in strings or comments
- `TODO`/`FIXME`/`HACK` markers
- Regex searches across file contents
- Dynamic dispatch via `@objc` selectors or `AnyObject` (SourceKit-LSP may miss these)

## Compose Pattern

```
1. workspaceSymbol(query: "TypeName") → get {filePath, line}
2. documentSymbol(filePath) → find symbol → get precise {line, character}
3. hover / findReferences / outgoingCalls({filePath, line, character})
```

Never call `findReferences`, `hover`, or `outgoingCalls` without a confirmed position
from step 1 or 2 — a wrong character offset silently returns no results.

## Swift-Specific Notes

- **Package boundaries** — `findReferences` works across all three packages (TunerEngine,
  LumaDesignSystem, App) in a single call. Use this to verify no cross-package violations.
- **Protocol conformance** — `goToImplementation` finds concrete types conforming to a
  protocol; `findReferences` on the protocol itself finds all adoption sites.
- **Actor isolation** — `hover` on an `async` call site confirms whether it crosses an
  actor boundary (the resolved type includes `@MainActor` or `@TunerEngine` if applicable).
- **`@objc` / dynamic dispatch** — LSP cannot trace these; fall back to grep for
  selector strings.

## Graceful Fallback

If LSP returns an error (server not indexed, file not open):

- Fall back to grep immediately — do not retry LSP more than once.
- Do not stall waiting for LSP availability.
