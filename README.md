# Display Manager for DMS and Niri


<img width="638" height="926" alt="Screenshot from 2025-12-24 20-09-22" src="https://github.com/user-attachments/assets/5603ecb0-b8f0-4278-9360-6e895a5109e9" />


A **DankMaterialShell (DMS)** plugin that lets you:

- Toggle **Niri** displays on/off  
- Control hardware monitor brightness, constrast via DDC/CI
- Control resolution and refresh rate
- Optionally force a DisplayPort link re-init before a rate change (workaround for
  panels that intermittently fail to lock at high refresh rates)

Designed to be lightweight, fast, and bar-friendly.

---

## Requirements

### Brightness Control (DDC/CI)

To control monitor brightness, you need `ddcutil` and access to the I2C interface.

```bash
sudo pacman -S ddcutil
sudo usermod -aG i2c $USER
```

---

## Usage

Click the bar pill to open the display list. Each monitor card has:

| Control | Action |
| --- | --- |
| Power toggle (right) | Enable/disable the output (`niri msg output <name> on/off`) |
| Scale `-` / `+` | Output scale, 0.5 – 3.0 |
| Resolution dropdown | Resolution, keeping the current refresh rate when available |
| Refresh rate dropdown | Refresh rate for the selected resolution |
| ⟳ button | Forced link re-init before the next mode change (see below) |
| Brightness / Contrast sliders | Hardware values via DDC/CI (`ddcutil setvcp 10` / `12`) |

Brightness, contrast, and the re-init flag are stored per connector name in the DMS
plugin settings (`reinit_<connector>`, default `false`).

---

## Forced link re-init (workaround)

Some panels intermittently fail to lock their DisplayPort main link when the refresh rate
changes: the screen goes black or fills with noise, while the connector still reports as
connected and DDC/CI keeps answering. Only unplugging the cable brought it back.

Enabling the ⟳ button next to the refresh rate dropdown makes the next mode change on that
monitor run as:

```bash
niri msg output <name> off
sleep 1.2
niri msg output <name> on      # link is torn down and retrained
sleep 0.9
niri msg output <name> mode <W>x<H>@<Hz>
```

The cycle retrains the link, which is what replugging the cable did.

**Off by default.** With the button off, the plugin runs exactly one command per change
(`niri msg output <name> mode ...`), as before.

### Caveats

- The panel blanks for ~2 seconds while the output is cycled.
- Disabling an output removes it from Xwayland. **This crashes Steam and other GTK/X11
  clients** (observed as `segfault ... in libgdk-x11-2.0.so.0` right after the output is
  removed) and can re-arrange windows/workspaces. Enabling this while a game or Steam is
  open is not recommended.
- It is a workaround, not a fix: the underlying failure is intermittent (~1 in 3 rate
  changes on the affected panel), and the cycle only makes the transition more likely to
  take.

### If the screen already went black

Try the cheapest recovery first, from another monitor or over SSH:

```bash
# 1. plain mode changes - no output removal, X11 clients unaffected
niri msg output DP-1 mode "1920x1080@60.000"; sleep 1
niri msg output DP-1 mode "1920x1080@300.000"

# 2. DPMS cycle on all monitors - no output removal
niri msg action power-off-monitors; sleep 2; niri msg action power-on-monitors

# 3. output re-init - same as replugging the cable (may crash Steam/GTK apps)
niri msg output DP-1 off; sleep 2; niri msg output DP-1 on
```

Or, with the ⟳ button enabled, re-select the current refresh rate to force a re-init
without changing rates.
