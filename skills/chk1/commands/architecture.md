---
name: chk1:architecture
description: Architectural compliance audit — patterns, boundaries, coupling
allowed-tools: Read, Grep, Glob, Bash(git *)
---

# chk1:architecture — Architectural Compliance Audit

Check that changes comply with the existing architecture. Detects pattern violations, boundary erosion, new coupling, unauthorized abstractions, and structural deviations.

## Instructions

1. Determine scope using the same logic as the full audit
2. Run pre-flight checks
3. Read changed files AND their surrounding context (imports, module structure, neighboring files)
4. Execute **Section 6: Architectural Compliance Review** with expanded depth:

### Pattern Compliance
- Do new files follow existing naming conventions?
- Do new functions/classes follow existing patterns in the same module?
- Are existing abstractions reused, or were parallel ones created?
- Were helpers/utilities duplicated instead of shared?

### Boundary Integrity
- Do changes cross module/layer boundaries inappropriately?
- Are there new direct imports that skip abstraction layers?
- Do database queries appear in layers that shouldn't have them?
- Are there circular dependencies introduced?

### Coupling Analysis
- Were new dependencies between modules introduced?
- Are components more tightly coupled after the change?
- Were global state or singletons introduced?
- Are there new cross-cutting concerns without proper middleware/hooks?

### Consistency
- Do error handling patterns match the rest of the codebase?
- Do logging patterns match?
- Do API response formats match existing endpoints?
- Do naming conventions (variables, functions, files) match?

5. Output format:

```markdown
### Architecture Audit

**Scope**: <base>..<head> (N commits, N files)

### Pattern Compliance

| # | File | Issue | Severity | Existing Pattern | What Was Done |
|---|------|-------|----------|------------------|---------------|
| 1 | path/file | New util duplicates existing | Medium | utils/format.js:fmt() | Created local fmt() |

### Boundary Violations

| # | From | To | Description |
|---|------|----|-------------|
| 1 | routes/api.js | db/queries.js | Direct DB query in route handler, bypassing service layer |

### New Coupling

| # | File | Coupled To | Description |
|---|------|-----------|-------------|
| 1 | module-a/index.js | module-b/internal.js | Imports internal function, not exported API |

### Consistency Issues

| # | File | Issue | Expected | Actual |
|---|------|-------|----------|--------|
| 1 | routes/new.js | Error format | { error: string } | { message: string, code: number } |

### Verdict

VERDICT: BLOCKED | PERMITTED | PERMITTED WITH WARNINGS
Pattern issues: N | Boundary violations: N | Coupling: N | Consistency: N
```

## After

Ask the user: **Do you want help fixing the architecture issues found?** If yes, invoke `/chk1:fix`.
