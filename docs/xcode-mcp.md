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
3. Open the result through MCP: `XcodeOpenWorkspace` on `NotchSuite.xcodeproj`. Xcode.app
   does not need to be open.
4. Build, test and inspect through MCP (`BuildProject`, `XcodeSwitchScheme` to
   `NotchSuiteTests` then `RunAllTests`, `GetBuildLog`, …) or through the repository
   scripts (`./script/verify.sh`, `./script/build_and_run.sh --build-only`).
5. CI regenerates the project from `project.yml` on its own and builds with `xcodebuild`.
   **CI never depends on the MCP service.**

MCP builds use Xcode's default DerivedData, not `build/DerivedData`.

## What agents may use

The server exposes 54 tools. The repository allows or denies them like this:

| Class | Tools | Policy |
|---|---|---|
| Read and session | `GetFileCompilerFlags`, `GetTargetBuildSettings`, `DocumentationSearch`, `XcodeGlob`, `XcodeGrep`, `XcodeLS`, `XcodeRead`, `XcodeListRunDestinations`, `XcodeListSchemes`, `XcodeListTargets`, `XcodeListTemplates`, `XcodeListTestPlans`, `XcodeListWorkspaces`, `StringCatalogRead`, `StringCatalogContext`, `XcodeOpenWorkspace`, `XcodeCloseWorkspace`, `XcodeSwitchScheme`, `XcodeSwitchRunDestination`, `XcodeSwitchTestPlan` | Core ones allowed; the rest ask |
| Build and test | `BuildProject`, `RunAllTests`, `RunSomeTests`, `GetTestList`, `RenderPreview` | Allowed |
| Debug and diagnostics | `GetBuildLog`, `GetConsoleOutput`, `GetCrashIssueLogs`, `GetFieldPerformanceIssueLogs`, `GetTopCrashIssues`, `GetTopFieldPerformanceIssues`, `XcodeRefreshCodeIssuesInFile`, `InvokeDebuggerCommand` | Build log, console output and file diagnostics allowed; the rest ask |
| Runtime | `RunProject`, `StopProject`, `RunCodeSnippet`, `DeviceInteraction*` (5 tools) | Ask each time |
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
- Runtime tools (`RunProject`, `RunCodeSnippet`, `DeviceInteraction*`, `InvokeDebuggerCommand`)
  are a separate policy from structural mutation: they ask each time and are not denied.

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

The default is that structural editing through MCP is denied. To try one on purpose, do it
in a scratch copy, never in the real checkout:

1. Copy the repository without `.claude/`, `.git` and `NotchSuite.xcodeproj` into
   `build/mcp-scratch/` (`build/` is gitignored and inside the approved folder).
2. Run `xcodegen generate` there, then `XcodeOpenWorkspace` on the copy.
3. Use the structural tools on that copy only, and delete it afterwards.

Pass `projectPath: "NotchSuite.xcodeproj"` to `XcodeNewTarget`; the root package counts as a
second project. Whatever you learn goes into `project.yml`, then regenerate.

## Re-audit after an Xcode update

A new Xcode can add tools. List the server's tools and compare with the table above:

```sh
{ printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"audit","version":"0"}}}' '{"jsonrpc":"2.0","method":"notifications/initialized"}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'; sleep 3; } \
  | xcrun mcpbridge 2>/dev/null | jq -r 'select(.id==2) | .result.tools[].name' | sort
```

Any tool not in the table is unclassified; treat it as mutating until its description
says otherwise, and deny it.
