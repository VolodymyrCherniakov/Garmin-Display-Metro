# MetroDisplay — Garmin Connect IQ Watch Face

## Project Overview
- **Type**: Garmin Connect IQ (CIQ) Watch Face.
- **Language**: Monkey C (`.mc`).
- **Target Device**: Garmin Fenix 7X (`fenix7x`), 280x280 round MIP display.
- **Theme**: Post-apocalyptic Nixie tube watch face inspired by *Metro 2033* (Artyom's wristwatch).
- **Style**: Dark industrial PCB background with copper traces and gold vias, vacuum Nixie tubes with multi-pass neon glow, unlit cathode ghost filaments, wire anode mesh, Geiger dosimeter battery gauge, and military date badge.

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
    ├── all_digits_preview.png                  # Preview showing digit filaments 0-9
    ├── bin/
    │   ├── MetroDisplay.prg                    # Compiled watch face binary
    │   └── MetroDisplay.prg.debug.xml          # Debug symbol mapping
    ├── source/
    │   ├── MetroDisplayApp.mc                  # Application entry point (AppBase)
    │   ├── MetroDisplayView.mc                 # Core rendering & complications engine
    │   └── MetroDisplayBackground.mc           # Background canvas drawable handler
    └── resources/
        ├── drawables/launcher_icon.svg         # App launcher icon
        ├── layouts/layout.xml                  # Layout definition
        ├── settings/ (properties.xml, settings.xml) # Watch face settings
        └── strings/strings.xml                 # App text strings
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
  -d fenix7x \
  -f MetroDisplay/monkey.jungle \
  -y developer_key \
  -o MetroDisplay/bin/MetroDisplay.prg
```

From inside the `MetroDisplay` directory (`/home/x13/Projects/garmin_metro/MetroDisplay`):
```bash
/home/x13/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin/monkeyc \
  -d fenix7x \
  -f monkey.jungle \
  -y ../developer_key \
  -o bin/MetroDisplay.prg
```

---

## Visual Architecture & Rendering (`MetroDisplayView.mc`)

### Display Metrics
- **Screen Resolution**: 280 x 280 px (center: `(140, 140)`).
- **Tubes**:
  - Dimensions: width 44 px, height 92 px (Y: 94).
  - Tube X positions: `[36, 86, 150, 200]` for `[H1, H2, M1, M2]`.
  - Colon indicator: INS-1 neon glow dots at `X = 140`, `Y = 124` and `156`.

### Rendering Pipeline (Order of Execution in `onUpdate`)
1. **PCB Background**:
   - Dark industrial solder mask background (`0x08100C`).
   - Copper circuit traces (`0x183020`) with 45° and 90° bends.
   - Solder vias with copper pads (`0x4A4020`) and drill holes (`0x08100C`).
   - Technical silkscreen text (`METRO D-6 · DISP-01`), guide lines, and fiducial crosshairs.
2. **Nixie Tubes (`drawNixieTube`)**:
   - Stamped metal base socket (`0x1F2426`).
   - Dark vacuum cavity (`0x0A0D0B`).
   - Crosshatch anode mesh grid (`0x1A221C`).
   - Outer capsule glass border (`0x38423E`) + specular reflection streak (`0x587880`).
   - Unlit cathode ghost filament stack (subtle digit `8` at `0x22140A`).
   - Active bent-wire cathode digit (`0-9`) rendered with 3 passes:
     - Pass 1: Plasma halo (`0x882200`, pen width 6).
     - Pass 2: Neon orange glow (`0xFF5500`, pen width 3).
     - Pass 3: White-hot core (`0xFFFF66`, pen width 1).
3. **INS-1 Neon Indicator Bulbs**: Dual miniature glowing bulbs for time colon.
4. **Top Complication**: Military date badge plate (`DAY · DD MON`) with radiation warning triangle.
5. **Bottom Complication**: Geiger dosimeter 10-segment battery bar (`PWR %` or `CHG %`), dynamically colored for normal amber (`0xFF5500`), low battery red (`0xFF0000`), or charging green (`0x00FF88`).
6. **Bezel Screws**: 4 corner chassis bolts at 45° angles with slotted screw heads.

---

## Guidelines for Future Development
- **MIP Display Palette**: Keep colors aligned with the 64-color palette of Garmin Memory-in-Pixel (MIP) screens where possible to avoid dithering artifacts.
- **Battery Optimization**: Watch faces switch between high-power mode (`onExitSleep`) and low-power mode (`onEnterSleep`, 1 Hz to 1/min updates). Avoid heavy allocations inside `onUpdate(dc)`.
- **Anti-aliasing**: Always guard with `if (dc has :setAntiAlias)` before enabling anti-aliasing.
