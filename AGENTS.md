# MetroDisplay — Garmin Connect IQ Watch Face

## Project Overview
- **Type**: Garmin Connect IQ (CIQ) Watch Face.
- **Language**: Monkey C (`.mc`).
- **Target Device**: Garmin Fenix 7X (`fenix7x`), 280x280 round MIP display.
- **Theme**: Post-apocalyptic Tactical Dashboard Watch Face inspired by *Metro 2033* (Artyom's wristwatch).
- **Style**: Dark industrial PCB background with copper traces and gold vias, vacuum Nixie tubes with multi-pass neon glow, unlit cathode ghost filaments, wire anode mesh, vector icons for all metrics, sub-script digital seconds, Body Battery vitality complication, and full-width military date bar.

---

## Directory & File Structure
```
garmin_metro/
├── developer_key                               # Garmin CIQ RSA signing key
└── MetroDisplay/
    ├── AGENTS.md                               # Persistent context & instructions for AI agents
    ├── manifest.xml                            # App ID, minApiLevel="1.2.0", target: fenix7x
    ├── monkey.jungle                           # Project definition (project.manifest = manifest.xml)
    ├── preview_full.png                        # Rendered watch face preview (280x280)
    ├── render_preview.py                       # Python script for generating pixel-exact previews
    ├── all_digits_preview.png                  # Preview showing digit filaments 0-9
    ├── bin/
    │   ├── MetroDisplay.prg                    # Compiled watch face binary
    │   └── MetroDisplay.prg.debug.xml          # Debug symbol mapping
    ├── source/
    │   ├── MetroDisplayApp.mc                  # Application entry point & settings update dispatcher
    │   ├── MetroDisplayView.mc                 # Tactical dashboard engine, complications, & Nixie renderer
    │   ├── MetroDisplayDelegate.mc             # WatchFaceDelegate handling touch tap toggle
    │   └── MetroDisplayBackground.mc           # Background canvas drawable handler
    └── resources/
        ├── drawables/launcher_icon.svg         # App launcher icon
        ├── layouts/layout.xml                  # Layout definition
        ├── settings/ (properties.xml, settings.xml) # Customizable data slots & sunlight properties
        └── strings/strings.xml                 # App text strings & metric labels
```

---

## Build & Development Toolchain

### Monkey C Compiler (`monkeyc`)
The Garmin Connect IQ SDK is located at:
`/home/x13/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin/monkeyc`

### Build Command (Tested & Verified)
From the repository root (`/home/x13/Projects/garmin_metro`):
```bash
/home/x13/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin/monkeyc \
  -w \
  -d fenix7x \
  -f MetroDisplay/monkey.jungle \
  -y developer_key \
  -o MetroDisplay/bin/MetroDisplay.prg
```

From inside the `MetroDisplay` directory (`/home/x13/Projects/garmin_metro/MetroDisplay`):
```bash
/home/x13/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin/monkeyc \
  -w \
  -d fenix7x \
  -f monkey.jungle \
  -y ../developer_key \
  -o bin/MetroDisplay.prg
```

---

## Tactical Dashboard Architecture & Layout (`MetroDisplayView.mc`)

### Display Metrics (280 x 280 px, Center `(140, 140)`)

1. **Row 1: Very Top Row (Battery, Y: ~10 - 16, Center Y = 12)**:
   - Symmetrically centered battery block ($X=140$):
     - Dynamic vector battery icon with fill level + lightning bolt when charging.
     - Percentage text (e.g. `85%`).

2. **Row 2: Sunlight / Ambient Sensor Tube (Y: ~24 - 34, Center Y = 29)**:
   - Width 88 px, Height 10 px ($X=96$).
   - Stamped copper brackets at ends with rivets.
   - Evaluated via `isSunlitEnvironment()`:
     - Interactive Simulator Tap: `MetroDisplayDelegate` toggles `_debugSunlightOverride`.
     - App Settings Override: `SunlightMode` (0: Auto, 1: Always Lit, 2: Always Dark).
     - Astronomical: `Toybox.Weather.getSunrise()` / `getSunset()` based on GPS position.
     - Fallback: Civil daylight hours (06:30 - 19:30).

3. **Row 3: Upper Symmetrical Slots (Y: 42 - 62, Center Y = 52, 2 Fields)**:
   - Tightly placed directly below the sunlight tube:
     - Left Slot ($X=54, W=78, H=20$, Center $X=93$): **Altitude** (Mountain icon + e.g. `145m` / `480ft`).
     - Right Slot ($X=148, W=78, H=20$, Center $X=187$): **Weather Temperature** (Weather cloud/sun icon + e.g. `21°C` / `70°F`).

4. **Row 4: Full-Width Date Bar (Y: 72 - 90, Center Y = 81, 3 Fields)**:
   - Spanning full width ($W=208, H=18$ at $X=36, Y=72$):
     - Left Field ($X: 36 - 96$, Center $X=66$): Day of week (`WED`).
     - Center Field ($X: 96 - 184$, Center $X=140$): Calendar icon + Month/Day (`30 SEP`).
     - Right Field ($X: 184 - 244$, Center $X=214$): Tactical Hazard / Status rune.

5. **Row 5: Center Time, Sub-script Seconds, & Side Icons (Y: 100 - 164)**:
   - **Main Nixie Time (HH:MM)**: Scaled tubes ($W=26, H=50$ at $Y=100-150$) at $X=[64, 94, 160, 190]$. Multi-pass glow, ghost filament `8`, wire anode mesh. Symmetrically centered at $X=140$.
   - **INS-1 Colon Bulbs**: Miniature dual glowing bulbs at $X=140$, $Y=115$ and $Y=135$.
   - **Sub-script Digital Seconds ($X=172 - 204, Y=152 - 164$)**: Compact plate positioned **directly underneath the minutes digits**, updating cleanly at 1 Hz (dimmed `--` in sleep mode).
   - **Side Status Icons**:
     - Left ($X=36$): Bluetooth status icon at $Y=118$ + **Dynamic Alarm Bell Icon** at $Y=136$ (displayed *only* if `alarmCount > 0`).
     - Right ($X=244, Y=125$): Notification status message bubble icon (cyan with unread indicator dot when notifications present).

6. **Row 6: Lower Data Slots (Y: 170 - 190, Center Y = 180, 3 Fields)**:
   - Placed directly under the time block:
     - Left Slot ($X=38, W=62, H=20$, Center $X=69$): **Calories** (Flame icon + `1840`).
     - Center Slot ($X=108, W=64, H=20$, Center $X=140$): **Steps** (Footsteps icon + `10741`).
     - Right Slot ($X=180, W=62, H=20$, Center $X=211$): **Heart Rate** (Heart icon + `80`).

7. **Row 7 & 8: Stacked Bottom Rows (Shifted Lower Towards Edge)**:
   - Integrated with PCB grid bus rails connecting Rows 6, 7, and 8:
     - **Row 7: Distance Block ($Y=196 - 214$, Center $Y=205$)**: $W=96, H=18$ at $X=92$. Location pin icon + `5.4 km` / `3.4 mi`.
     - **Row 8: Body Battery Block ($Y=220 - 238$, Center $Y=229$)**: $W=96, H=18$ at $X=92$. Updated **vitality human silhouette with glowing energy core icon** + `75%`.

8. **Chassis Bolts**:
   - 4 corner chassis screws at $(38, 52)$, $(242, 52)$, $(48, 224)$, $(232, 224)$, completely clear of all data slots and screen curvature.

---

## Customizable Data Fields (Settings Integration)

Each data slot is user-configurable via Garmin Connect / Garmin Express with options:
- `0`: None (Off)
- `1`: Heart Rate
- `2`: Battery
- `3`: Steps
- `4`: Calories
- `5`: Distance
- `6`: Weather / Temperature
- `7`: Sunrise / Sunset
- `8`: Active Minutes
- `9`: Floors Climbed
- `10`: Altitude / Elevation
- `11`: Body Battery

### Settings Lifecycle
1. `properties.xml` defines default slot assignments.
2. `settings.xml` provides user-facing dropdown list pickers.
3. `MetroDisplayApp.onSettingsChanged()` forwards changes to `MetroDisplayView.onSettingsChanged()`.
4. Properties are cached in integer member variables upon load to avoid garbage collection allocations during 1 Hz rendering.
