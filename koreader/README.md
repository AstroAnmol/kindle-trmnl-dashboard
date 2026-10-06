# 📖 KOReader TRMNL Dashboard Integration

Display your self-hosted e-ink dashboard (`http://10.0.0.219:5055/api/display/image`) as your **KOReader sleep screen wallpaper** with **Active Sleep periodic background refresh**.

---

## 🌟 Key Features
1. **Periodic Active Sleep:** The Kindle wakes up in the background on an RTC timer (every 10, 15, 30, or 60 min), connects to Wi-Fi, downloads the new image, updates the screensaver, and sleeps again.
2. **Auto-update on Sleep:** Automatically fetches fresh data right when you press the power button to lock the device.
3. **Bypasses Amazon Lockscreen Ads:** Even if your Kindle has "Special Offers" (lockscreen ads enabled), KOReader has full control of the display and renders its own custom wallpapers.
4. **Zero Amazon Rootfs / Upstart Hassles:** Runs entirely in user-space (`/mnt/us/koreader/`).
5. **On-Screen KOReader Menu:** Configure refresh intervals, update on demand, view fullscreen, or change the server URL directly inside KOReader.

---

## 🚀 Easy Installation

### Option A: Automatic Installer (USB Cable or Wi-Fi)
Connect your Kindle via USB and run:
```bash
cd koreader
./install.sh
```
Follow the prompt (select Option 1 for USB or Option 2 for SSH/Wi-Fi).

### Option B: Manual Copy via USB
1. Plug your Kindle into your computer.
2. Copy the `koreader/plugins/trmnl.koplugin` folder to:
   ```
   Kindle/koreader/plugins/trmnl.koplugin
   ```
3. Safely eject and unplug your Kindle.

---

## 📱 How to Use in KOReader

1. Open **KOReader** on your Kindle.
2. Tap the **top menu bar** (or swipe down from the top).
3. Tap the **Tools** icon (screwdriver/wrench).
4. Tap **TRMNL Dashboard**:
   * Tap **Update Dashboard Now** — KOReader will download the latest dashboard image from `http://10.0.0.219:5055/api/display/image` and save it.
   * Tap **Periodic Refresh (Active Sleep)** — select your desired interval (e.g. *Every 15 minutes*).
   * Ensure **Auto-update on Sleep** is checked.
5. Press the physical power button on your Kindle. Your dashboard will appear full-screen on the e-ink display and refresh periodically in the background!
