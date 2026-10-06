# 📟 Kindle Online Screensaver Setup (WP63GW & KUAL)

This client extension turns your jailbroken **Amazon Kindle (WP63GW - 7th Gen Basic / KT2)** into an always-on, ambient smart e-ink dashboard using the **Online Screensaver** architecture.

---

## 🌟 Why this approach works reliably

* **100% Fullscreen (Edge-to-Edge):** The dashboard renders in native screensaver mode without browser top bars or menus.
* **4 to 8 Weeks Battery Life:** The Kindle stays in hardware deep-sleep (`echo mem > /sys/power/state`). It only powers up Wi-Fi for ~5–8 seconds to download new content, then suspends back into deep sleep using RTC hardware alarms.
* **No `lab126_gui` Killing:** Older scripts tried to kill Amazon's window manager (`stop lab126_gui`), which broke Wi-Fi and caused watchdog crashes. This solution runs cooperatively with Kindle OS `powerd`.
* **Zero FAT32 Filesystem Corruption:** The scheduler executes out of RAM (`/tmp/`), so plugging in USB never causes drive corruption.
* **ETag 304 Caching:** If no calendar events or weather items changed, the server returns `304 Not Modified`. The Kindle immediately goes back to sleep without redrawing, eliminating unnecessary e-ink flashing and saving battery.
* **Automatic Battery Telemetry:** Every refresh reports battery percentage and charging status to the server, displaying it directly on your dashboard.
* **NiLuJe `linkss` Optional:** Uses the Kindle's built-in Linux e-ink utility `/usr/sbin/eips` to paint directly to the display while in screensaver. It works whether or not you have NiLuJe's `linkss` hack installed!

---

## 📦 Installation Options

### Method 1: USB Cable (Easiest)

1. Connect your Kindle to your computer using a USB cable.
2. Ensure the Kindle drive mounts on your computer (e.g. `/Volumes/Kindle` on macOS).
3. From your computer's terminal, run:
   ```bash
   cd kindle
   ./install.sh
   ```
   *(Select Option 1 and press Enter. It will copy the extension folder to `extensions/onlinescreensaver` on your Kindle).*
4. Safely **Eject** the Kindle drive and unplug the USB cable.

### Method 2: Wi-Fi / SSH (Over the Network)

If your Kindle has USBNetwork / SSH enabled:
```bash
# Copy extension to Kindle
scp -r kindle/extensions/onlinescreensaver root@<kindle-ip>:/mnt/us/extensions/

# Set permissions
ssh root@<kindle-ip> "chmod +x /mnt/us/extensions/onlinescreensaver/bin/*.sh"
```

---

## 🚀 Activating on Your Kindle

1. On your Kindle, open **KUAL** from your book library.
2. Tap **Online Screensaver**.
3. Tap **Enable auto-download**.
   * *This registers the background Upstart service and arms the RTC scheduler.*
4. Tap **Update now** to trigger an immediate fetch and verify connectivity.
5. Put your Kindle to sleep (press the power button once). The dashboard will display full-screen!

---

## ⚙️ Configuration (`extensions/onlinescreensaver/bin/config.sh`)

All settings can be customized in `bin/config.sh` on your Kindle:

| Setting | Default | Description |
| :--- | :--- | :--- |
| `IMAGE_URI` | `http://10.0.0.219:5055/api/display/image` | The server image endpoint |
| `DEFAULTINTERVAL` | `15` | Refresh interval in minutes |
| `SCHEDULE` | `00:00-07:00=60 07:00-22:00=15 22:00-24:00=30` | Time-of-day update intervals |
| `DISABLE_WIFI` | `1` | Powers off Wi-Fi radio between refreshes (huge battery saver) |
| `WRITE_SCREENSAVER` | `0` | `0` = paint directly with `eips`; `1` = also save to `linkss/screensavers/bg_ss00.png` |
| `TEST_DOMAIN` | `10.0.0.219` | Target IP used to verify network connectivity |

---

## 🛠️ Menu Options in KUAL

* **Update now:** Immediately turns on Wi-Fi, fetches the latest image from the server, and redraws the screen.
* **Enable auto-download:** Enables and starts the background sleep/wake update loop.
* **Disable auto-download:** Disables the loop and clears the RTC wakeup alarm.
* **Restart auto-download:** Restarts the service (useful after editing `config.sh`).
