# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```sh
swift build                    # debug build
swift build -c release         # release build
swift test                     # run Swift XCTest tests
python3 -m pytest Tests/PluginTests/ -v   # run Python plugin tests
bash scripts/build.sh          # full app bundle: build + sign + launch
```

## Architecture

macOS menu bar app (SwiftUI + AppKit) that aggregates AI service usage quotas via external Python scripts.

### Two-layer design

- **UsageBoardApp** (SwiftUI + AppKit): AppDelegate (status item, popover, settings window), UsageBoardStore (@MainActor ObservableObject), Views, DesignSystem, AppLocalization
- **UsageBoardCore** (Foundation only): Models (AppConfiguration, PluginMetadata, PluginOutput, UsageItem, etc.), ConfigStore, PluginExecutor, PluginMetadataParser, PluginStateStore, BundledPluginInstaller, UpdateChecker

Dependency: `UsageBoardApp → UsageBoardCore` (strict, no reverse deps)

### Plugin system

All usage query logic lives in external Python scripts. The app runs them as child processes and parses stdout JSON.

- Python plugins live in `Resources/BundledPlugins/` with `_common.py` shared module
- Plugins declare metadata in a JSON comment block (`# UsageBoardPlugin: { ... } # /UsageBoardPlugin`)
- Plugin stdout JSON format: `{ "updatedAt", "items": [{ id, name, used, limit, displayStyle, resetAt, status, color }], "badge", "chart" }`
- `displayStyle`: "ratio" (used/limit) or "percent" (percentage bar)
- Colors: blue/yellow/orange/red. Status: normal/warning/critical
- Config stored at `~/Library/Application Support/UsageBoard/config.json`
- Plugin scripts are symlinked from app bundle to the support directory

### Key patterns

- Strict Swift 6 concurrency: `@MainActor` on UsageBoardStore and AppDelegate, `Sendable` on models
- ConfigStore uses atomic file writes (write to temp, rename)
- PluginStateStore: two-level cache (in-memory NSLock dictionary + disk JSON files)
- PluginExecutor: 15s timeout, async stdout reader with DataBuffer (prevents pipe deadlocks)
- i18n: bilingual (zh-Hans/en), selected via `AppleLanguages` preference key
- Zero external dependencies (Foundation, SwiftUI, AppKit only)

### Plugin authoring

To add a new plugin:
1. Create `.py` in `Resources/BundledPlugins/` with metadata comment block
2. Use `from _common import ...` for shared utilities
3. Accept `--usageboard-param K=V` CLI args via `parse_usageboard_params()`
4. Output JSON to stdout via `success(items, badge, chart)` or `failure(message)`
