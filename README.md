# 📟 Kindle TRMNL Dashboard (`kindle-trmnl-dashboard`)

Turn your jailbroken **Amazon Kindle (WP63GW - 7th Gen Basic)** into a dedicated, low-power, ambient smart wall display compatible with the **TRMNL** e-ink protocol.

Built with **FastAPI**, **Playwright**, and **Pillow**, this repository delivers a self-hosted dashboard server (containerized via Docker / Dockge) along with battery-optimized client scripts utilizing NiLuJe's `fbink` for true deep-sleep e-ink rendering.

---

## 🌟 Key Features

* **Target Hardware (Kindle WP63GW / 7th Gen Basic):** Native 800×600 landscape layout, battery sysfs integration (`yoshi_battery` / `max77696-battery`), and frontlight-safe execution (no missing driver warnings).
* **TRMNL Protocol Compatible:** Implements standard TRMNL endpoints (`/api/setup`, `/api/display`, `/api/log`).
* **Multi-Feed Google Calendar:** Parses multiple private iCal (`.ics`) feeds with accurate **RFC 5545 recurring event expansion** (`recurring-ical-events`).
* **Open-Meteo Weather (Atlanta & Celsius Default):** Real-time weather, high/low forecasts, precipitation probability, humidity, and wind in **°C**—**no API key required**.
* **Flexible Tasks & Notes:**
  * **Local Markdown**: Edit `config/tasks.md` with standard `- [ ]` and `- [x]` checkboxes.
  * **Optional Google Keep**: Automatically sync checklist items from Google Keep (via `gkeepapi` with App Password).
  * **Structured JSON**: `config/tasks.json` fallback.
* **TRMNL Monochrome Aesthetic:** 2px high-contrast borders, clean modular grid (60% agenda/weather, 40% tasks/stats), and crisp SVG icons.
* **1-Bit E-Ink Pipeline:** Hardware-optimized bilevel rendering with optional **Floyd-Steinberg dithering** or clean thresholding in BMP or PNG.
* **Kindle Power Optimization:** Powers on Wi-Fi only for updates (~10 seconds), reports battery & signal telemetry, and suspends to deep RAM sleep (`echo mem > /sys/power/state`) using RTC wake alarms.
* **KUAL Launcher Extension:** Start, stop, refresh, and inspect device diagnostics straight from your Kindle screen.
* **Dockge & 1-Command Docker Deployment:** Tailored for `/opt/stacks/kindle-trmnl-dashboard` at `http://10.0.0.219:5055`.

---

## 🏛️ System Architecture

```
+-------------------------------------------------------------------------+
|                  Kindle WP63GW Display (7th Gen Basic)                  |
|                                                                         |
|  [RTC Wake Alarm] ──> [Enable Wi-Fi] ──> [Collect Batt % & Signal RSSI] |
|                                                      │                  |
|                                                      ▼                  |
|  [Suspend to Deep Sleep 'mem'] <── [fbink Draw] <── [Fetch /api/display]|
|                                                      ▲                  |
+──────────────────────────────────────────────────────┼──────────────────+
                                                       │ HTTP / Wi-Fi
+──────────────────────────────────────────────────────┼──────────────────+
|           Home Server: 10.0.0.219 (Docker / Dockge :5055)               |
|                                                      │                  |
|  • /api/log      <── Ingests Battery Telemetry ──────┘                  |
|  • /api/display  ──> Renders 800x600 E-ink Bitmap Image                 |
|                                                                         |
|  [Data Aggregator]                                                      |
|    ├── Google Calendar (iCal .ics feeds with recurring event expansion) |
|    ├── Open-Meteo API (Atlanta, GA | Celsius forecast, humidity, rain)  |
|    └── Tasks & Notes (config/tasks.md or Google Keep sync)              |
|                                                                         |
|  [Rendering Pipeline]                                                   |
|    Jinja2 Template ──> Headless Chromium ──> Pillow 1-Bit / Grayscale    |
+-------------------------------------------------------------------------+
```

---

## 🚀 Server Deployment: Dockge & Docker Compose

Designed to run cleanly under Dockge at `/opt/stacks/kindle-trmnl-dashboard` on your home server (`10.0.0.219`).

### Option A: Via Dockge (Recommended)
1. In Dockge UI (`http://10.0.0.219:5001`), click **+ Compose** to create a new stack.
2. Set Stack Name: `kindle-trmnl-dashboard`.
3. Paste the contents of `docker-compose.yml`:
   ```yaml
   services:
     kindle-trmnl:
       build:
         context: .
         dockerfile: Dockerfile
       container_name: kindle-trmnl-dashboard
       restart: unless-stopped
       ports:
         - "5055:5055"
       volumes:
         - ./config:/app/config
       env_file:
         - path: ./config/.env
           required: false
         - path: .env
           required: false
       environment:
         - PORT=5055
         - HOST=0.0.0.0
         - REFRESH_RATE_SECONDS=${REFRESH_RATE_SECONDS:-900}
         - ICAL_URLS=${ICAL_URLS:-}
         - LATITUDE=${LATITUDE:-33.7490}
         - LONGITUDE=${LONGITUDE:--84.3880}
         - LOCATION_NAME=${LOCATION_NAME:-Atlanta}
         - TIMEZONE=${TIMEZONE:-America/New_York}
         - KINDLE_SCREEN_WIDTH=${KINDLE_SCREEN_WIDTH:-800}
         - KINDLE_SCREEN_HEIGHT=${KINDLE_SCREEN_HEIGHT:-600}
         - IMAGE_FORMAT=${IMAGE_FORMAT:-png}
         - COLOR_MODE=${COLOR_MODE:-1bit}
         - DITHERING=${DITHERING:-true}
         - CELSIUS=${CELSIUS:-true}
   ```
4. Click **Start** to build and launch the container.
5. In the stack directory (`/opt/stacks/kindle-trmnl-dashboard/config`), you can edit `tasks.md` and `.env` at any time.

### Option B: Standalone Docker Compose (Terminal)
```bash
git clone https://github.com/anmol/kindle-trmnl-dashboard.git /opt/stacks/kindle-trmnl-dashboard
cd /opt/stacks/kindle-trmnl-dashboard
cp config/.env.example config/.env
docker compose up -d --build
```

### Verify in Your Web Browser
Open your browser to:
- **Interactive Web Preview**: `http://10.0.0.219:5055/`
- **Raw Rendered Image**: `http://10.0.0.219:5055/api/display`
- **Aggregated JSON Context**: `http://10.0.0.219:5055/api/data`
- **Interactive Swagger Docs**: `http://10.0.0.219:5055/docs`

---

## ⚙️ Configuration (`config/.env`)

```ini
# E-ink refresh interval in seconds (default: 900 = 15 minutes)
REFRESH_RATE_SECONDS=900

# Viewport dimensions (Kindle WP63GW 7th Gen Basic Landscape: 800x600)
KINDLE_SCREEN_WIDTH=800
KINDLE_SCREEN_HEIGHT=600
SCREEN_ORIENTATION=0

# Image format ('png' or 'bmp') and color mode ('1bit' or '8bit')
IMAGE_FORMAT=png
COLOR_MODE=1bit
DITHERING=true

# Timezone (IANA format)
TIMEZONE=America/New_York

# Google Calendar private iCal URLs (comma-separated for multiple feeds)
ICAL_URLS=https://calendar.google.com/calendar/ical/.../basic.ics

# Weather (Open-Meteo - Atlanta, GA default)
LATITUDE=33.7490
LONGITUDE=-84.3880
LOCATION_NAME=Atlanta
CELSIUS=true

# Optional: Google Keep Integration
GOOGLE_KEEP_EMAIL=
GOOGLE_KEEP_PASSWORD=
GOOGLE_KEEP_NOTE_TITLE="Kindle Tasks"
```

---

## 📝 Tasks & Notes Integration

### 1. Local Markdown (`config/tasks.md`)
By default, the server reads tasks directly from `config/tasks.md`. You can edit this file at any time; updates appear on the next screen refresh.

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

### 2. Google Keep Integration (Optional)
If you prefer adding tasks from your phone via Google Keep:
1. Create a checklist note in Google Keep titled **"Kindle Tasks"**.
2. Generate a [Google App Password](https://myaccount.google.com/apppasswords) (select App: *Other (Custom name)* ➜ *Kindle Dashboard*).
3. Set in `config/.env`:
   ```ini
   GOOGLE_KEEP_EMAIL=your.email@gmail.com
   GOOGLE_KEEP_PASSWORD=xxxx xxxx xxxx xxxx
   GOOGLE_KEEP_NOTE_TITLE="Kindle Tasks"
   ```
4. The dashboard will automatically sync the checked and unchecked items from your Keep note.

---

## 📅 Calendar Setup: Google Calendar iCal Feeds

You do **not** need a Google Cloud API key or OAuth setup to display your calendars. You can use your private iCal link:

1. Open [Google Calendar](https://calendar.google.com/) in your web browser.
2. In the left sidebar, hover over the calendar you want to sync and click the three dots (`⋮`) ➜ **Settings and sharing**.
3. Scroll down to the **Integrate calendar** section.
4. Locate the field titled **"Secret address in iCal format"**.
5. Copy the private `.ics` URL and paste it into `config/.env`:
   ```ini
   ICAL_URLS=https://calendar.google.com/calendar/ical/your_private_feed/basic.ics
   ```

---

## 📱 Kindle WP63GW Client Setup (7th Gen Basic)

The Kindle WP63GW (Kindle Touch 2 / 7th Gen Basic) features an 800×600 e-ink panel and does **not** have a built-in frontlight. Our scripts automatically handle these hardware specifications.

### Prerequisites on Kindle
1. A **jailbroken Kindle WP63GW** (via LanguageBreak or WatchThis).
2. **KUAL** (Kindle Unified Application Launcher) installed.
3. **NiLuJe's FBInk** binary:
   - Download `fbink-armel` or `fbink-armhf` from the [NiLuJe FBInk release thread](https://www.mobileread.com/forums/showthread.php?t=299066).
   - Place `fbink` in `kindle/bin/fbink` (or install via NiLuJe's KUAL extension).

---

### Step 1: Configure Client Settings
Edit `kindle/config.sh`:
```sh
# Set to your home server IP (default: 10.0.0.219:5055)
SERVER_URL="http://10.0.0.219:5055"

# Rotation for Kindle WP63GW (landscape 800x600):
# 1 = 90° clockwise landscape (default)
# 3 = 270° inverted landscape
FBINK_ROTATION=1
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
- Check frontlight hardware (gracefully skipped on WP63GW without driver warnings).
- Unload background book indexer to conserve battery.
- Test server connectivity to `http://10.0.0.219:5055/api/setup`.

---

### Step 4: Start the Dashboard
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

With our battery-preserving execution loop, a Kindle WP63GW runs for **4 to 8 weeks on a single battery charge**:

| Optimization | Implementation | Impact |
| :--- | :--- | :--- |
| **Frontlight Disabled** | Checked and skipped automatically on WP63GW. | No driver errors or wasted cycles. |
| **Wi-Fi Duty Cycle** | Wi-Fi is powered ON only for the ~10s download window, then powered OFF immediately. | Eliminates continuous wireless radio power draw. |
| **Deep RAM Sleep** | Device executes `echo mem > /sys/power/state` between refreshes. | Kindle enters true hardware sleep state (< 1mA current draw). |
| **Background Indexing Off** | `lipc-set-prop com.lab126.blanket unload` | Prevents Kindle OS from indexing files in the background. |
| **WP63GW Battery Sysfs** | Prioritizes `/sys/devices/system/yoshi_battery/battery_capacity` and `max77696-battery`. | Accurate battery telemetry on every refresh. |

---

## 📄 License
MIT License. Feel free to modify and share!