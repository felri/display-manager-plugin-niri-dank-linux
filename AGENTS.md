# AGENTS.md — Display Manager Plugin for DMS + Niri

## What This Project Is

A **DankMaterialShell (DMS)** plugin that runs as a bar widget, providing control over Niri Wayland compositor displays. It lets users:

- Toggle displays on/off via `niri msg output <name> {enable,disable}`
- Change resolution and refresh rate via `niri msg output <name> mode <W>x<H>@<Hz>`
- Adjust output scale via `niri msg output <name> scale <float>`
- Control **hardware** brightness and contrast via `ddcutil setvcp`
- Optionally cycle the output (`off` → `on`) before a mode change, as a workaround for
  panels that intermittently fail to lock their DisplayPort link after a rate change

The plugin is a **single QML file** (`DisplayManager.qml`) that Quickshell/DMS loads at runtime. There is no build step.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | Qt Quick / QML (Quickshell framework) |
| Host Shell | [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) |
| Compositor IPC | `niri msg --json outputs` and `niri msg output ...` |
| DDC/CI | `ddcutil` (I²C hardware control) |
| Package | `plugin.json` manifest |

## File Structure

```
.
├── DisplayManager.qml   # Entire plugin (UI + logic, ~875 lines)
├── plugin.json          # DMS plugin manifest
├── assets/
│   └── screenshot.png   # Screenshot for the registry listing
├── README.md            # User-facing docs
├── LICENSE              # Apache 2.0
└── AGENTS.md            # This file
```

## How It Works

1. **Initialization** (`Component.onCompleted` → `refreshMonitors()`): Parses `niri msg --json outputs` to discover connected monitors, their current modes, brightness/contrast values (via `ddcutil getvcp`), and available display modes.
2. **Pill UI**: Each monitor gets a horizontal bar with:
   - Enable/disable toggle
   - Resolution dropdown (ComboBox with themed popup)
   - Scale radio buttons
   - Brightness and contrast sliders
3. **Actions**: When a user changes a setting, the plugin executes the appropriate `niri msg` or `ddcutil` command via `Quickshell.execDetached(["sh", "-c", cmd])`.
4. **Forced link re-init** (optional, per monitor, `reinit_<connector>` plugin setting): when
   enabled, `applyMode()` runs `off` → 1.2 s → `on` → 0.9 s → `mode` instead of a single
   `mode` call, and re-applies the target mode afterwards. Note the side effect: disabling an
   output removes it from Xwayland, which crashes Steam/GTK clients.
5. **Settings persistence**: Brightness, contrast and the re-init flag are saved via `pluginService.savePluginData("displayManager", key, value)` and restored on next load.

## Known panel quirk (context for the workaround)

From investigating a `WAM SFUCW-27300` 1080p/300 Hz panel (2026-09) on `nvidia-open` 610/615
with Niri plus two 60 Hz monitors:

- Switching that monitor from 60 Hz to a high rate fails to lock the DisplayPort link roughly
  **1 in 3** times: black screen or noise, while `card1-DP-1/status` stays `connected`,
  `dpms=On`, DDC/CI keeps answering and the driver logs nothing (no NVRM/Xid entry).
- Any link re-init fixes it, which is why replugging the cable worked. `niri msg output X off`
  + `on` is the software equivalent (verified: picture returns, same mode re-picked).
- The 300 Hz mode is synthesised by the driver from the EDID range limits (48–300 Hz, max
  dotclock 720 MHz) and needs 702 MHz — 97.5% of that ceiling. 280 Hz is likewise not in the
  EDID; 60/120/165/200/240 are.
- Disabling the output removes it from Xwayland → `steam` segfaults in
  `libgdk-x11-2.0.so.0` within ~1 s (reproduced twice), and empty workspace IDs on that output
  can be renumbered. Plain rate changes (no output removal) do **not** crash it.
- Recovery ladder, least destructive first: plain 60→target mode change → DPMS cycle
  (`niri msg action power-off-monitors` / `power-on-monitors`) → output off/on → cable.

## How to Update the Plugin

### 1. Update the source code in this repo

Make your changes to `DisplayManager.qml`, increment the version in `plugin.json`, commit, and push:

```bash
git add DisplayManager.qml plugin.json
git commit -m "fix: theme ComboBox popup background to follow dark mode"
git push
```

### 2. Update the DMS Plugin Registry (only if metadata changed)

The DMS plugin registry at [AvengeMedia/dms-plugin-registry](https://github.com/AvengeMedia/dms-plugin-registry) has an entry for this plugin at:

```
plugins/felri-display-manager-niri.json
```

**You only need to update the registry entry if** the plugin's metadata changed (description, dependencies, capabilities, screenshot URL, etc.). Source code changes in this repo are picked up automatically because the registry points to this repo's `plugin.json` and the DMS installer clones/pulls from the latest.

If metadata changed, fork the registry repo, update the JSON file, and submit a Pull Request.

### 3. Users install the update

Users who already have the plugin installed can update via:

```
dms plugins update displayManager
```

Or reinstall via the DMS Settings UI → Plugins tab.

## Publishing a New Plugin to the Registry

If you were publishing this for the first time (already done):

1. Ensure `plugin.json` in this repo is correct
2. Fork [AvengeMedia/dms-plugin-registry](https://github.com/AvengeMedia/dms-plugin-registry)
3. Create `plugins/{github-username}-{plugin-name}.json` with required fields (see the registry's [CONTRIBUTING.md](https://raw.githubusercontent.com/AvengeMedia/dms-plugin-registry/master/CONTRIBUTING.md))
4. Run validation: `python3 .github/generate.py --validate && python3 .github/validate_links.py`
5. Submit a PR

## Development Notes

- The plugin uses **Material Design 3 color roles** from the DMS `Theme` singleton (e.g. `Theme.surfaceText`, `Theme.surfaceContainerHighest`). Never hardcode colors — always use theme properties so dark/light mode works automatically.
- Qt Quick Controls 2.15 `ComboBox` popups need explicit theming via the `popup` property, otherwise they default to the system palette.
- `ddcutil` requires I²C permissions. Users need to be in the `i2c` group or have a udev rule.
- The plugin requires the `process` permission (`plugin.json`) to execute shell commands.
- Brightness/contrast use `--noverify` flag on `ddcutil` for speed, at the cost of not verifying the value was actually set.
- Local testing loop: edit here, copy into `~/.config/DankMaterialShell/plugins/displayManagerNiri/`
  (that directory is its own checkout of this repo), then reload without restarting the shell:

  ```bash
  cp DisplayManager.qml plugin.json ~/.config/DankMaterialShell/plugins/displayManagerNiri/
  dms ipc call plugins reload displayManager     # → PLUGIN_RELOAD_SUCCESS: displayManager
  ```

  QML errors surface in the journal (`journalctl -f | grep qml`). `qmllint DisplayManager.qml`
  parses the file standalone (the `qs.*` imports stay unresolved, but syntax errors show up).
