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
