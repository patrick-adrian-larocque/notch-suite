# Engineering rules: reuse and verify before building

Before any non-trivial investigation, proposal, or implementation, read this file and apply the relevant sections. It is the single canonical copy for Claude and Codex; `CLAUDE.md` and `AGENTS.md` point here.

## 1. Understand existing behavior

Before proposing a change:

- Read the relevant implementation, callers, configuration, and tests.
- Trace ownership and behavior through completion, cancellation, failure, and shutdown.
- Separate the reported symptom from its established cause.
- Preserve unrelated work.

Do not select a solution before understanding the responsibility it must fulfill.

## 2. Reuse before invention

Evaluate solutions in this order:

1. Existing project implementation or dependency (see `CLAUDE.md`, "Existing implementation sources").
2. Native Swift, Foundation, AppKit, or platform capability.
3. Established third-party library.
4. Extend or refactor the existing responsibility owner.
5. Custom implementation when the earlier options are insufficient.

This is a decision order, not an automatic winner. Prefer the option with the strongest correctness evidence and the lowest total maintenance burden.

Do not add managers, coordinators, registries, wrappers, services, protocols, or scripts merely to organize a small change. A new type is appropriate when a domain concept, an invariant, a platform boundary, or a demonstrated implementation need justifies it. State that justification and show that existing code and dependencies were evaluated first. Infrastructure types are not banned; unjustified ones are.

Actively evaluate maintained libraries before writing substantial or error-prone infrastructure. Do not reject a dependency simply to avoid installing it.

## 3. Verify the actual environment

Check each item against its own authoritative source, and keep the sources distinct:

- **From the machine:** the installed compiler, selected Xcode, SDK, and OS version (for example `swift --version`, `xcode-select -p`, `xcodebuild -version`, `sw_vers`).
- **From project configuration:** package tools-version (`Package.swift`), Swift language mode, deployment targets, target settings, and entitlements (`Package.swift`, `project.yml`; the `.xcodeproj` is generated output).
- **From resolution metadata:** resolved dependency versions (`Package.resolved` or the equivalent), checked against what the project actually resolves.

Never treat a manifest's minimum tools-version as the installed compiler. Never confuse language mode, SDK version, and operating-system version. Declared compatibility is not proof that integration builds or behaves correctly.

## 4. Research the exact version

For a serious dependency candidate:

- Identify the canonical upstream repository.
- Verify the release tag and its publication date.
- Read the manifest and the relevant implementation at that exact tag.
- Check platform support, license, dependencies, and unusual build requirements.
- Inspect the APIs that directly affect the decision.

Do not attribute properties of unpinned `main` to a released version. Use search engines for discovery, then verify decisive claims against primary sources. Documentation and search results may be stale, even when hosted upstream; resolve inconsistencies against version-specific source and metadata.

## 5. Establish what a bug fix actually changed

When citing an upstream issue:

- Read the report and the maintainer's explanation.
- Inspect the linked fix.
- Determine which behavior it changes.
- Verify whether the evaluated release contains it.

Do not infer behavior from an issue's title alone. A historical bug is not evidence that the selected release remains defective. Use exact dates when timing matters.

## 6. Compare equivalent solutions

Compare complete implementations of the same required behavior, including:

- Correctness and failure modes.
- Ownership and lifecycle integration.
- Existing code replaced.
- Custom code still required.
- Dependency and migration cost.
- Tests and maintenance burden.

Do not compare a minimal custom sketch against a complete library migration. Line counts are estimates unless an implementation supports them. Fewer lines and fewer dependencies do not automatically mean greater reliability.

Before rejecting a library, check its relevant alternatives: synchronous operations, asynchronous operations, streaming, cancellation, teardown, and documented escape hatches.

## 7. Make lifecycle claims precise

These are different events:

- Cancellation requested.
- Signal sent.
- Process exited.
- Exit observed and resources released.

A parent-owned timer or queued callback cannot provide cleanup after the parent has exited. Normal quit, cancellation, sleep, crash, and force-quit each need separate reasoning and evidence. Do not call a path "proven" merely because it exists or succeeds in a different scenario.

## 8. State identity and recovery limits

For PID-based recovery or signaling:

- Validate the record and the complete process identity.
- Define record ownership, storage, replacement, and removal.
- Address concurrent instances and stale records.
- Revalidate identity before delayed signals.
- Explain any remaining check-to-signal race.
- Identify the processes the mechanism cannot discover.

Do not claim "cannot affect another process" unless the mechanism establishes that guarantee. Recovery on the next launch is different from cleanup when the parent dies.

## 9. Label evidence honestly

Use these labels for material conclusions:

- **OBSERVED LOCAL FACT:** directly checked in the current environment.
- **UPSTREAM FACT:** verified against an identified source and version.
- **INFERENCE:** reasoned from evidence, with assumptions stated.
- **UNVERIFIED:** not established.

Keep historical reports separate from fresh observations. Preserve unresolved findings as unresolved. For important claims, record enough context to reproduce the check: source location, version, command, result, or test.

## 10. Verify the chosen behavior

Use the project's existing test and build mechanisms. Cover the material lifecycle and failure cases the change affects. Tests must verify required behavior, not merely mirror implementation details.

A dependency's own tests do not prove our integration works. Source inspection does not substitute for executable verification where it is available. Report skipped checks and capability limits explicitly.

## 11. Keep research bounded

Batch independent checks. Reuse verified evidence. Stop researching when the decisive questions are answered; continue only to resolve a specific uncertainty that could change the decision. Do not expand a focused repair into a general architecture review.

## 12. Completion standard

Before claiming completion, report:

- What changed and why.
- What was reused.
- What custom behavior remains.
- What fresh verification established.
- What limitations remain.

Follow the user's authorized scope and the repository workflow. A read-only request permits no edits, installation, commits, or publishing.
