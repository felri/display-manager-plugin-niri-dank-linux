# Monitor Control for DMS

<img width="692" height="632" alt="Screenshot from 2025-12-24 14-22-26" src="https://github.com/user-attachments/assets/a7dc5fc8-3d34-47bd-b118-aae94c62467f" />


A **DankMaterialShell (DMS)** plugin that lets you:

- Toggle **Niri** displays on/off  
- Control **hardware monitor brightness** via DDC/CI  

Designed to be lightweight, fast, and bar-friendly.

---

## Requirements

### Brightness Control (DDC/CI)

To control monitor brightness, you need `ddcutil` and access to the I2C interface.

```bash
sudo pacman -S ddcutil
sudo usermod -aG i2c $USER
