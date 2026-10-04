# Now Playing requirements (#24)

Status: draft, last checked 2026-10-03 on macOS 27.2 (26B5091g), Apple silicon.
Keep this file current: when a fact below changes, update it and its "Checked" column.

## Goal

The island shows what is playing system-wide and controls it, using as little new
code as possible. Reuse what already exists before writing anything new.

## Approach: reuse first

| Need | Reuse | New code |
| --- | --- | --- |
| Read playback | mediaremote-adapter `stream`, vendored unchanged | none |
| Parse output | `NowPlayingStreamParser` (NotchCore, already tested) | none |
| Run the process | adapt boring.notch `NowPlayingStreamSupport.swift` (251 lines, GPLv3) | trim to what we use |
| Commands | adapter `send <id>` | a 5-case `MediaCommand` to ID map |
| Progress, playback, artwork state | `PlaybackProgress`, `PlaybackState`, `ArtworkState` (NotchCore) | none |
| Views | `IslandView` levels from #44 | compact, peek, open content only |

Don't add: AppleScript fallbacks, per-app controllers, favorites, shuffle/repeat,
seeking, or lyrics. They can come later as separate issues if wanted.

## Requirements

**Engine**
- R1. Bundle `mediaremote-adapter.pl` in Resources and `MediaRemoteAdapter.framework`
  in Frameworks, pinned to upstream `73f14ab` (the owner fork's HEAD). The framework is
  passed to the script by absolute path, never linked.
- R2. Run `/usr/bin/perl <script> <framework> stream --debounce=100` as one long-lived
  child process. Artwork is included in the stream rather than fetched separately:
  with diffs on, the adapter sends it once per track, not with every update.
- R3. Treat "engine failed" separately from "nothing playing". A failed engine must not
  show as an empty island; show nothing and log it, and retry with backoff.
- R4. Stop the child on quit and on sleep, restart on wake. No orphaned perl processes.

**Data**
- R5. Feed each complete stdout line to `NowPlayingStreamParser` and act on its
  `NowPlayingReport` (PR #50): `.session` yields the track, `.noSession` yields `nil`,
  and `.incomplete` or a rejected line is logged while the last good state is kept.
- R6. Ignore the empty first payload (`{"payload":{}}`); upstream issue #23 says
  stream always prints it.
- R7. Treat non-finite `duration` as unknown (upstream issue #28).

**Controls**
- R8. Map `play 0, pause 1, togglePlayPause 2, nextTrack 4, previousTrack 5` to
  `send <id>`, run as a short-lived process with argument arrays, never a shell string.
  Report a non-zero exit as a failed command.

**UI**
- R9. Compact shows artwork and eq bars, peek adds the title, open adds artist, progress
  and prev/play/next. Artwork loads off the main actor; a late result can't replace a
  newer track.
- R10. Eq bars stop when paused or when reduce motion is on. Long titles truncate.
- R11. Every control has a VoiceOver label and reports when it can't act.

**Licensing**
- R12. Keep the existing mediaremote-adapter entry in `THIRD_PARTY_LICENSES`. Add a
  boring.notch (GPLv3) entry for any adapted code, and keep its file header notice.

## Acceptance checks

| # | Check | How |
| --- | --- | --- |
| A1 | Music and Spotify playback updates the island within 1 s | manual, Debug build |
| A2 | prev/play/pause/next reach the player | manual |
| A3 | Slow or missing artwork shows the fallback | manual plus `ArtworkState` tests |
| A4 | Engine missing or killed: no fake "nothing playing", recovers | `NowPlayingPresentationTests.engineHealthDrivesIsEngineDown` (`NotchSuiteTests`, over a fake `NowPlayingSource`) plus manual `kill` against the real adapter |
| A5 | Split lines, CRLF, diffs, player gone | parser tests (exist) plus line-buffer tests |
| A6 | Quit and sleep leave no `perl` child | `pgrep -f mediaremote-adapter` |
| A7 | Licenses complete | `license-auditor` agent |

## Facts, sources and verification

| Fact | Source | Checked |
| --- | --- | --- |
| Since macOS 15.4, apps can't read MediaRemote directly; the adapter works by running inside `/usr/bin/perl` | adapter README; media-remote (Rust) README | online 2026-10-03 |
| Adapter last tested by upstream on macOS 27.0 (26A5425a) | adapter README badge | online 2026-10-03 |
| Owner fork is 1 commit behind upstream (a dev convenience script only) | `gh api compare` | 2026-10-03 |
| Adapter builds universal (x86_64, arm64) with CMake, ad-hoc signed by default | local build | local 2026-10-03 |
| `test` exits 0 with an ad-hoc framework on macOS 27.2 | local run | local 2026-10-03 |
| An ad-hoc signed framework returns full data: `get`, `stream` (with `diff:false` updates) and `send 1` (pause delivered) all worked against a test app publishing `MPNowPlayingInfoCenter` | local probe app | local 2026-10-03 |
| QuickTime Player and Safari playing a local file published nothing (`null`), so they can't be used to test | local run | local 2026-10-03 |
| A third-party README claims a Developer ID signature is required on 15.4+ | ultra-media-remote README | contradicted locally on 27.2; recheck if data stops |
| The payload can omit `bundleIdentifier`. The adapter's source requires only `processIdentifier`, `playing` and `title` (`src/adapter/keys.m`) and adds `bundleIdentifier` when it can look the process up; its README is wrong. Handled by PR #50: identity is optional and a missing bundle ID is still a session | local probe; adapter source | local 2026-10-03, source 2026-10-04 |
| boring.notch vendors the same three files, ad-hoc signed in the repo, re-signed when the app is signed | boring.notch `dev` `mediaremote-adapter/` | 2026-10-03 |
| Commands may be blocked on macOS 26.1+ for some setups | gist comment (ejbills, 2025-11) | contradicted locally: `send 1` paused the test app on 27.2 |
| Commands always go to the system's elected player, not a chosen app | adapter issue #41 | online 2026-10-03 |
| Apple has said scripting runtimes, including Perl, may not ship by default in future macOS; still present in 27.2 | Xcode 11 release notes (2019); local `/usr/bin/perl` | 2026-10-03 |

## Open questions and blockers

1. **Missing `bundleIdentifier`.** Resolved in PR #50: the parser already treats it as a
   normal session. A missing bundle ID is valid evidence, not a failure. With Music and
   Spotify, check that the source yields a session, identity resolves as far as the bundle
   ID or process ID allows, the UI behaves without a bundle ID, and updates and controls work.
2. **Signing.** No blocker on this Mac today (no signing identity needed). If a later
   macOS starts returning empty sessions, try an Apple Development signature first.
3. **Perl removal risk.** If a future macOS drops `/usr/bin/perl`, the engine stops. R3
   makes that visible instead of silent; no fallback is planned now.
