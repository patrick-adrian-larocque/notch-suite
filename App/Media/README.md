# Media engine integration scaffolding

These Swift files reserve the adaptation points for issue #24. They contain TODOs
only: no engine, fake player, or no-op `NowPlayingSource` is installed. Keep the
existing app behavior until the real implementation is ready.

| Location | Required follow-up |
| --- | --- |
| `MediaRemoteEngine.swift` | Package the fork's launcher/framework, own streaming and command processes, handle failures and shutdown. |
| `MediaRemoteNowPlayingSource.swift` | Implement the core protocol, parse updates, manage observers, and forward commands. |
| `NowPlayingPresentation.swift` | Bind playback/artwork to the island shell and connect accessible controls. |
| `../NotchSuiteApp.swift` | Own and start/stop the media integration with the app lifecycle. |
| `../../project.yml` | Add pinned engine resources and packaging/signing steps. |

Inspect [the owner's mediaremote-adapter fork](https://github.com/patrick-adrian-larocque/mediaremote-adapter)
and [boring.notch fork](https://github.com/patrick-adrian-larocque/boring.notch)
before implementation. The adapter README documents `/usr/bin/perl`, the launcher,
absolute framework paths, `stream`, and `send`; verify these against the pinned
revision. Follow `/port-from-reference` and preserve attribution when adding code.

Implement transport and source before presentation. Continue the existing shell
work in PR #44; connect views after that dependency lands. Track delivery in #24,
without treating this scaffold as completing the feature's acceptance criteria.
