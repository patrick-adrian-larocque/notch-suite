// Integration scaffold only: the macOS NowPlayingSource implementation is pending.
// Follow-up: #24. Reuse Sources/NotchCore/NowPlayingSource.swift and its MediaCommand.
//
// TODO(#24): Implement NowPlayingSource over the transport in MediaRemoteEngine.swift.
// Choose actor isolation that satisfies the existing synchronous stream factory and
// Sendable contract; do not change NotchCore merely to accommodate process callbacks.
// TODO(#24): Feed complete stdout lines to NowPlayingStreamParser.ingest(line:).
// Publish parser.nowPlaying after valid envelopes; report malformed lines without
// discarding the last valid state. Reset the parser for a new engine session.
// TODO(#24): Give each observer its own AsyncStream, yielding current state first;
// remove terminated observers and finish streams during intentional shutdown.
// TODO(#24): Represent engine unavailability separately from a valid nil playback
// update so a missing engine cannot masquerade as a working source with no player.
// TODO(#24): Map MediaCommand play/pause/togglePlayPause/nextTrack/previousTrack to
// the fork's verified send command IDs; propagate delivery failures to the caller.
// TODO(#24): Add meaningful transport/parser integration tests for split lines,
// full/diff updates, player disappearance, command failure, restart, and cancellation.
