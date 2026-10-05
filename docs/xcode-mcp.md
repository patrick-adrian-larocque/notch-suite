# Xcode MCP and XcodeGen

Apple's native Xcode MCP server (`xcrun mcpbridge`, configured as `xcode-tools` in
`.mcp.json`) is a **local agent capability** for inspecting, building and testing the app.
It does not own the project. Checked on Xcode 27.0 (27A266a), server version 25317.

## Ownership rule

**`project.yml` owns Xcode project structure.** That means targets, source membership,
package dependencies, framework embedding, build phases, entitlements, Info.plist settings,
target dependencies, schemes and the structural build settings in the spec.
`NotchSuite.xcodeproj` is generated output and is gitignored.

An edit made to the generated project through MCP is **not** a project change. Regenerating
discards it. Verified on a scratch copy: a new target and a changed `MARKETING_VERSION`
added through MCP were gone after `xcodegen generate`, and the same file's project IDs
changed. MCP edits are not a substitute for editing `project.yml`.

## Normal local workflow

1. Edit `project.yml` for any structural change.
2. Run `xcodegen generate`.
3. Open the result through MCP: `XcodeOpenWorkspace` on `NotchSuite.xcodeproj` (it asks
   each time). Xcode.app does not need to be open.
4. Build, test and inspect through MCP (`BuildProject`, `GetBuildLog`, …) or through the
   repository scripts (`./script/verify.sh`, `./script/build_and_run.sh --build-only`). To
   run tests, call `XcodeListSchemes` and switch to a scheme that has a test action; don't
   assume a name. The scheme list changes with `project.yml`: on a checkout without
   `AppTests/` the generated project has only `NotchSuite` and `NotchCore`, and neither runs
   tests (`xcodebuild` reports "not currently configured for the test action"). The core
   tests run with `swift test`.
5. CI regenerates the project from `project.yml` on its own and builds with `xcodebuild`.
   **CI never depends on the MCP service.**

MCP builds use Xcode's default DerivedData, not `build/DerivedData`.

## What agents may use

The server exposes 54 tools. The repository allows or denies them like this:

| Class | Tools | Policy |
|---|---|---|
| Read and session | `GetFileCompilerFlags`, `GetTargetBuildSettings`, `DocumentationSearch`, `XcodeGlob`, `XcodeGrep`, `XcodeLS`, `XcodeRead`, `XcodeListRunDestinations`, `XcodeListSchemes`, `XcodeListTargets`, `XcodeListTemplates`, `XcodeListTestPlans`, `XcodeListWorkspaces`, `StringCatalogRead`, `StringCatalogContext`, `XcodeOpenWorkspace`, `XcodeCloseWorkspace`, `XcodeSwitchScheme`, `XcodeSwitchRunDestination`, `XcodeSwitchTestPlan` | Core ones allowed; `XcodeOpenWorkspace` asks (explicit rule); the rest have no rule |
| Build and test | `BuildProject`, `RunAllTests`, `RunSomeTests`, `GetTestList`, `RenderPreview` | Allowed |
| Debug and diagnostics | `GetBuildLog`, `GetConsoleOutput`, `GetCrashIssueLogs`, `GetFieldPerformanceIssueLogs`, `GetTopCrashIssues`, `GetTopFieldPerformanceIssues`, `XcodeRefreshCodeIssuesInFile`, `InvokeDebuggerCommand` | Build log, console output and file diagnostics allowed; `InvokeDebuggerCommand` asks (explicit rule); the rest have no rule |
| Runtime | `RunProject`, `StopProject`, `RunCodeSnippet`, `DeviceInteraction*` (5 tools) | Ask each time (explicit rule) |

"No rule" means the tool is neither allowed nor denied, so the permission mode decides
whether it prompts; a permissive mode such as `bypassPermissions` can auto-approve it.
Only the explicit `ask` rules prompt in every mode.
| **Structural mutation** | `XcodeNewProject`, `XcodeNewTarget`, `UpdateTargetBuildSetting`, `UpdateFileCompilerFlags`, `AddEntitlement`, `AddInfoPlist`, `LocalizationPlanner`, `XcodeMakeDir`, `XcodeMV`, `XcodeRM`, `XcodeWrite`, `XcodeUpdate`, `StringCatalogEdit` | **Denied** |

`XcodeWrite`, `XcodeUpdate`, `XcodeMV` and `XcodeRM` are denied because they also add,
move or remove entries in the generated project, and because source edits already go through
the normal Edit and Write tools, which the repository's hooks cover.

**The deny list is a point-in-time audit, not a complete list.** The 13 structural tools
above were audited against Xcode 27.0 (27A266a) and its installed MCP server. Apple may add
or rename tools, so the list is not permanently exhaustive. Re-audit after every Xcode
upgrade (see the last section); until a new tool is classified, treat it as mutating.

**Enforcement.**

- **Claude Code: repository-configured.** `.claude/settings.json` denies the 13 structural
  tools (`permissions.deny`). A deny rule wins over any allow and holds in every permission
  mode. This is the policy that was tested.
- **Codex: not repository-enforced.** The committed `.codex/config.toml` does not define the
  `xcode-tools` server (it lives in each user's local config), so nothing committed here
  restricts Codex. `disabled_tools` below is a local, unverified suggestion: the key was not
  tested against Codex, and each user has to add it themselves.
- **Other MCP clients** are not constrained by Claude's deny rules.
- Runtime and debug tools (`RunProject`, `StopProject`, `RunCodeSnippet`,
  `InvokeDebuggerCommand`, `DeviceInteraction*`) and `XcodeOpenWorkspace` are listed in
  `permissions.ask`. Claude Code treats a tool matched by an explicit ask rule as an action
  no permission mode auto-approves, so these prompt in every mode, including
  `bypassPermissions`. This is a separate policy from structural mutation: they are
  approved per use, not denied. (Taken from the Claude Code permission docs; not exercised
  under `bypassPermissions` here.)
- `XcodeOpenWorkspace` asks because Xcode's folder approval is per user and can cover a
  parent directory; the approval here (`xcrun mcp-server status`) is this checkout only.

```toml
[mcp_servers.xcode-tools]
command = "xcrun"
args = ["mcpbridge"]
disabled_tools = [
    "XcodeNewProject", "XcodeNewTarget", "UpdateTargetBuildSetting", "UpdateFileCompilerFlags",
    "AddEntitlement", "AddInfoPlist", "LocalizationPlanner", "XcodeMakeDir", "XcodeMV",
    "XcodeRM", "XcodeWrite", "XcodeUpdate", "StringCatalogEdit",
]
```

## One-time setup and approvals

- `sudo xcrun mcp-server enable` turns headless mode on. Never use
  `--unsafe-always-allow-all-agents`.
- The first `XcodeOpenWorkspace` shows a dialog approving the agent and the project folder.
  `xcrun mcp-server status` lists what is approved. Revoke with
  `sudo xcrun mcp-server clear-permissions` (or `deny <id>`).

## Deliberate structural experiments

The default is that structural editing through MCP is denied, and agents working in this
repository must not do it. A session started inside the checkout, including any directory
under it such as `build/`, loads this repository's `.claude/settings.json` and `AGENTS.md`,
so the deny rules apply there too. A person who wants to try one on purpose uses a copy
**outside the checkout** and an MCP client or session that does not load this repository's
policy:

1. Copy the repository without `.claude/`, `.git` and `NotchSuite.xcodeproj` into a
   directory outside the checkout (for example under `mktemp -d`).
2. Run `xcodegen generate` there. Opening it needs its own Xcode folder approval (the
   dialog on the first `XcodeOpenWorkspace`), because the copy is outside the approved
   folder.
3. From that separate client or session, use the structural tools on the copy only. Delete
   the copy afterwards and revoke its approval with `sudo xcrun mcp-server deny <id>`.

Pass `projectPath: "NotchSuite.xcodeproj"` to `XcodeNewTarget`; the root package counts as a
second project. Whatever you learn goes into `project.yml`, then regenerate.

## Re-audit after an Xcode update

A new Xcode can add tools. List the server's tools and compare with the table above:

The script waits for each response before it sends the next message, as the MCP lifecycle
requires: `initialize`, its response, `notifications/initialized`, then `tools/list`.

```sh
python3 - <<'EOF'
import json, subprocess, sys

p = subprocess.Popen(["xcrun", "mcpbridge"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=subprocess.DEVNULL, text=True)

def send(m):
    p.stdin.write(json.dumps(m) + "\n")
    p.stdin.flush()

def reply(id):
    for line in p.stdout:
        try:
            m = json.loads(line)
        except ValueError:
            continue
        if m.get("id") == id:
            return m
    sys.exit("server closed before replying to request %s" % id)

send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
    "protocolVersion": "2025-03-26", "capabilities": {},
    "clientInfo": {"name": "audit", "version": "0"}}})
reply(1)
send({"jsonrpc": "2.0", "method": "notifications/initialized"})
send({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
r = reply(2)
if "result" not in r:
    sys.exit("tools/list failed: %s" % r.get("error"))
print("\n".join(sorted(t["name"] for t in r["result"]["tools"])))
p.stdin.close()
p.terminate()
EOF
```

Any tool not in the table is unclassified; treat it as mutating until its description
says otherwise, and deny it.
