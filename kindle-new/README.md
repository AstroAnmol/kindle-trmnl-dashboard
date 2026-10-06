# Kindle TRMNL Dashboard (v2 - Native Engine)

A clean, robust client for running the TRMNL dashboard on a jailbroken Kindle (specifically Kindle 7th Gen KT2 / WP63GW on firmware 5.x) based on the proven architecture from [dashink](https://github.com/dietrichmax/dashink).

---

## ⚡ Key Improvements over v1

1. **Native `eips` Framebuffer Rendering**: No external dependencies or complicated binary compilation needed. Directly renders the raw PNG from your Docker server (`/api/display/image`).
2. **Proper `lab126_gui` Management**:
   - Cleanly stops the Kindle reader UI with `stop lab126_gui` to prevent UI redraw conflicts.
   - Restores smoothly with `restore.sh` or KUAL's **Stop Dashboard Loop** (`start lab126_gui`).
3. **Hardware Escape Hatch (Touch / Power Button)**:
   - When the dashboard is running on your wall, **touching the screen** or **pressing the power button** reads directly from `/dev/input/event*` and automatically runs `restore.sh`, restoring the Kindle reader UI and KUAL.
4. **Safe Status & Diagnostics**:
   - "Status & Diagnostics" runs *without* stopping the Kindle UI. It tests Wi-Fi, battery, ping/curl to your server, and paints a test frame on the screen.
5. **No Aggressive Wi-Fi Cycling**:
   - Keeps connection stable using `ensureConnection wifi` instead of abruptly disabling Wi-Fi chips that can hang the Kindle kernel.

---

## 📂 File Structure

```text
kindle-new/
├── trmnl.conf              <-- Configuration file (Server URL, interval, etc.)
├── trmnl.sh                <-- Main dashboard display loop
├── restore.sh              <-- Restores reader UI (start lab126_gui)
├── info.sh                 <-- Safe diagnostic and test script
├── README.md               <-- This guide
└── extensions/
    └── kindle-trmnl/       <-- KUAL extension folder
        ├── config.xml
        ├── menu.json
        └── bin/
            ├── start.sh    <-- KUAL: Start Dashboard Loop
            ├── stop.sh     <-- KUAL: Stop Dashboard Loop
            ├── once.sh     <-- KUAL: Refresh Screen Once
            └── status.sh   <-- KUAL: Status & Diagnostics
```

---

## 🚀 Installation & Deployment

### Step 1: Connect Kindle via USB
Connect your jailbroken Kindle to your computer via USB cable. It will mount as an external drive (referred to as `/mnt/us` internally).

### Step 2: Copy the Files
1. Copy the core scripts directly to the root of your Kindle drive:
   - `trmnl.conf`
   - `trmnl.sh`
   - `restore.sh`
   - `info.sh`
2. Copy the `kindle-trmnl` folder from `extensions/` into the `extensions/` folder on your Kindle:
   - Target path: `extensions/kindle-trmnl/`

> **Note for Hotfix users**: If you prefer tapping scripts directly from your Kindle Library (via Hotfix `sh_integration`), you can also copy `info.sh`, `trmnl.sh`, and `restore.sh` into your `documents/` folder.

### Step 3: Configure `trmnl.conf`
Open `trmnl.conf` on your Kindle root using any text editor. Ensure your server URL is correct:

```sh
# URL serving the raw PNG image
DASHBOARD_URL="http://10.0.0.219:5055/api/display/image"

# Refresh interval in seconds (900 = 15 minutes, 300 = 5 minutes)
INTERVAL=900

# Full screen clear every N cycles to prevent e-ink ghosting
FULL_REFRESH_EVERY=12

# Minimum battery percentage to run the loop
LOW_BATTERY_THRESHOLD=10

# Hardware escape hatch (touch screen or power button to exit)
ENABLE_ESCAPE_HATCH=1
```

Eject and unplug the USB cable from the Kindle.

---

## 📱 How to Use in KUAL

Open **KUAL** from your Kindle library. You will see the **Kindle TRMNL** menu with 4 options:

### 1. `Status & Diagnostics`
- **What it does:** Tests Wi-Fi connection, reports device model, IP address, battery percentage, checks connectivity to `http://10.0.0.219:5055/api/display/image`, and paints a test frame on screen.
- **Safety:** Does NOT stop the reader UI. You can run this anytime to verify network reachability.

### 2. `Refresh Screen Once`
- **What it does:** Downloads the latest dashboard image and displays it on the screen immediately.
- **Safety:** Leaves the reader UI active in the background. Touching the screen will return straight back to KUAL.

### 3. `Start Dashboard Loop`
- **What it does:** Starts the continuous wall dashboard loop.
- It stops `lab126_gui`, prevents screensaver timeout, downloads the dashboard image, and paints it using `eips -g`.
- It repeats every `INTERVAL` seconds (default 15 minutes).

### 4. `Stop Dashboard Loop`
- **What it does:** Kills the loop process, cleans up temporary files, re-enables the screensaver, and restarts `lab126_gui`, bringing your normal Kindle interface back.

---

## 🚪 Escape Hatch (Exiting the Dashboard)

If the dashboard loop is active on your screen:
1. **Touch the screen** or **press the power button once**:
   - The background input monitor automatically detects the input event from the Linux kernel and executes `restore.sh`.
2. **Via SSH** (if connected):
   - Run `sh /mnt/us/restore.sh`
3. **Hard Reboot** (fallback only):
   - Hold the power button down for 20 seconds.
