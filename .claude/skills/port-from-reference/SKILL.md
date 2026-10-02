---
name: port-from-reference
description: How to adapt code or ideas from the reference repos (boring.notch, NotchDrop, mediaremote-adapter) into this project with the right attribution. Use whenever code from those repos is being copied, translated, or closely followed.
---

The reference repos are for reading. Never push to them.

| Repo | License | Notes |
|---|---|---|
| `patrick-adrian-larocque/boring.notch` | GPLv3 | Same license as this project |
| `patrick-adrian-larocque/notchdrop` | MIT | Keep the copyright and permission notice |
| `patrick-adrian-larocque/mediaremote-adapter` | BSD 3-Clause | Keep the copyright notice and conditions |

## Ideas vs. code

If you only follow an approach and write your own implementation, mention the inspiration (repo and file) in the PR description. No header is needed.

## Copying or closely adapting code

1. Take only what's needed.
2. Keep the original copyright notice in a header comment of the new file, and note that it was adapted. For example:
   `// Adapted from NotchDrop (MIT). Copyright (c) 2024 Lakr Aream.`
3. Make sure `THIRD_PARTY_LICENSES` has an entry for that project with its full license text. Add one if it's missing.
4. Fit the code to this project's layering:
   - Logic goes in `NotchCore`, with no AppKit, SwiftUI, or Combine.
   - Views go in the UI layer.
   - System integration goes in the app target, behind a protocol defined in `NotchCore`.
5. Add tests for the ported logic. Core tests run on Linux.
6. In the PR description, list what was ported, from which file, and at which commit of the reference repo.
