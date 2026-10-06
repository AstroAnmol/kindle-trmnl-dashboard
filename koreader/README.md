# 📖 KOReader Kindle Dashboard Integration

Turn your jailbroken **Amazon Kindle (WP63GW - 7th Gen Basic, firmware 5.12.2.2)** running **KOReader** into a dedicated, low-power ambient smart display compatible with the TRMNL protocol.

---

## 🌟 Why KOReader?

* **Bypasses Amazon Lockscreen Ads:** Even if your Kindle has Amazon "Special Offers", KOReader controls the e-ink screen directly and renders your dashboard as the sleep wallpaper.
* **100% Full-Screen (Edge-to-Edge):** Native 600×800 e-ink display without browser URL bars, menus, or notification bars.
* **Active Sleep Background Refresh:** Uses Kindle's hardware RTC alarms (`Device.wakeup_mgr`) to wake up periodically (e.g. every 15 minutes), connect to Wi-Fi, download the latest dashboard image, refresh the screen, and return to sleep.
* **On-Screen Configuration & Testing:** Includes an instant **"Update & Display on Screen Now"** action so you can test rendering without putting the Kindle to sleep.
* **Safe User-Space Operation:** Runs entirely from `/mnt/us/koreader/plugins/dashboard.koplugin` without modifying rootfs system partitions.
* **Battery Reporting:** Reads battery percentage and charging status and sends them to the server on every refresh.

---

## 🚀 Installation

### Option A: Using the Automated Installer (Recommended)
1. Plug your Kindle into your computer via USB (ensure it mounts as a drive, e.g., `/Volumes/Kindle` on macOS).
2. Run:
   ```bash
   cd koreader
   ./install.sh
   ```
   Select **Option 1 (USB Cable)** and press Enter. The installer will also remove any older `trmnl.koplugin` folder to avoid conflicts.
3. Safely Eject and unplug your Kindle.

### Option B: Manual Installation via USB
1. Connect your Kindle to your computer via USB.
2. Open your Kindle drive.
3. Remove old `koreader/plugins/trmnl.koplugin` if present.
4. Copy `koreader/plugins/dashboard.koplugin` to:
   ```
   <Kindle>/koreader/plugins/dashboard.koplugin
   ```
5. Safely Eject and unplug your Kindle.

### Option C: Over Wi-Fi via SSH / SCP
```bash
cd koreader
./install.sh
```
Select **Option 2 (Wi-Fi / SSH)** and enter your Kindle's IP address.

---

## 📱 How to Use on Your Kindle

1. Open **KOReader** on your Kindle (or exit and restart it if it was open).
2. Tap the **top menu bar** (or swipe down from the top edge).
3. Tap the **Tools** icon (screwdriver/wrench).
4. Tap **Kindle Dashboard**:
   * **Update & Display on Screen Now:** Tap to immediately download and paint the dashboard directly to your e-ink screen!
   * **Change Server URL:** Tap and enter your server's image endpoint:
     ```
     http://<your-server-ip>:5055/api/display/image
     ```
   * **Periodic Refresh (Active Sleep):** Choose your preferred update frequency (e.g. *Every 15 minutes*).
   * **Device Diagnostics:** Check live battery %, charging state, and paths.
5. Press the physical **Power button** once to put your Kindle to sleep.
6. Your 600×800 dashboard will display edge-to-edge on the e-ink screen and update automatically in the background!
