# Aphelion-Agents branch audit

Audited on 2026-09-05. Scope: all 29 files changed by `aphelion-agents` at `746576268fe` relative to merge base `d4afe59d00b387c293fbda0a808ce5184a5ee3f4` with the locally available `origin/master`. No remote refresh was performed. The audit checkout started clean, detached at the branch tip. Repairs are uncommitted working-tree changes.

The audit treated the existing tests and documentation as claims to verify, not acceptance evidence. Independent reviews covered process/reporting, guidance/checkers, and launchers; the controller was reviewed separately. Regression cases were observed failing before their corresponding repairs.

## Findings and applied repairs

| Priority | Finding | Repair and regression coverage |
| --- | --- | --- |
| P1 | The allow-network launcher returned a stale exit status; CALL reparsing and caller-relative caches broke some arguments and locations. | Preserve child status, scan options without CALL reparsing, validate network mode before bootstrap, resolve caches against the checkout, and disable inherited delayed expansion. Launcher tests cover failures, external cwd, percent/metacharacter arguments, and exclamation marks. |
| P1 | Full compilation could select a different compiler than the verified one and silently omit profile defines. Registry lookup requested the unnamed value instead of `installpath`. | Pass the qualified compiler through `DM_EXE`, forward defines to the fixed build target, and query the named registry value. |
| P1 | The inherited build graph omits `modular_aphelion`, allowing stale canonical artifacts after Meridian edits. | Supplement its cache with a fingerprint of the modular tree, dependencies, compiler, defines, and resulting artifact hashes. Invalidate the canonical pair when the fingerprint is missing or changes. Tests prove reuse without changes and rebuilding after a modular edit. |
| P1 | Lock publication exposed an empty file that another controller could reap; two controllers could both acquire ownership. | Publish a complete candidate atomically with a hard link. A delayed-write interleaving regression now permits only one owner. Cancellation also interrupts lock waiting. |
| P1 | Process inspection and cleanup errors were swallowed, falsely certifying successful ownership and cleanup. | Propagate typed supervision failures and mark unverified process cleanup in the final report. Failed cleanup returns exit 5, including failures during compilation. |
| P1 | PID-based discovery could adopt an unrelated replacement root; termination could race PID reuse. | Seed discovery from verified live identities, retain known orphan descendants, pin the process object before stopping it, and include children discovered during final cleanup in reports. Native tests verify owned descendants terminate while an unrelated process survives. |
| P1 | Natural root exit could leave pipe draining waiting on a surviving descendant; inspection helpers and unterminated probe output had incomplete bounds. | Clean descendants before draining inherited pipes, bound PowerShell helpers, enforce byte limits before line buffering, and react to output-consumer failures. |
| P1 | Fatal rules in other files were never read; final runtime records could be lost at shutdown. | Read every configured rule file, preserve whole-batch readiness ordering, support plain-text readiness files, and synchronously drain final records including a missing trailing newline. Run, test, and soak reject shutdown-time runtime failures. |
| P1 | Skipped tests or unrelated passing tests could satisfy requested-test acceptance. | Minimums count passes; every explicitly focused identity must pass. Preserve skip counts and reject completion runtime signatures even when a profile allows some occurrences. |
| P2 | Continuous child rules were ignored by run/test, and required artifacts were ignored by run/soak. | Enforce those profile contracts throughout the applicable workflows and join the monitors on exit/failure. |
| P2 | Partial deployment failures lost workspace ownership; rejected monitor races could leave background work active after finalization. | Publish workspace ownership immediately after exclusive creation, settle paired copies before cleanup, preserve requested retention, and abort/join monitor tasks on rejected races. |
| P2 | Some summary setters bypassed path redaction; profile paths and duplicate rule identities were insufficiently validated. | Redact at final serialization, cover Windows case variants and Unix profile roots, reject drive-relative/traversal paths, and reject duplicate counter identities. Raw child logs remain deliberately unredacted local evidence. |
| P2 | Doctor combined Git warnings with Git's revision/status output. | Parse only stdout as metadata while retaining stderr in diagnostic logs. A warning-emitting Git fixture now preserves the exact revision. |
| P2 | Marker checking examined additions without unchanged pairing context, missed deleted END markers, and accepted malformed syntax. | Compare complete old/new file context, report new syntax/pairing errors, and preserve unchanged legacy debt. The base CLI supplies the required full-context diff. |
| P2 | Documentation checks missed owned guides; guidance presented historical or external observations as current guarantees. | Expand routing/link checks, qualify historical plans and external contracts, correct Dogmos architecture provenance, preserve prior user authorization, and state map/configuration limits of `full_test`. |
| P2 | Launcher fixtures required a hard link to an executable outside their temp directory; native tests assumed all Windows supervision completed in five seconds. | Copy the executable fixture and use an explicit 30-second test deadline. Production timeout assertions remain intact. |

## Coverage

Reviewed controller source, process supervision, reporting, profiles, every original controller test, both launchers, both Python checkers and their tests, `AGENTS.md`, every branch-added agent document, and the module template. Reviewed the `.gitignore` change and the synchronized BYOND changes in `.tgs.yml`/`dependencies.sh`; no repair was needed for those three files. BYOND 516.1687 was verified locally. No game source, creative content, human build entry point, deployment configuration, or CI workflow was rewritten by this audit.

New regression coverage is in `tools/rift/*-audit.test.ts`; shared runtime fixtures are in `tools/rift/workflow-evidence.fixture.ts`. Run `bun test tools/rift`, not just the original `rift.test.ts`, to include these cases.

## Verification

| Gate | Result | Evidence |
| --- | --- | --- |
| Complete controller suite | 134 passed, 0 failed; 348 assertions | Pinned Bun 1.3.5 on Windows with CIM access; `data/rift-audit-controller-final.log`; 118.20 seconds. |
| Python checker suites | 18 passed | Python 3.11.0 with the checkout added to its embedded interpreter import path; also passed on Python 3.13.2. `data/rift-audit-python-pinned.log`. |
| Documentation/marker CLIs | Passed | `python tools/ci/check_agent_docs.py`; `python modular_aphelion/tools/aphelion_marker_check.py --base origin/master`. |
| Formatting/diff checks | Passed | Biome checked 12 controller files; `git diff --check`. |
| Direct DreamMaker | 0 errors, 3 expected build-entry warnings | BYOND 516.1687, `data/rift-audit-dm-host.log`; 1:53 compiler time. Compiler-only evidence. |
| Real RIFT full build | Passed; fresh DMB/RSC | Offline run `20260905T122129Z-b7e4c61e`; 0 errors/0 warnings; DMB SHA-256 `41b58ea2a1026039c7fcdb6d769ddd69f8eef2623df585997ff4901484c784bc`, RSC SHA-256 `03fcbf19f38de59901583313e77513d8e022c9d87156e9a030cdebb2771a1534`. |
| RuntimeStation soak | Passed | Run `20260905T122619Z-9cc781cb`; full 30-second post-readiness window, zero runtime signatures, six DreamDaemon resource samples, requested termination, cleanup passed with no leftovers. Total workflow time was 294.677 seconds, including build/deployment/initialization. |
| Focused MetaStation test | Timed out before readiness; no test results | Run `20260905T123639Z-e6240503`, `data/rift-audit-focused-final.log`. CIBUILDING compilation passed with 0 errors and 2 expected instrumentation warnings. The audit's 300-second readiness override elapsed during initialization; the CI profile normally allows 600 seconds. DreamDaemon was stopped and cleanup passed with no leftovers. This is timeout/cleanup evidence, not a passing focused test. |

Each live run's `data/rift-runs/<run-id>/summary.json`, `events.ndjson`, and artifact manifest are the detailed local evidence. They are gitignored. Raw logs may contain local paths and configuration details; do not publish them without review.

The initial restricted run reported 80 controller tests passing and four failures. Native CIM queries were denied, launcher fixture hard links were denied, and BYOND opened a first-run folder dialog. Those restrictions were separated from code defects; the exact blocked compiler process was stopped and host validation used the configured environment. The first host suite exposed the ignored missing-PID lookup leaving PowerShell's exit status false. A native regression reproduced that issue and the repaired suite passed. An earlier full-build attempt also returned compiler exit 255 without a compiler diagnostic; the fresh sequential full-build rerun passed. These earlier attempts are not counted as successful gates.

A first focused-test attempt failed because a successful native inspection exceeded the original five-second helper deadline. The bounded helper deadline is now 15 seconds; regression cases cover a successful six-second inspection and termination of a hung helper. A controller-suite run concurrent with MetaStation initialization hit four fixture deadlines (130 passed, four timed out); launcher and lock fixtures now have explicit 30-second test deadlines, and the final suite was rerun after the server stopped. Production timeout assertions were preserved.

## Remaining limits and follow-up

1. **Process-tree containment is incomplete.** Polling cannot recover a descendant whose intermediate parent exited before discovery. Instance-safe cleanup protects known processes, but does not prove that no undiscovered descendant exists. For a hard containment guarantee, add a Windows Job Object supervisor, assign the root before it can create children, prevent breakaway, and test short-lived intermediate launchers and cancellation with real processes. Do not describe current polling as that guarantee.
2. **Timeouts are per child and stage.** Deployment, collection, and verified cleanup add time beyond a child wall limit. Callers must budget the whole workflow separately. Cancellation is checked between operations; file copies are not preempted midway.
3. **Acceptance remains scoped.** `full_test` is selected-map/configuration evidence; this audit does not establish all-map tests, hosted CI, installed Meridian-MCP end-to-end behavior, MariaDB-backed scenarios, Dogmos paired-native integration, or human gameplay acceptance. The full build exercised the inherited build target through RIFT, not the interactive `BUILD.cmd` wait path.
4. **Supplemental invalidation is conservative.** Changes to documentation or Python caches beneath `modular_aphelion` can cause an extra compile. Narrowing that set requires an authoritative resource/input manifest; prefer an unnecessary rebuild to stale evidence.
5. **Marker checking is scoped.** The checker validates syntax/pairing regressions in tracked changes. It does not prove every core edit has a marker and does not review untracked files. The stdin interface requires full-context diffs.

The outstanding focused-game qualification can be rerun without the shorter audit deadlines: `RIFT.cmd test --profile ci --map _maps/metastation.json --focus /datum/unit_test/simple_animal_freeze --network offline --format result`. Require the requested test to pass, the clean-run artifact, natural DreamDaemon shutdown, and successful cleanup before recording that gate as passed.

The audited branch is materially safer after the repairs. The remaining process containment limit is an architectural follow-up, not a passing-test guarantee.
