# mediaremote-adapter (vendored)

Unmodified files from [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter),
BSD 3-Clause (see `LICENSE` here and `THIRD_PARTY_LICENSES`). The owner's fork,
[patrick-adrian-larocque/mediaremote-adapter](https://github.com/patrick-adrian-larocque/mediaremote-adapter),
is at the same revision.

- Revision: `73f14ab1568371e6e3c44063f21c34c5e2712c4d` (2026-09-04)
- `mediaremote-adapter.pl`: copied from `bin/`.
- `MediaRemoteAdapter.framework`: built from that revision with CMake, universal
  (`x86_64`, `arm64`).

## How the app uses it

`project.yml` copies the script into `Contents/Resources` and the framework into
`Contents/Frameworks` without linking it. `App/Media/MediaRemoteEngine.swift` runs:

```text
/usr/bin/perl <Resources>/mediaremote-adapter.pl <Frameworks>/MediaRemoteAdapter.framework stream ...
```

`/usr/bin/perl` is a platform binary that MediaRemote still serves on macOS 15.4 and
later; the app itself can't read MediaRemote directly.

## Updating

```sh
git clone https://github.com/ungive/mediaremote-adapter && cd mediaremote-adapter
git checkout <revision>
cmake -S . -B build && cmake --build build
cp bin/mediaremote-adapter.pl <repo>/Vendor/mediaremote-adapter/
rm -rf <repo>/Vendor/mediaremote-adapter/MediaRemoteAdapter.framework
cp -R build/MediaRemoteAdapter.framework <repo>/Vendor/mediaremote-adapter/
```

Then update the revision above and in `docs/requirements/now-playing.md`, and rerun
the live check in `App/Media/README.md`.
