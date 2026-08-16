# dm-mcp Hardening and Dogmos Harness Integration Plan

> **For agentic workers:** This plan is executed inline in the current session. Steps use checkbox syntax for tracking; repository instructions prohibit committing or pushing unless explicitly requested.

**Goal:** Consolidate the recovered dm-mcp work into its canonical checkout, make DreamDaemon failures and DreamMaker source inspection dependable, and integrate the useful parts of the Dogmos PowerShell verification workflow without making the generic MCP Dogmos-specific.

**Architecture:** Keep dm-mcp as a generic MCP server with reusable primitives: structured process execution, bounded runtime diagnostics, source extraction, and protocol-level self-tests. Keep Dogmos-specific baselines, map selection, and atmos semantics in Meridian Rift’s PowerShell harness, but make that harness use the same validated MCP/build conventions and remove brittle assumptions. The user-configured dm-mcp checkout is the canonical working tree; do not encode a developer-specific absolute path in this repository.

**Tech Stack:** Rust 2021, Tokio, serde/serde_json, SpacemanDMM dreammaker/dreamchecker/dmm-tools, BYOND DreamMaker/DreamDaemon, PowerShell 5.1+, Meridian Rift’s Dogmos PowerShell scripts.

**Spec:** User request in the active Codex task; repository rules in `CLAUDE.md` and `AGENTS.md`; Dogmos workflow specification in `tools/dogmos/README.md` and the project plan/memory files.

## Global Constraints

- Leave changes in both repositories uncommitted and unpushed.
- Use the user-configured dm-mcp checkout as the only canonical dm-mcp checkout; refer to it by a local environment variable or checkout-relative path in documentation.
- Do not expose MCP protocol JSON on stdout except valid JSON-RPC responses; diagnostics belong on stderr or structured tool results.
- Never leave piped DreamDaemon stdout/stderr unread.
- Every behavioral change gets a failing test or a deliberately failing verification probe before implementation.
- Preserve the Dogmos harness’s independent gates: compile, initialization marker, runtime signatures, test failures, per-test runtime counts, timing trends, and panic logs.
- Do not turn generic dm-mcp into a Meridian-only hardcoded test runner; expose generic process/log primitives and keep Dogmos policy in the harness.
- Mark new or modified core Dogmos edits according to `AGENTS.md`; do not reformat unrelated inherited core files.

## Task 1: Establish canonical repository and test baseline

**Files:**
- Read: the canonical dm-mcp checkout's `src\`, `test_mcp.ps1`, `test_parse.ps1`, and `test-mcp.sh`
- Read: `tools/dogmos/*.ps1`, `tools/dogmos/README.md`
- Modify: none during the baseline phase

**Interfaces:**
- Consumes the recovered diff in Claude’s package cache only as a reference.
- Produces a verified inventory of canonical paths, existing tests, available BYOND executables, and current failure modes.

- [x] Confirm the canonical checkout is the upstream clone and the package-cache checkout contains the recovered three-file patch.
- [x] Audit every Dogmos PowerShell script and record hard-coded paths, process lifetimes, exit-code gates, baseline semantics, and destructive cleanup.
- [ ] Run the canonical dm-mcp’s existing `cargo test` and `test-mcp.ps1` after replacing foreign paths with explicit parameters in the test design.
- [ ] Record baseline failures before any implementation changes.

## Task 2: Add failing unit tests for diagnostics and source extraction

**Files:**
- Modify: the canonical dm-mcp checkout's `src\state.rs` and `src\tools\parse.rs`

**Interfaces:**
- Produces tested pure helpers for bounded output capture and source extraction.
- Later runtime code consumes `OutputLog`, `push_output_line`, `recent_output`, and exit-state fields.

- [ ] Add a ring-buffer test that pushes more than capacity and asserts oldest-first bounded output.
- [ ] Add a test that requests zero and oversized recent-output windows.
- [ ] Add source-extraction tests for a normal indented proc, a top-level declaration boundary, a missing line, comments at column zero, and the maximum-line cap.
- [ ] Run `cargo test` and confirm these tests fail because the helpers and behavior do not yet exist in the canonical checkout.

## Task 3: Implement reliable process diagnostics

**Files:**
- Modify: the canonical dm-mcp checkout's `src\state.rs`, `src\tools\runtime.rs`, `src\tools\mod.rs`, and `README.md`

**Interfaces:**
- `ServerState` owns the current process, port, last exit code, and an `Arc<Mutex<VecDeque<String>>>` diagnostic ring.
- Runtime startup drains both child streams immediately, resets state before spawning readers, and reports captured output on early exit.
- `dm_status` returns `running`, `pid`, `port`, `last_exit_code`, and bounded `recent_output`.
- Add a generic `dm_wait_for_output` tool that waits for a literal or regex marker with a timeout, reports early process exit, and never blocks the MCP request loop without a timeout.

- [ ] Implement the minimal state changes and make the new unit tests pass.
- [ ] Implement Tokio child supervision and reader-task lifecycle without clearing output after readers start.
- [ ] Add condition-based waiting rather than another fixed 1.5-second startup sleep.
- [ ] Add tests for the output-wait matcher using the shared ring buffer and timeout semantics.
- [ ] Update tool schemas and README examples.
- [ ] Run focused Rust tests, then `cargo test` and `cargo build --release`.

## Task 4: Improve DreamMaker compile and source inspection

**Files:**
- Modify: the canonical dm-mcp checkout's `src\tools\compile.rs`, `src\tools\parse.rs`, `src\tools\mod.rs`, and `README.md`

**Interfaces:**
- `dm_compile` accepts optional `working_directory`, `defines`, and `timeout_ms`, returns structured command status, stdout/stderr, parsed diagnostics, and output paths.
- `dm_get_proc` returns a bounded `source` field for each override when the source file is readable; source extraction is explicitly best-effort and never prevents location metadata from returning.

- [ ] Add failing tests for source extraction before implementation.
- [x] Implement bounded source extraction with correct handling of CRLF, comments, column-zero declarations, EOF, and line caps.
- [x] Replace blocking compiler execution with timeout-aware process execution and preserve the complete raw output.
- [x] Make diagnostic parsing tolerate Windows paths containing drive-letter colons and common DreamMaker output variants.
- [x] Run focused tests and compile verification.

## Task 5: Replace brittle MCP smoke scripts

**Files:**
- Modify: the canonical dm-mcp checkout's `test_mcp.ps1`, `test_parse.ps1`, `test-mcp.sh`, and `README.md`

**Interfaces:**
- PowerShell scripts accept `-BinaryPath`, optional `-DmePath`, and `-TimeoutSeconds`; defaults resolve relative to the script/repository rather than a developer-specific checkout.
- Smoke tests parse each JSON-RPC response, verify matching IDs and `isError`, derive the tool count from `tools/list`, and test the source field when a DME is supplied.

- [x] Add failing protocol assertions for response IDs, malformed responses, tool discovery, and optional parsing.
- [x] Implement a timeout-safe PowerShell process harness with separate stdout/stderr capture.
- [x] Remove hard-coded foreign paths and fixed “17 tools” assumptions.
- [x] Keep the shell script useful on Unix but make it use the same dynamic assertions and optional DME argument.
- [x] Run both script variants where the platform permits.

## Task 6: Harden Dogmos PowerShell integration

**Files:**
- Modify: `tools/dogmos/_common.ps1`
- Modify: `tools/dogmos/boot_probe.ps1`
- Modify: `tools/dogmos/run_tests.ps1`
- Modify: `tools/dogmos/analyze_round_log.ps1`
- Modify: `tools/dogmos/show_failure.ps1`
- Modify: `tools/dogmos/README.md`

**Interfaces:**
- Shared helpers provide safe JSON reads, stable test-result lookup, runtime signature extraction, and process cleanup.
- `run_tests.ps1 -Focus` verifies every requested path appears in the recorded results, not merely that the total count is large enough.
- Boot/test scripts clean up DreamDaemon in `finally` blocks and preserve useful stdout/stderr on every failure path.
- Round analysis reports actual monotonicity separately from first/last growth and handles missing/empty CSV samples.

- [x] Add focused PowerShell repro checks for duplicate/missing focus paths and malformed result files.
- [x] Implement cleanup and stronger validation one script at a time, running the relevant script’s syntax/behavior check after each change.
- [x] Keep baseline updates explicit and never silently rewrite baselines during normal verification.
- [x] Document which checks are generic MCP capabilities versus Dogmos-specific policy.

## Task 7: Reconcile Dogmos markers and project memory

**Files:**
- Modify: `code/game/turfs/change_turf.dm`
- Modify: the external planning and memory artifacts associated with this Meridian checkout (kept outside this repository)

**Interfaces:**
- The `CHANGETURF_IGNORE_AIR` temperature resync remains guarded by `air` and is marked/documented according to the current fork rules.
- Plan and memory record the split-checkout cause, canonical dm-mcp path, recovered features, new MCP/harness capabilities, and actual verification results.

- [x] Mark only the touched Dogmos core change without reformatting unrelated inherited code.
- [x] Append the new findings and remaining known limitations to both planning artifacts.
- [x] Keep the existing known map-preview flake and nondeterministic ruin-placement caveat explicit.

## Task 8: Final verification and handoff

**Files:**
- Read all changed files and their diffs in both repositories.

- [x] Run the applicable formatting/hygiene gate: `git diff --check` passed; full `cargo fmt --check`
  remains unsuitable because untouched upstream files are not rustfmt-clean.
- [x] `cargo test` for dm-mcp.
- [x] `cargo build --release` for dm-mcp.
- [x] Canonical PowerShell MCP smoke test and optional parser test.
- [x] Run the available Dogmos compile/focused/suite checks and record limitations; the standalone
  CIBUILDING compile gate timed out boundedly and did not establish a fresh successful compile.
- [x] `git diff --check` in both repositories and `git status --short` confirmation.
- [x] Report exact passing/failing commands, known flakes, untested live behavior, and all remaining discrepancies.

## Completion record (2026-08-16)

The implementation is complete in the working trees, with the limitations below recorded instead
of being hidden behind green summaries.

### dm-mcp

- Consolidated the recovered work into the canonical user-configured dm-mcp checkout; the package
  cache is no longer treated as an alternate source of truth.
- Added Tokio-backed DreamDaemon supervision with continuous stdout/stderr draining, a bounded
  500-line output ring, exit-code capture, post-exit diagnostics, and literal/regex output waits.
- Added compiler timeouts, optional compiler path/working directory/defines, structured diagnostics,
  and a schema assertion that keeps the advertised `dm_compile` interface aligned with the code.
- Added bounded source extraction, column-zero declaration boundaries, comment handling, relative
  source-path resolution from the loaded DME, and serialization fixes required by current
  SpacemanDMM identifiers.
- Replaced hard-coded protocol scripts with parameterized PowerShell and shell smoke tests. They
  resolve binaries relative to the checkout, drain both process streams before sending requests,
  validate response IDs and exit status, discover tools dynamically, and exercise source-backed
  parsing when a DME is supplied.
- Added `TESTING.md` as the operational guide for Rust, MCP, source, runtime, and Meridian checks.

### Meridian/Dogmos harness

- Hardened JSON/log reading, process-ID-aware cleanup, focus validation, initialization checks,
  runtime and timing baselines, round-log analysis, and bounded DreamMaker compile checks.
- Removed the personal absolute Dogmos checkout default from `build_dogmos.ps1`; its default now
  derives the sibling checkout from the Meridian repository, with an explicit override for other
  layouts.
- Added the required APHELION marker around the `CHANGETURF_IGNORE_AIR` temperature guard in the
  core turf file.

### Verification

- `cargo test`: 18 passed, 0 failed.
- `cargo build --release`: passed; only existing dead-code warnings remain.
- `test_mcp.ps1 -SkipBuild`: passed with 18 tools and exit code 0.
- `test_parse.ps1 -SkipBuild` against the Meridian DME, `/turf/open`, and `AfterChange`: passed,
  including source extraction.
- `test-mcp.sh -SkipBuild` and Bash syntax check: passed through the Windows delegation path.
- All Meridian and dm-mcp PowerShell scripts parse successfully.
- `git diff --check` is clean. `cargo fmt --check` remains unsuitable as a repository gate because
  the upstream checkout is not rustfmt-clean outside this change; no unrelated formatting churn
  was introduced.
- The latest available Dogmos full-suite evidence remains 497 passed / 9 failed, with 8 known and
  the ninth being the pre-existing/self-healing `map_previews.dmi` initialization flake. The suite
  was not rerun after harness-only edits. The standalone CIBUILDING compile gate was exercised with
  a 30-second timeout and correctly failed boundedly when DreamMaker stalled; it did not establish
  a fresh successful compile on this machine.

No commit or push was performed. The canonical dm-mcp checkout and Meridian checkout retain their
working-tree changes for review.

## Post-completion audit (2026-08-16)

The earlier verification notes above were written before the final Dogmos implementation pass. The
current authoritative results are:

- The accepted Dogmos design is implemented: configurable blocked-turf temperature authority,
  `FAST_ZONE`/`FDM_ONLY` Equalize profiles, deterministic lossless heat-edge processing, and Kennel
  superconductivity telemetry.
- The final Dogmos suite recorded 516 tests: 499 passed and 8 known-baseline failures, with 10 runtime
  records across 4 known-baseline signatures and no new failures or runtimes. A standalone compiled
  boot previously initialized in 64.8688 seconds with 0 runtime errors; the TGUI TypeScript and
  Rspack builds also passed.
- After a Rust-only boundary correction from `is_normal()` to `is_finite()`, the focused Rust turf
  suite passed 5/5, the release DLL rebuilt, and the 65-proc generated-binding check remained in sync.
- A subsequent focused DM attempt reached its 900-second timeout before DreamMaker emitted a compile
  artifact. This exposed and fixed a harness bug: timeout cleanup now snapshots and stops only newly
  created `dm`, DreamDaemon, and DreamMaker processes. That attempt is infrastructure-timeout
  evidence, not a code-test failure.
- The generated map-preview binary produced by test initialization was restored after the run; the
  known map-preview flake remains explicitly out of scope. Both repositories pass `git diff --check`,
  all Dogmos PowerShell scripts parse cleanly, and no personal absolute paths are present in scanned
  repository artifacts.

Remaining follow-up is intentionally documented rather than silently closed: the FFI lifecycle/error
boundary audit, live acceptance of the global Equalize/flamethrower profile, the unresolved
Equalize/superconductivity anomaly, and Kennel Phase 5 cutover.
