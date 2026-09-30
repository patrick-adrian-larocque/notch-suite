# Running CI on your Mac (self-hosted runner)

The repo is private. On GitHub Free that means 2,000 Actions minutes a month, and GitHub-hosted macOS minutes count 10x, which works out to about 200 macOS minutes. Jobs on your own machine don't use those minutes.

GitHub announced a $0.002/minute fee for self-hosted runners in private repos, due to start in March 2026, then postponed it. It hasn't taken effect. Check [GitHub's Actions pricing](https://github.com/resources/insights/2026-pricing-changes-for-github-actions) if that changes.

## What runs where

The repository variable `CI_RUNNER` picks the runner:

| Job | `CI_RUNNER` unset (default) | `CI_RUNNER` = `self-hosted` |
|---|---|---|
| Linux (Swift 6.4) | GitHub's Ubuntu runner, `swift:6.4-noble` in Docker (x86_64) | Your Mac, the same image through OrbStack (arm64) |
| macOS (Xcode) | GitHub's `macos-26`, skipped on draft PRs | Your Mac with your Xcode, drafts included |
| Claude, triage, label sync | GitHub's Ubuntu runner | Unchanged |

Pull requests from forks always use GitHub's runners, so code from outside the repo never runs on your Mac.

One runner handles both CI jobs. The Linux job doesn't need a Linux runner: `scripts/ci-swift.sh` runs each Swift command in the official Linux image with `docker run`. OrbStack provides `docker` on the Mac.

## One-time setup

Run these in Terminal on the Mac. They assume Homebrew and a logged-in GitHub CLI (`gh auth status`).

**1. Xcode.** Xcode should be installed and selected, with its license accepted:

```sh
xcode-select -p                  # should print /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

**2. OrbStack.**
1. Run `brew install --cask orbstack`.
2. Open OrbStack once so it finishes setup.
3. Turn on **Start at login** in its settings.
4. Check it works. The first run downloads the image, about 1 GB:

```sh
docker run --rm swift:6.4-noble swift --version
```

**3. The runner.** Run this from a Terminal where both `docker` and `xcodebuild` work. The runner saves that shell's `PATH` in `~/actions-runner/.path` and uses it for every job.

```sh
mkdir -p ~/actions-runner && cd ~/actions-runner
version=$(gh release view -R actions/runner --json tagName -q .tagName | sed 's/^v//')
curl -fsSLo runner.tar.gz \
  "https://github.com/actions/runner/releases/download/v${version}/actions-runner-osx-arm64-${version}.tar.gz"
tar xzf runner.tar.gz && rm runner.tar.gz
token=$(gh api -X POST repos/patrick-adrian-larocque/notch-suite/actions/runners/registration-token -q .token)
./config.sh --unattended --replace \
  --url https://github.com/patrick-adrian-larocque/notch-suite \
  --token "$token" \
  --name "$(scutil --get LocalHostName)"
./svc.sh install    # a LaunchAgent: runs whenever you're logged in
./svc.sh start
```

The runner gets the default labels `self-hosted`, `macOS` and `ARM64`, which are what `ci.yml` asks for.

GitHub's page for this (**Settings → Actions → Runners → New self-hosted runner → macOS → ARM64**) shows the same download with a checksum, if you'd rather copy from there.

**4. Turn it on.**

```sh
gh variable set CI_RUNNER --body self-hosted -R patrick-adrian-larocque/notch-suite
```

The runner should show as **Idle** under Settings → Actions → Runners. To try it, run CI by hand on any branch: `gh workflow run ci.yml -R patrick-adrian-larocque/notch-suite --ref <branch>`.

## Things to know

- **The Mac has to be awake, logged in, and running OrbStack.**
  - While it's off, CI jobs wait in the queue. After 24 hours they fail.
  - When you're away for a while, switch back to GitHub's runners with `gh variable delete CI_RUNNER -R patrick-adrian-larocque/notch-suite`.
- **Jobs run as your macOS user**, with access to your files. Keep the repo private while the runner is registered.
- **Swift versions:**
  - The macOS job calls `xcrun swift`, so it always uses the Swift that ships with your selected Xcode. swiftly toolchains and `.swift-version` files don't affect it.
  - The Linux version is the image tag in `ci.yml`.
  - `.swift-version` is gitignored for that reason.
- **CPU architecture:** on the Mac the Linux job builds for arm64, while GitHub's Ubuntu runner builds for x86_64. That rarely matters for this code.
- **Upkeep:**
  - The runner updates itself.
  - Check it with `cd ~/actions-runner && ./svc.sh status`.
  - Logs are in `~/actions-runner/_diag/`.
- **To remove it:**

  ```sh
  cd ~/actions-runner && ./svc.sh stop && ./svc.sh uninstall
  ./config.sh remove --token "$(gh api -X POST repos/patrick-adrian-larocque/notch-suite/actions/runners/remove-token -q .token)"
  gh variable delete CI_RUNNER -R patrick-adrian-larocque/notch-suite
  ```
