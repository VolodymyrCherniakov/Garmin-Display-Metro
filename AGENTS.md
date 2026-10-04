# MetroDisplay — Garmin Connect IQ Watch Face

## Project Overview
- **Type**: Garmin Connect IQ (CIQ) Watch Face.
- **Language**: Monkey C (`.mc`).
- **Target Device**: Garmin Fenix 7X (`fenix7x`), 280x280 round MIP display.
- **Theme**: Post-apocalyptic Tactical Dashboard Watch Face inspired by *Metro 2033* (Artyom's wristwatch).
- **Style**: Dark industrial PCB background with muted copper traces and gold vias, enlarged vacuum Nixie tubes with multi-pass neon glow, unlit cathode ghost filaments, wire anode mesh, vector icons for all metrics, right-aligned sub-script digital seconds, wide glowing ambient sensor tube, and a seamless stepped-pyramid tactical grid.

---

## Directory & File Structure
```
garmin_metro/
├── developer_key                               # Garmin CIQ RSA signing key
└── MetroDisplay/
    ├── AGENTS.md                               # Persistent context & instructions for AI agents
    ├── manifest.xml                            # App ID, minApiLevel="1.2.0", target: fenix7x
    ├── monkey.jungle                           # Project definition (project.manifest = manifest.xml)
    ├── preview_full.png                        # Rendered watch face preview (280x280, lit sunlight state)
    ├── preview_dark.png                        # Rendered watch face preview (280x280, dark sunlight state)
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

1. **Row 1: Top Center Battery (Y: 20 - 30, Center Y = 25)**:
   - Symmetrically centered battery block ($X=140$):
     - Dynamic vector battery icon with fill level + lightning bolt when charging.
     - Percentage text (e.g. `85%`).

2. **Row 2: Bigger Sunlight / Ambient Sensor Tube (Y: 42 - 57, Center Y = 49.5)**:
   - Enlarged dimensions: Width 116 px, Height 15 px ($X=82 - 198$).
   - Scaled copper brackets at ends ($8 \times 17$ px) with copper rivets.
   - Brighter electric cyan bloom and white-hot core in lit state. Dark cavity with cold tungsten wire in unlit state.
   - Evaluated via `isSunlitEnvironment()`:
     - Interactive Simulator Tap: `MetroDisplayDelegate` toggles `_debugSunlightOverride`.
     - App Settings Override: `SunlightMode` (0: Auto, 1: Always Lit, 2: Always Dark).
     - Astronomical: `Toybox.Weather.getSunrise()` / `getSunset()` based on GPS position.
     - Fallback: Civil daylight hours (06:30 - 19:30).

3. **Row 3: Centered 7-Segment Nixie Clock, INS-1 Bulbs, Right-Side Seconds & Side Icons (Y: 105 - 175, Center Y = 140)**:
   - **Main Nixie Time (HH:MM)**: Centered vertically and horizontally around $(140, 140)$ ($W=38, H=70$ at $Y=105-175$) at $X=[54, 96, 146, 188]$.
   - **Classic 7-Segment Display & Real Nixie Look**:
     - Standard 7-segment layout (`a` top, `b` upper-right, `c` lower-right, `d` bottom, `e` lower-left, `f` upper-left, `g` middle) spanning $26 \times 52$ px with thickness $5$ px.
     - Each segment is an elongated hexagon with pointed ends and beveled 45° corners drawn with filled polygons (`fillPolygon`), leaving a clean $1-2$ px gap between neighboring segments.
     - **Pre-computed Segment Bitmasks** (`a=bit0(1)` ... `g=bit6(64)`):
       - `0`: `0x3F` (a, b, c, d, e, f)
       - `1`: `0x06` (b, c)
       - `2`: `0x5B` (a, b, d, e, g)
       - `3`: `0x4F` (a, b, c, d, g)
       - `4`: `0x66` (b, c, f, g)
       - `5`: `0x6D` (a, c, d, f, g)
       - `6`: `0x7D` (a, c, d, e, f, g)
       - `7`: `0x07` (a, b, c)
       - `8`: `0x7F` (a, b, c, d, e, f, g)
       - `9`: `0x6F` (a, b, c, d, f, g)
     - **Multi-pass Neon Glow**:
       1. Soft outer plasma halo (`COLOR_HALO_OUTER`, `0x882200`, pen width 7).
       2. Vibrant neon-orange mid glow (`COLOR_GLOW_MID`, `0xFF5500`, beveled polygon).
       3. White-hot core filament spine (`COLOR_CORE_HOT`, `0xFFFF66`, pen width 1).
     - **Unlit Cathode Ghost Segments**: Always drawn in dim copper tone (`COLOR_GHOST_FILAMENT`, `0x22140A`) for all unlit segments, so every tube displays a faint "8" behind the lit digit for vacuum tube physical depth.
     - **Zero GC Allocations**: All polygon coordinate arrays and spine lines for all 4 tubes are pre-allocated in `onLayout()`; `onUpdate()` only references cached arrays.
     - Wire anode mesh (crosshatch grid inside the glass cavity).
     - Stamped metal socket base at tube bottom and specular highlight reflections on tube shoulder/edge.
   - **INS-1 Colon Bulbs**: Miniature dual glowing neon bulbs centered at $X=140$, $Y=126$ and $Y=154$.
   - **Right-Aligned Sub-script Digital Seconds ($X=230, Y=162$)**: Positioned on the **right side of the minutes tubes** with 4 px gap (tube right edge at 226), baseline aligned with the bottom edge of the tubes (at $Y \approx 175$). Updates at 1 Hz (dimmed `--` in sleep mode). Clear of display edge and notification icon.
   - **Side Status Icons**:
     - Left ($X=32$): Bluetooth status icon at $Y=131$ (centered at $Y=140$ when no alarm) + **Dynamic Alarm Bell Icon** at $Y=144$ (displayed *only* if `alarmCount > 0`).
     - Right ($X=248, Y=125$): Notification status message bubble icon (cyan with unread indicator dot when notifications present), moved up to clear seconds.

4. **Seamless Stepped Pyramid Grid (Y: 202 - 268, H=66, Zero Gaps, Inner Dividers Only)**:
   All data plates below the time touch each other with zero gap as one continuous table/grid.
   - **Outer Border Removed**: No border lines around the outer perimeter or shoulders. Grid shape is defined cleanly by the dark plate fill (`COLOR_PLATE_BG`) against the PCB background.
   - **Inner Dividers Only**: Thin dim dark-green 1 px divider lines (`COLOR_PLATE_BORDER`, `0x24362A`) separating adjacent cells:
     - 2 vertical dividers in Row A at $X=102$ and $X=178$ ($Y \in [202, 224]$).
     - 1 horizontal shared divider between Row A and Row B from $X=64$ to $X=216$ at $Y=224$.
     - 1 vertical divider in Row B at $X=140$ ($Y \in [224, 246]$).
     - 1 horizontal shared divider between Row B and Row C from $X=104$ to $X=176$ at $Y=246$.
   - **Icon & Typography Scaling**:
     - Scaled vector icons (11 - 12 px) for all metrics (stairs, heart, cloud, footsteps, flame, vitality).
     - Value text rendered consistently with `FONT_SYSTEM_XTINY` for all cells.
     - Compact weather format: `24°/25°` (no spaces around slash).
   - **Row A (Full width, Y: 202 - 224, H=22, X: 26 - 254, W=228, 3 Cells of 76 px, Center Y=213)**:
     - Left Cell ($X: 26 - 102$, Center $X=64$): **Floors Climbed** (Ascending stairs icon + plain number e.g. `12`). Default slot `SlotMidLeft = 9`.
     - Center Cell ($X: 102 - 178$, Center $X=140$): **Heart Rate** (Heart icon + bpm e.g. `80`). Default slot `SlotMidCenter = 1`.
     - Right Cell ($X: 178 - 254$, Center $X=216$): **Temperature & Feels-Like** (Weather cloud icon + compact `24°/25°`). Default slot `SlotMidRight = 12`.
   - **Row B (Centered below Row A, Y: 224 - 246, H=22, X: 64 - 216, W=152, 2 Cells of 76 px, Center Y=235)**:
     - Left Cell ($X: 64 - 140$, Center $X=102$): **Steps** (Footsteps icon + e.g. `10741`). Default slot `SlotLowerLeft = 3`.
     - Right Cell ($X: 140 - 216$, Center $X=178$): **Calories** (Flame icon + e.g. `1840`). Default slot `SlotLowerRight = 4`.
   - **Row C (Centered below Row B, Y: 246 - 268, H=22, X: 104 - 176, W=72, 1 Cell, Center Y=257)**:
     - Center Cell ($X: 104 - 176$, Center $X=140$): **Body Battery** (Vitality silhouette icon + percentage e.g. `75%`). Default slot `SlotBottom = 11`.
   - **Bottom Spacing & Safe Margins**:
     - Grid bottom edge at $Y=268$ leaves an exact $8 - 12$ px clearance from the circular bezel, following the curvature cleanly.
     - Vertical negative space: Top margin 20 px, Battery $\to$ Sunlight 12 px, Sunlight $\to$ Time 48 px, Time $\to$ Grid 27 px, Grid $\to$ Bezel 8-12 px.

5. **PCB Traces & Solder Vias (Muted, Thinner, Outside Grid Only)**:
   - Traces exist strictly outside the grid in open areas: top rails ($Y: 25-42$), side traces ($Y: 120-160, 100-140$), intermediate traces ($Y=188$), and lower side traces ($Y: 224-246$).
   - Muted copper color (`0x122418`), pen width 1 px.
   - Solder vias driven by static `VIA_COORDS` lookup table to guarantee zero GC allocations during rendering.
   - Silkscreen fiducials at $(24, 140)$.

6. **Chassis Bolts**:
   - 4 perimeter chassis screws at $(36, 54)$, $(244, 54)$, $(48, 228)$, $(232, 228)$, completely clear of all data slots and screen boundaries (margin $\ge 19$ px to bezel). Driven by static `CHASSIS_BOLTS` table.

---

## Customizable Data Fields (Settings Integration)

Each data slot is user-configurable via Garmin Connect / Garmin Express with options:
- `0`: None (Off)
- `1`: Heart Rate
- `2`: Battery
- `3`: Steps
- `4`: Calories
- `5`: Distance
- `6`: Weather (Current Temp)
- `7`: Sunrise / Sunset
- `8`: Active Minutes
- `9`: Floors Climbed
- `10`: Altitude / Elevation
- `11`: Body Battery
- `12`: Temp & Feels-Like

### Slot Properties
- `SlotMidLeft`: Row A Left Cell (Default: 9, Floors Climbed)
- `SlotMidCenter`: Row A Center Cell (Default: 1, Heart Rate)
- `SlotMidRight`: Row A Right Cell (Default: 12, Temp & Feels-Like)
- `SlotLowerLeft`: Row B Left Cell (Default: 3, Steps)
- `SlotLowerRight`: Row B Right Cell (Default: 4, Calories)
- `SlotBottom`: Row C Center Cell (Default: 11, Body Battery)

### Settings Lifecycle
1. `properties.xml` defines default slot assignments.
2. `settings.xml` provides user-facing dropdown list pickers.
3. `MetroDisplayApp.onSettingsChanged()` forwards changes to `MetroDisplayView.onSettingsChanged()`.
4. Properties are cached in integer member variables upon load to avoid garbage collection allocations during 1 Hz rendering.
