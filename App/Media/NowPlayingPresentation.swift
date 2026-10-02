// Integration scaffold only: media presentation is not connected to the island yet.
// Follow-up: #24; coordinate with the existing island shell PR #44 / issue #23.
//
// TODO(#24): Own a single source observation task in the app's media presentation
// model. Bind updates to the existing PlaybackState, PlaybackProgress, and artwork
// models; cancel observation and stale artwork work when the source/player changes.
// TODO(#24): Adapt suitable media UI integration from the owner's boring.notch fork
// after inspection, preserving original notices whenever implementation code is reused.
// TODO(#24): Supply compact/peek/open player views to the shell after #44 lands;
// avoid replacing or duplicating that PR's hover/click handling and panel geometry.
// TODO(#24): Load artwork off the main actor with loading/missing/error fallbacks;
// ensure late results cannot overwrite newer tracks. Handle paused progress correctly.
// TODO(#24): Route prev/play/next actions through NowPlayingSource.send; expose
// unavailable/failed controls accessibly instead of silently ignoring button presses.
// TODO(#24): Verify Music/Spotify, player switching, long titles, artwork failure,
// pause/resume, sleep/wake, reduce motion, and VoiceOver with hands-on testing.
