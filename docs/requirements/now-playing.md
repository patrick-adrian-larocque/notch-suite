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
- R2. Run `/usr/bin/perl <script> <framework> stream --no-artwork --debounce=100` as one
  long-lived child process. Fetch artwork separately (R9) so updates stay small.
- R3. Treat "engine failed" separately from "nothing playing". A failed engine must not
  show as an empty island; show nothing and log it, and retry with backoff.
- R4. Stop the child on quit and on sleep, restart on wake. No orphaned perl processes.

**Data**
- R5. Feed each complete stdout line to `NowPlayingStreamParser`. A rejected line is
  logged and the last good state is kept.
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
| A1 | Music and Spotify playback updates the island within 1 s | manual, Developer ID signed build |
| A2 | prev/play/pause/next reach the player | manual |
| A3 | Slow or missing artwork shows the fallback | manual plus `ArtworkState` tests |
| A4 | Engine missing or killed: no fake "nothing playing", recovers | unit test with a fake process plus manual `kill` |
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
| With an ad-hoc framework, `get` printed `null` and `stream` printed only an empty payload while QuickTime was playing | local run | local 2026-10-03, see open question 1 |
| A Developer ID signature on the framework is required for data on 15.4+; ad-hoc loads but returns empty sessions | ultra-media-remote README (third party, not upstream) | online only, not confirmed |
| boring.notch vendors the same three files, ad-hoc signed in the repo, re-signed when the app is signed | boring.notch `dev` `mediaremote-adapter/` | 2026-10-03 |
| Commands may be blocked on macOS 26.1+ for some setups | gist comment (ejbills, 2025-11) | online only, not confirmed |
| Commands always go to the system's elected player, not a chosen app | adapter issue #41 | online 2026-10-03 |
| Apple has said scripting runtimes, including Perl, may not ship by default in future macOS; still present in 27.2 | Xcode 11 release notes (2019); local `/usr/bin/perl` | 2026-10-03 |

## Open questions and blockers

1. **Signing (blocker for A1).** This Mac has no code-signing identity
   (`security find-identity` found 0). The ad-hoc test returned no data, which matches the
   third-party Developer ID claim, but QuickTime may simply not publish Now Playing. Needs
   a test with Music or Spotify playing, signed with an Apple Development or Developer ID
   certificate. Until then, A1 and A2 can't pass locally.
2. **Commands on 26.1+.** Confirm `send` works on this Mac once data flows.
3. **Perl removal risk.** If a future macOS drops `/usr/bin/perl`, the engine stops. R3
   makes that visible instead of silent; no fallback is planned now.
