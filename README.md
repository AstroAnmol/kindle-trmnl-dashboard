# 📟 Kindle TRMNL Dashboard (`kindle-trmnl-dashboard`)

Turn any jailbroken Amazon Kindle into a dedicated, low-power, ambient smart wall display compatible with the **TRMNL** e-ink protocol.

Built with **FastAPI**, **Playwright**, and **Pillow**, this repository delivers a self-hosted dashboard server (containerized via Docker) along with battery-optimized client scripts utilizing NiLuJe's `fbink` for true deep-sleep e-ink rendering.

---

## 🌟 Key Features

* **TRMNL Protocol Compatible:** Implements standard TRMNL endpoints (`/api/setup`, `/api/display`, `/api/log`).
* **Multi-Feed Google Calendar:** Parses multiple private iCal (`.ics`) feeds with accurate **RFC 5545 recurring event expansion** (`recurring-ical-events`).
* **Open-Meteo Weather:** Real-time weather, high/low forecasts, precipitation probability, humidity, and wind—**no API key required**.
* **Markdown & JSON Tasks:** Live checklist with `- [ ]` and `- [x]` markdown support (`config/tasks.md`) or structured JSON.
* **TRMNL Monochrome Aesthetic:** 2px high-contrast borders, clean modular grid (60% agenda/weather, 40% tasks/stats), and crisp SVG icons.
* **1-Bit E-Ink Pipeline:** Hardware-optimized bilevel rendering with optional **Floyd-Steinberg dithering** or clean thresholding in BMP or PNG.
* **Kindle Power Optimization:** Turns on Wi-Fi only for updates (~10 seconds), reports battery & signal telemetry, and suspends to deep RAM sleep (`echo mem > /sys/power/state`) using RTC wake alarms.
* **KUAL Launcher Extension:** Start, stop, refresh, and inspect device diagnostics straight from your Kindle screen.
* **1-Command Docker Deployment:** Multi-stage `Dockerfile` with pre-installed Chromium and system fonts.

---

## 🏛️ System Architecture

```
+-------------------------------------------------------------------------+
|                         Jailbroken Kindle Display                       |
|                                                                         |
|  [RTC Wake Alarm] ──> [Enable Wi-Fi] ──> [Collect Batt % & Signal RSSI] |
|                                                      │                  |
|                                                      ▼                  |
|  [Suspend to Deep Sleep 'mem'] <── [fbink Draw] <── [Fetch /api/display]|
|                                                      ▲                  |
+──────────────────────────────────────────────────────┼──────────────────+
                                                       │ HTTP / Wi-Fi
+──────────────────────────────────────────────────────┼──────────────────+
|                    Home Server (Docker Container :5055)                 |
|                                                      │                  |
|  • /api/log      <── Ingests Battery Telemetry ──────┘                  |
|  • /api/display  ──> Renders E-ink Bitmap Image                         |
|                                                                         |
|  [Data Aggregator]                                                      |
|    ├── Google Calendar (iCal .ics feeds with recurring event expansion) |
|    ├── Open-Meteo API (Current, forecast, humidity, rain probability)   |
|    └── Tasks & Notes (config/tasks.md checklist parser)                 |
|                                                                         |
|  [Rendering Pipeline]                                                   |
|    Jinja2 Template ──> Headless Chromium ──> Pillow 1-Bit / Grayscale    |
+-------------------------------------------------------------------------+
```

---

## 🚀 Quickstart: Server Deployment (Docker)

Deploying to your home server (Raspberry Pi, Unraid, Synology, Proxmox, or Linux server) requires only **Docker** and **Docker Compose**.

### 1. Clone the Repository
```bash
git clone https://github.com/anmol/kindle-trmnl-dashboard.git
cd kindle-trmnl-dashboard
```

### 2. Configure Environment Settings
```bash
cp config/.env.example config/.env
nano config/.env
```

Key environment variables in `config/.env`:
```ini
# E-ink refresh interval in seconds (default: 900 = 15 minutes)
REFRESH_RATE_SECONDS=900

# Viewport dimensions (Kindle 4/5/Touch: 600x800 | Paperwhite 3/4: 1072x1448 | TRMNL: 800x480)
KINDLE_SCREEN_WIDTH=800
KINDLE_SCREEN_HEIGHT=480
SCREEN_ORIENTATION=0

# Image format ('png' or 'bmp') and color mode ('1bit' or '8bit')
IMAGE_FORMAT=png
COLOR_MODE=1bit
DITHERING=true

# Timezone (IANA format)
TIMEZONE=America/New_York

# Google Calendar private iCal URLs (comma-separated for multiple feeds)
ICAL_URLS=https://calendar.google.com/calendar/ical/your_private_feed/basic.ics

# Weather (Open-Meteo - coordinates for your city)
LATITUDE=40.7128
LONGITUDE=-74.0060
LOCATION_NAME=New York
CELSIUS=false
```

### 3. Launch the Container
```bash
docker compose up -d --build
```

### 4. Verify in Your Web Browser
Open your browser to:
- **Interactive Web Preview**: `http://<server-ip>:5055/`
- **Raw Rendered Image**: `http://<server-ip>:5055/api/display`
- **Aggregated JSON Context**: `http://<server-ip>:5055/api/data`
- **Interactive Swagger Docs**: `http://<server-ip>:5055/docs`

---

## 📅 Calendar Setup: Google Calendar iCal Feeds

You do **not** need a Google Cloud API key or OAuth setup to display your calendars. You can use your private iCal link:

1. Open [Google Calendar](https://calendar.google.com/) in your web browser.
2. In the left sidebar, hover over the calendar you want to sync and click the three dots (`⋮`) ➜ **Settings and sharing**.
3. Scroll down to the **Integrate calendar** section.
4. Locate the field titled **"Secret address in iCal format"**.
5. Click the copy icon to copy the private `.ics` URL.
   > **Note**: Do **not** use the "Public address in iCal format" unless your calendar is intentionally set to public.
6. Paste the URL into `config/.env`:
   ```ini
   ICAL_URLS=https://calendar.google.com/calendar/ical/.../basic.ics
   ```
7. To include multiple calendars (e.g. Work, Family, Birthdays), separate them with commas:
   ```ini
   ICAL_URLS=https://calendar.google.com/calendar/ical/cal1/basic.ics,https://calendar.google.com/calendar/ical/cal2/basic.ics
   ```

---

## 📝 Tasks & Notes Setup

By default, the server reads tasks directly from `config/tasks.md`. You can edit this file at any time (even while the server is running); updates appear on the next screen refresh.

```markdown
# Daily Focus & Tasks

- [ ] Complete Kindle TRMNL dashboard setup
- [ ] Review upcoming week calendar events
- [x] Configure Open-Meteo weather coordinates
- [ ] Charge Kindle e-reader battery
- [ ] Water indoor plants

# Quick Notes
- Grocery: Oat milk, Apples, Sourdough, Coffee beans
- Reminder: Trash pickup Tuesday 7:00 AM
```

* `- [ ] text` creates an unchecked task.
* `- [x] text` creates a completed task (rendered with strikethrough).
* Lines under `# Quick Notes` are rendered in the footer notes card.

---

## 📖 Kindle Client Setup (Jailbroken Kindle)

### Prerequisites on Kindle
1. A **jailbroken Kindle** (e.g., via LanguageBreak, WatchThis, or WinterBreak).
2. **KUAL** (Kindle Unified Application Launcher) installed.
3. **NiLuJe's FBInk** binary:
   - Download the precompiled binary from the [MobileRead FBInk thread](https://www.mobileread.com/forums/showthread.php?t=299066) or [GitHub Releases](https://github.com/NiLuJe/FBInk/releases).
   - Place `fbink` in `kindle/bin/fbink` (or install system-wide via NiLuJe's installer).

---

### Step 1: Configure Client Settings
On your computer, edit `kindle/config.sh`:
```bash
nano kindle/config.sh
```
Set `SERVER_URL` to your home server's IP address:
```sh
SERVER_URL="http://192.168.1.100:5055"
REFRESH_INTERVAL=900   # 15 minutes
```

---

### Step 2: Copy Files to Kindle via SCP
Connect your Kindle to Wi-Fi and copy the client folder:
```bash
# Copy client scripts to Kindle USB storage
scp -r kindle root@<kindle-ip>:/mnt/us/kindle-trmnl-dashboard

# Install KUAL menu extension
scp -r kindle/kual/kindle-trmnl root@<kindle-ip>:/mnt/us/extensions/
```

---

### Step 3: Run Setup on Kindle
SSH into your Kindle:
```bash
ssh root@<kindle-ip>
cd /mnt/us/kindle-trmnl-dashboard
sh setup.sh
```
`setup.sh` will:
- Set execution permissions.
- Validate `fbink`.
- Prevent screensaver timeout (`preventScreenSaver 1`).
- Turn off the frontlight to save power.
- Test server connectivity.

---

### Step 4: Start the Dashboard
You have two options to launch the dashboard:

#### Option A: Via KUAL Launcher (Recommended)
1. Open **KUAL** from your Kindle book library.
2. Select **Kindle TRMNL Dashboard**.
3. Tap **Start Dashboard Loop**.

#### Option B: Via SSH Terminal
```bash
cd /mnt/us/kindle-trmnl-dashboard
nohup sh loop.sh >/dev/null 2>&1 &
```

---

## 🔋 Battery Preservation Deep Dive

With our battery-preserving execution loop, an older Kindle can run for **3 to 6 weeks on a single battery charge**:

| Optimization | Implementation | Impact |
| :--- | :--- | :--- |
| **Frontlight Disabled** | `lipc-set-prop -i com.lab126.powerd flAsynchronouseLevel 0` | Saves ~60-80% power on illuminated models (Paperwhite/Oasis/Voyage). |
| **Wi-Fi Duty Cycle** | Wi-Fi is powered ON only for the ~10s download window, then powered OFF immediately. | Eliminates continuous wireless radio power draw. |
| **Deep RAM Sleep** | Device executes `echo mem > /sys/power/state` between refreshes. | Kindle enters true hardware sleep state (< 1mA current draw). |
| **Background Indexing Off** | `lipc-set-prop com.lab126.blanket unload` | Prevents Kindle OS from indexing files in the background. |
| **Dynamic Sleep Intervals** | Server can increase sleep interval during nighttime via `Refresh-Rate` header. | Fewer wake cycles when you're asleep. |

---

## 📱 Hardware Resolution Reference Table

Configure `KINDLE_SCREEN_WIDTH` and `KINDLE_SCREEN_HEIGHT` in `config/.env` according to your Kindle model:

| Model | Generation | Native Resolution | Recommended Orientation | Recommended Config |
| :--- | :--- | :--- | :--- | :--- |
| **TRMNL Native** | 7.5" E-ink | 800 × 480 | Landscape | `WIDTH=800, HEIGHT=480, ROTATION=0` |
| **Kindle Basic 4 / 5** | 4th / 5th | 600 × 800 | Landscape (800x600) | `WIDTH=800, HEIGHT=600, ROTATION=1` |
| **Kindle Touch** | 4th | 600 × 800 | Landscape (800x600) | `WIDTH=800, HEIGHT=600, ROTATION=1` |
| **Kindle Paperwhite 1 / 2**| 5th / 6th | 758 × 1024 | Landscape (1024x758) | `WIDTH=1024, HEIGHT=758, ROTATION=1` |
| **Kindle Paperwhite 3 / 4**| 7th / 10th | 1072 × 1448 | Landscape (1448x1072)| `WIDTH=1448, HEIGHT=1072, ROTATION=1` |
| **Kindle Voyage** | 7th | 1072 × 1448 | Landscape (1448x1072)| `WIDTH=1448, HEIGHT=1072, ROTATION=1` |
| **Kindle Oasis 1** | 8th | 1072 × 1448 | Landscape (1448x1072)| `WIDTH=1448, HEIGHT=1072, ROTATION=1` |
| **Kindle Paperwhite 5** | 11th | 1264 × 1680 | Landscape (1680x1264)| `WIDTH=1680, HEIGHT=1264, ROTATION=1` |
| **Kindle Oasis 2 / 3** | 9th / 10th | 1264 × 1680 | Landscape (1680x1264)| `WIDTH=1680, HEIGHT=1264, ROTATION=1` |

---

## 🛠️ TRMNL API Specification

| Method | Endpoint | Description | Headers Returned |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/setup` | Handshake verification | `status: 200` |
| `GET` | `/api/display` | Returns rendered e-ink image | `Refresh-Rate`, `Image-Format`, `Cache-Control` |
| `POST`| `/api/log` | Logs device battery % and RSSI | `status: 200` |
| `GET` | `/` | Desktop/Mobile preview page | HTML |
| `GET` | `/api/data` | Aggregated JSON context | JSON |
| `GET` | `/api/health`| Health status probe | JSON |

---

## ❓ Troubleshooting

### 1. Wi-Fi does not reconnect after wake
Some Kindle firmware versions require an extra 2–3 seconds after `lipc-set-prop com.lab126.cmd wirelessEnable 1`. You can increase `WIFI_TIMEOUT=30` in `kindle/config.sh`.

### 2. Device does not wake up automatically from sleep
On older Kindles running Linux 2.6/3.0 kernels, the RTC device is mapped to `/dev/rtc1`. On newer devices, it is `/dev/rtc0` or handled directly via `lipc-set-prop -i com.lab126.powerd rtcWakeup <seconds>`. `kindle/display.sh` tries both methods automatically.

### 3. Screen image looks inverted
If your Kindle displays white text on black background instead of black text on white, toggle `DITHERING=false` or adjust `FBINK_ROTATION` in `kindle/config.sh`.

---

## 📄 License
MIT License. Feel free to modify and share!