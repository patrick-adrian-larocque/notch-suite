// Integration scaffold only: no engine is bundled or launched yet.
// Follow-up: #24. Source: https://github.com/patrick-adrian-larocque/mediaremote-adapter
//
// TODO(#24): Inspect the fork's build instructions and pin the revision being integrated.
// TODO(#24): Bundle mediaremote-adapter.pl and MediaRemoteAdapter.framework; resolve
// their absolute paths from Bundle resources. Update project.yml's copy/embed steps,
// signing, and THIRD_PARTY_LICENSES with the required original notices.
// TODO(#24): Implement an owned process transport using /usr/bin/perl with arguments
// [scriptPath, frameworkPath, "stream"]. Keep stderr separate from JSON stdout.
// TODO(#24): Buffer UTF-8 stdout into complete lines across partial reads and CRLF.
// TODO(#24): Expose process failures separately from "nothing is playing"; handle
// cancellation, exit status, bounded restart/backoff, sleep/wake, and pipe cleanup.
// TODO(#24): Implement short-lived "send" command processes using the documented
// numeric command IDs. Check errors/exit status; never interpolate a shell command.
// TODO(#24): Verify framework/helper signing and macOS compatibility on the real Mac.
