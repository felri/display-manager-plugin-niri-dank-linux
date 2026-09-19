# Display Manager for DMS and Niri


<img width="638" height="926" alt="Screenshot from 2025-12-24 20-09-22" src="https://github.com/user-attachments/assets/5603ecb0-b8f0-4278-9360-6e895a5109e9" />


A **DankMaterialShell (DMS)** plugin that lets you:

- Toggle **Niri** displays on/off  
- Control hardware monitor brightness, constrast via DDC/CI
- Control resolution and refresh rate

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
| Brightness / Contrast sliders | Hardware values via DDC/CI (`ddcutil setvcp 10` / `12`) |

Brightness and contrast are stored per connector name in the DMS plugin settings.

---

## Known issue: black screen or noise after a refresh-rate change

Reported on a `WAM SFUCW-27300` 1080p/300 Hz panel (EDID 1.4, NVIDIA open driver
610/615, Niri, two other monitors at 60 Hz): switching that monitor from 60 Hz to a high
rate intermittently leaves it black or full of noise — roughly **1 in 3** times. While it
is black, everything else looks healthy:

- `niri msg outputs` still reports the output active at the requested mode
- `/sys/class/drm/*-DP-1/{status,enabled,dpms}` = `connected` / `enabled` / `On`
- `ddcutil` still talks to the monitor (brightness reads back)
- the kernel and the driver log nothing — no NVRM message, no Xid

That panel declares 60/120/165/200/240 Hz in its EDID and runs the 280/300 Hz modes at
97.5% of the maximum dotclock it reports (702 MHz of 720 MHz), so the driver's synthesised
high rates sit right at the panel's ceiling.

### What was tried and did **not** help

Cycling the output (`niri msg output <name> off` → `on` → mode) before applying the new
rate, i.e. forcing a DisplayPort link re-init. Logged sequence on a failing attempt:

```
1/3 output off      -> niri: disconnecting connector
2/3 output on       -> niri: connecting connector, picks 60 Hz (panel fine)
3/3 mode 300 Hz     -> niri: output picking mode  ->  panel black again
```

So the failure is tied to those modes themselves, not to stale link state, and the re-init
does not change the odds. (This workaround shipped in 1.2.0 and was removed in 1.2.1.)

### What does help

1. **Go back to 60 Hz** with a plain mode change — no output removal, X11 clients unaffected:

   ```bash
   niri msg output DP-1 mode "1920x1080@60.000"
   ```

   Verified to restore the picture from a black-but-enabled state.
2. If that is not enough, escalate: `niri msg action power-off-monitors` + `power-on-monitors`,
   then `niri msg output DP-1 off` + `on` (this one removes the X11 output — see below),
   then the cable.
3. Consider a rate the panel actually declares (240 Hz) instead of the synthesised 280/300 Hz.

### Caveat: disabling an output breaks X11 clients

`niri msg output <name> off` (and unplugging the cable) removes that output from Xwayland.
Steam segfaults in `libgdk-x11-2.0.so.0` within about a second of that happening (reproduced
twice, with a backtrace uploaded by Steam's crash handler), and empty workspace IDs on the
output can be renumbered. Plain mode changes do not trigger this — prefer them for recovery.
