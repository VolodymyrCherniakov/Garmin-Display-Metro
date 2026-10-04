import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

//! MetroDisplayView
//! Tactical dashboard Watch Face inspired by Metro 2033 (Artyom's wristwatch).
//! Designed with an edge-to-edge PCB grid frame for the Garmin Fenix 7X (280x280 round display).
//!
//! Layout Structure:
//! 1. Row 1 (Y: ~18-28, Center Y = 25): Centralized Battery icon + percentage at top
//! 2. Row 2 (Y: ~42-57, Center Y = 49.5): Wider & taller glowing neon sunlight/ambient tube (116x15)
//! 3. Row 3 (Y: 105-175, Center Y = 140): Centered 7-segment Nixie clock (HH:MM, 38x70), INS-1 colon bulbs, sub-script seconds on right (X=230, Y=162), side icons
//! 4. Seamless Stepped Pyramid Grid (Y: 202-268, Zero gaps, shared 1px inner dividers, no outer border):
//!    - Row A (Y: 202-224, Center Y = 213, 3 cells): Floors | Heart Rate | Weather & Feels-like
//!    - Row B (Y: 224-246, Center Y = 235, 2 cells): Steps | Calories
//!    - Row C (Y: 246-268, Center Y = 257, 1 cell): Body Battery (8-10px from bottom display edge)
class MetroDisplayView extends WatchUi.WatchFace {

    // Metric Types Enum
    enum MetricType {
        METRIC_NONE               = 0,
        METRIC_HEART_RATE         = 1,
        METRIC_BATTERY            = 2,
        METRIC_STEPS              = 3,
        METRIC_CALORIES           = 4,
        METRIC_DISTANCE           = 5,
        METRIC_WEATHER            = 6,
        METRIC_SUNRISE_SUNSET     = 7,
        METRIC_ACTIVE_MINUTES     = 8,
        METRIC_FLOORS             = 9,
        METRIC_ALTITUDE           = 10,
        METRIC_BODY_BATTERY       = 11,
        METRIC_WEATHER_FEELS_LIKE = 12
    }

    // Icon Types Enum
    enum IconType {
        ICON_NONE         = 0,
        ICON_ALTITUDE     = 1,
        ICON_WEATHER      = 2,
        ICON_CALENDAR     = 3,
        ICON_BELL         = 4,
        ICON_BLUETOOTH    = 5,
        ICON_PHONE        = 6,
        ICON_FLAME        = 7,
        ICON_STEPS        = 8,
        ICON_HEART        = 9,
        ICON_DISTANCE     = 10,
        ICON_VITALITY     = 11,
        ICON_BATTERY      = 12,
        ICON_HAZARD       = 13,
        ICON_STAIRS       = 14
    }

    // Display geometry (280x280 for fenix7x)
    private var _screenW as Lang.Number = 280;
    private var _centerX as Lang.Number = 140;

    // Centered 8-bit Nixie tube layout coordinates (Y: 105 - 175, Center Y = 140)
    private var _tubeW as Lang.Number = 38;
    private var _tubeH as Lang.Number = 70;
    private var _tubeY as Lang.Number = 105;
    private var _tubeXs as Lang.Array<Lang.Number> = [54, 96, 146, 188];

    // 7-Segment Display Bitmasks for Digits 0-9
    // Segments: a=bit0(1), b=bit1(2), c=bit2(4), d=bit3(8), e=bit4(16), f=bit5(32), g=bit6(64)
    private const SEGMENT_MASKS = [
        0x3F, // 0: a, b, c, d, e, f
        0x06, // 1: b, c
        0x5B, // 2: a, b, d, e, g
        0x4F, // 3: a, b, c, d, g
        0x66, // 4: b, c, f, g
        0x6D, // 5: a, c, d, f, g
        0x7D, // 6: a, c, d, e, f, g
        0x07, // 7: a, b, c
        0x7F, // 8: a, b, c, d, e, f, g
        0x6F  // 9: a, b, c, d, f, g
    ];

    // Base 7-segment polygon coordinates (relative to digit origin, 26x52 px, thickness 5)
    private const BASE_SEG_POLYGONS = [
        [[3, 2], [5, 0], [21, 0], [23, 2], [21, 4], [5, 4]],        // a (top horizontal)
        [[24, 3], [26, 5], [26, 23], [24, 25], [22, 23], [22, 5]],   // b (upper-right vertical)
        [[24, 27], [26, 29], [26, 47], [24, 49], [22, 47], [22, 29]],// c (lower-right vertical)
        [[3, 50], [5, 48], [21, 48], [23, 50], [21, 52], [5, 52]],   // d (bottom horizontal)
        [[2, 27], [4, 29], [4, 47], [2, 49], [0, 47], [0, 29]],      // e (lower-left vertical)
        [[2, 3], [4, 5], [4, 23], [2, 25], [0, 23], [0, 5]],        // f (upper-left vertical)
        [[3, 26], [5, 24], [21, 24], [23, 26], [21, 28], [5, 28]]    // g (middle horizontal)
    ];

    // Base segment spine lines for filament glow [x1, y1, x2, y2]
    private const BASE_SPINE_LINES = [
        [5, 2, 21, 2],   // a
        [24, 5, 24, 23], // b
        [24, 29, 24, 47],// c
        [5, 50, 21, 50], // d
        [2, 29, 2, 47],  // e
        [2, 5, 2, 23],   // f
        [5, 26, 21, 26]  // g
    ];

    // Pre-allocated per-tube segment polygons & spine lines (zero GC allocations in onUpdate)
    private var _tubePolygons as Lang.Array<Lang.Array<Lang.Array<[Lang.Numeric, Lang.Numeric]> > >?;
    private var _tubeSpines as Lang.Array<Lang.Array<Lang.Array<Lang.Number> > >?;
    private var _digitsCache as Lang.Array<Lang.Number> = [0, 0, 0, 0];

    // State & Interactive Flags
    private var _isSleepMode as Lang.Boolean = false;
    private var _debugSunlightOverride as Lang.Boolean? = null;

    // User Settings Cache
    private var _sunlightMode as Lang.Number = 0;
    private var _slotMidLeft as Lang.Number = 9;       // Floors Climbed
    private var _slotMidCenter as Lang.Number = 1;     // Heart Rate
    private var _slotMidRight as Lang.Number = 12;     // Weather (Temp & Feels-Like)
    private var _slotLowerLeft as Lang.Number = 3;     // Steps
    private var _slotLowerRight as Lang.Number = 4;    // Calories
    private var _slotBottom as Lang.Number = 11;       // Body Battery

    // Nixie tube color palette (Orange-Amber Glow)
    private const COLOR_HALO_OUTER      = 0x882200; // Deep glowing red-orange plasma halo
    private const COLOR_GLOW_MID        = 0xFF5500; // Bright neon orange
    private const COLOR_CORE_HOT        = 0xFFFF66; // White-hot filament center
    private const COLOR_GHOST_FILAMENT  = 0x22140A; // Dim unlit cathode wire in background
    private const COLOR_TUBE_GLASS_BG   = 0x0A0D0B; // Deep dark cavity inside tube
    private const COLOR_TUBE_BORDER     = 0x38423E; // Outer glass capsule rim
    private const COLOR_TUBE_HIGHLIGHT  = 0x587880; // Specular glass reflection
    private const COLOR_MESH_GRID       = 0x1A221C; // Anode wire mesh grid
    private const COLOR_SOCKET_BASE     = 0x1F2426; // Stamped metal socket base
    private const COLOR_SOCKET_BORDER   = 0x101314; // Socket outline

    // Top Sunlight Neon Tube Palette (Electric Cyan & Ice-Blue Glow)
    private const COLOR_SUN_HALO        = 0x0055AA; // Brilliant electric cobalt bloom
    private const COLOR_SUN_GLOW_MID    = 0x00CCFF; // Vibrant neon cyan beam
    private const COLOR_SUN_CORE_HOT    = 0xFFFFFF; // White-hot center filament
    private const COLOR_SUN_OFF_BG      = 0x0A1014; // Dark cavity when unlit
    private const COLOR_SUN_OFF_RIM     = 0x2A343A; // Unlit glass border
    private const COLOR_SUN_OFF_WIRE    = 0x222C32; // Unlit grey tungsten wire
    private const COLOR_SUN_BRACKET     = 0x5A4830; // Stamped copper bracket
    private const COLOR_SUN_BRACKET_RIM = 0x382C1E; // Bracket outline
    private const COLOR_SUN_RIVET       = 0x9C7E4C; // Copper rivets

    // PCB background colors (Muted, Darker Outside Traces)
    private const COLOR_PCB_BG          = 0x08100C; // Dark industrial solder mask
    private const COLOR_PCB_TRACE       = 0x122418; // Muted, dark copper/green trace
    private const COLOR_PCB_VIA_PAD     = 0x3A3218; // Muted gold solder via pad
    private const COLOR_PCB_SILK        = 0x233428; // Silkscreen markings
    private const COLOR_SCREW_RIM       = 0x40454A; // Perimeter chassis screw rim
    private const COLOR_SCREW_HEAD      = 0x282C30; // Screw head face
    private const COLOR_SCREW_SLOT      = 0x101214; // Screw drive slot

    // Tactical Plates & Phosphor Colors
    private const COLOR_PLATE_BG        = 0x0C1410; // Dark stamped plate
    private const COLOR_PLATE_BORDER    = 0x24362A; // Single 1px border rim
    private const COLOR_TEXT_AMBER      = 0xFFAA00; // Phosphor amber
    private const COLOR_TEXT_ORANGE     = 0xFF7700; // Phosphor orange
    private const COLOR_TEXT_GREEN      = 0x00FF88; // Phosphor electric green
    private const COLOR_TEXT_CYAN       = 0x00D0FF; // Phosphor ice cyan
    private const COLOR_TEXT_RED        = 0xFF3300; // Warning red
 
    // Static coordinate tables (prevent heap allocations in onUpdate)
    private const VIA_COORDS = [
        [96, 14], [184, 14],
        [25, 120], [25, 160],
        [255, 100], [255, 140],
        [64, 188], [140, 188], [216, 188],
        [48, 246], [232, 246]
    ];

    private const CHASSIS_BOLTS = [
        [36, 54],
        [244, 54],
        [48, 228],
        [232, 228]
    ];

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    //! Load user-configurable settings
    public function loadSettings() as Void {
        _sunlightMode = readProperty("SunlightMode", 0);
        _slotMidLeft = readProperty("SlotMidLeft", 9);
        _slotMidCenter = readProperty("SlotMidCenter", 1);
        _slotMidRight = readProperty("SlotMidRight", 12);
        _slotLowerLeft = readProperty("SlotLowerLeft", 3);
        _slotLowerRight = readProperty("SlotLowerRight", 4);
        _slotBottom = readProperty("SlotBottom", 11);
    }

    //! Safe property reader with fallback
    private function readProperty(key as Lang.String, defaultValue as Lang.Number) as Lang.Number {
        try {
            if (Application has :Properties && Application.Properties has :getValue) {
                var val = Application.Properties.getValue(key);
                if (val != null) {
                    return val as Lang.Number;
                }
            }
        } catch (e) {
            // Fall back to default
        }
        return defaultValue;
    }

    //! Called by MetroDisplayApp when settings are changed
    public function onSettingsChanged() as Void {
        _debugSunlightOverride = null;
        loadSettings();
        WatchUi.requestUpdate();
    }

    //! Load layout metrics
    function onLayout(dc as Graphics.Dc) as Void {
        _screenW = dc.getWidth();
        _centerX = _screenW / 2;

        _tubeW = 38;
        _tubeH = 70;
        _tubeY = 105;
        _tubeXs = [54, 96, 146, 188];

        var digitW = 26;
        var digitH = 52;
        var dxOff = (_tubeW - digitW) / 2; // 6
        var dyOff = (_tubeH - digitH) / 2; // 9

        var tubePolys = new [4] as Lang.Array<Lang.Array<Lang.Array<[Lang.Numeric, Lang.Numeric]> > >;
        var tubeSp = new [4] as Lang.Array<Lang.Array<Lang.Array<Lang.Number> > >;

        for (var t = 0; t < 4; t++) {
            var ox = _tubeXs[t] + dxOff;
            var oy = _tubeY + dyOff;

            var segList = new [7] as Lang.Array<Lang.Array<[Lang.Numeric, Lang.Numeric]> >;
            var spList = new [7] as Lang.Array<Lang.Array<Lang.Number> >;

            for (var s = 0; s < 7; s++) {
                var basePoly = BASE_SEG_POLYGONS[s] as Lang.Array<Lang.Array<Lang.Number> >;
                var poly = new [6] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;
                for (var p = 0; p < 6; p++) {
                    poly[p] = [basePoly[p][0] + ox, basePoly[p][1] + oy];
                }
                segList[s] = poly;

                var baseSp = BASE_SPINE_LINES[s] as Lang.Array<Lang.Number>;
                spList[s] = [baseSp[0] + ox, baseSp[1] + oy, baseSp[2] + ox, baseSp[3] + oy];
            }

            tubePolys[t] = segList;
            tubeSp[t] = spList;
        }

        _tubePolygons = tubePolys;
        _tubeSpines = tubeSp;
    }

    function onShow() as Void {
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
        _isSleepMode = false;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        _isSleepMode = true;
        WatchUi.requestUpdate();
    }

    //! Main Render Loop
    function onUpdate(dc as Graphics.Dc) as Void {
        if (!_isSleepMode && dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // 1. Draw Integrated PCB Background Grid Frame (Muted, Outside Only)
        drawPcbBackground(dc);

        // 2. Row 1: Centralized Top Battery Icon + Percentage (Y: ~8-16, Center Y = 12)
        drawTopBattery(dc);

        // 3. Row 2: Wider & Taller Sunlight / Ambient Tube Directly Below Battery (Y: ~25-38, Center Y = 31)
        var isSunlit = isSunlitEnvironment();
        drawTopSunlightTube(dc, isSunlit);

        // 4. Row 3: Scaled Nixie Clock (HH:MM) + INS-1 Colon + Sub-script Seconds + Side Icons (Y: 48-114)
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        var minutes = clockTime.min;
        var seconds = clockTime.sec;

        var is24Hour = System.getDeviceSettings().is24Hour;
        if (!is24Hour) {
            if (hours == 0) {
                hours = 12;
            } else if (hours > 12) {
                hours = hours - 12;
            }
        }

        var hTens = hours / 10;
        var hOnes = hours % 10;
        var mTens = minutes / 10;
        var mOnes = minutes % 10;

        if (!is24Hour && hTens == 0) {
            hTens = -1; // Blank leading zero
        }

        _digitsCache[0] = hTens;
        _digitsCache[1] = hOnes;
        _digitsCache[2] = mTens;
        _digitsCache[3] = mOnes;

        for (var i = 0; i < 4; i++) {
            drawNixieTube(dc, i, _tubeXs[i], _tubeY, _tubeW, _tubeH, _digitsCache[i]);
        }

        // INS-1 Colon Lamps (X: 140, between Hours and Minutes)
        drawColonIndicator(dc);

        // Sub-script Digital Seconds (Rendered on RIGHT side of minutes tubes, bottom-aligned)
        drawSubscriptSeconds(dc, seconds);

        // Side Status Icons (Left: Bluetooth + Dynamic Alarm; Right: Notification)
        drawSideIcons(dc);

        // 5. Seamless Stepped Pyramid Grid (Zero Gaps, Single 1px Shared Borders)
        // Row A: Floors, Heart Rate, Weather & Feels-like
        // Row B: Steps, Calories
        // Row C: Body Battery
        drawSeamlessGrid(dc, isSunlit);

        // 6. Outer Industrial Chassis Bolts (Corner Screws)
        drawChassisBolts(dc);
    }

    // =========================================================================
    // ROW 1: CENTRALIZED TOP BATTERY (Center Y = 25)
    // =========================================================================

    private function drawTopBattery(dc as Graphics.Dc) as Void {
        var bat = getBatteryPercent();
        var charging = isBatteryCharging();

        var text = Lang.format("$1$%", [bat]);
        var textW = dc.getTextWidthInPixels(text, Graphics.FONT_SYSTEM_XTINY);

        var iconW = 14;
        var gap = 4;
        var totalW = iconW + gap + textW;

        var startX = _centerX - (totalW / 2);
        var cy = 25;

        var col = charging ? COLOR_TEXT_GREEN : ((bat <= 20) ? COLOR_TEXT_RED : COLOR_TEXT_AMBER);
        drawBatteryIcon(dc, startX, cy - 4, bat, charging, col);

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            startX + iconW + gap,
            cy,
            Graphics.FONT_SYSTEM_XTINY,
            text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // =========================================================================
    // ROW 2: BIGGER SUNLIGHT TUBE (W: 116, H: 15, X: 82-198, Y: 42-57, Center Y = 49.5)
    // =========================================================================

    public function toggleDebugSunlight() as Void {
        if (_debugSunlightOverride == null) {
            _debugSunlightOverride = !isSunlitEnvironment();
        } else {
            _debugSunlightOverride = !_debugSunlightOverride;
        }
        WatchUi.requestUpdate();
    }

    private function isSunlitEnvironment() as Lang.Boolean {
        if (_debugSunlightOverride != null) {
            return _debugSunlightOverride as Lang.Boolean;
        }

        if (_sunlightMode == 1) {
            return true;
        } else if (_sunlightMode == 2) {
            return false;
        }

        if (Toybox has :Weather && Weather has :getSunrise && Weather has :getSunset) {
            try {
                var conditions = Weather.getCurrentConditions();
                if (conditions != null && conditions.observationLocationPosition != null) {
                    var now = Time.now();
                    var loc = conditions.observationLocationPosition as Position.Location;
                    var sunrise = Weather.getSunrise(loc, now);
                    var sunset = Weather.getSunset(loc, now);
                    if (sunrise != null && sunset != null) {
                        return (now.greaterThan(sunrise) && now.lessThan(sunset));
                    }
                }
            } catch (e) {
                // Fallback
            }
        }

        var clockTime = System.getClockTime();
        var currentMinute = (clockTime.hour * 60) + clockTime.min;
        return (currentMinute >= 390 && currentMinute <= 1170);
    }

    private function drawTopSunlightTube(dc as Graphics.Dc, isSunlit as Lang.Boolean) as Void {
        var tubeW = 116;
        var tubeH = 15;
        var tubeX = 82;                     // 140 - 58
        var tubeY = 42;                     // Center Y: 49.5

        var bracketW = 8;
        var bracketH = 17;
        var bracketY = tubeY - 1;

        var leftBx = tubeX - 4;
        var rightBx = tubeX + tubeW - bracketW + 4;

        var bracketColor = isSunlit ? COLOR_SUN_BRACKET : 0x282624;
        var bracketRim = isSunlit ? COLOR_SUN_BRACKET_RIM : 0x161618;
        var rivetColor = isSunlit ? COLOR_SUN_RIVET : 0x48423A;

        // Mounting Brackets
        dc.setColor(bracketColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(leftBx, bracketY, bracketW, bracketH, 2);
        dc.fillRoundedRectangle(rightBx, bracketY, bracketW, bracketH, 2);

        dc.setColor(bracketRim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(leftBx, bracketY, bracketW, bracketH, 2);
        dc.drawRoundedRectangle(rightBx, bracketY, bracketW, bracketH, 2);

        dc.setColor(rivetColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(leftBx + 3, bracketY + 3, 1);
        dc.fillCircle(leftBx + 3, bracketY + bracketH - 3, 1);
        dc.fillCircle(rightBx + bracketW - 3, bracketY + 3, 1);
        dc.fillCircle(rightBx + bracketW - 3, bracketY + bracketH - 3, 1);

        // Glass Capsule Body
        var cornerR = 5;
        if (isSunlit) {
            dc.setColor(0x061D2B, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(tubeX, tubeY, tubeW, tubeH, cornerR);

            dc.setColor(COLOR_SUN_HALO, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(6);
            dc.drawRoundedRectangle(tubeX, tubeY, tubeW, tubeH, cornerR);

            dc.setColor(COLOR_SUN_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawRoundedRectangle(tubeX, tubeY, tubeW, tubeH, cornerR);

            var wireY = tubeY + (tubeH / 2);
            var wireX1 = tubeX + bracketW - 2;
            var wireX2 = tubeX + tubeW - bracketW + 2;

            dc.setColor(COLOR_SUN_HALO, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(6);
            dc.drawLine(wireX1, wireY, wireX2, wireY);

            dc.setColor(COLOR_SUN_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(wireX1, wireY, wireX2, wireY);
            dc.drawCircle(_centerX, wireY, 5);

            dc.setColor(COLOR_SUN_CORE_HOT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(wireX1, wireY, wireX2, wireY);
            dc.drawCircle(_centerX, wireY, 2);

            dc.setColor(0xAAEEFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tubeX + 10, tubeY + 2, tubeX + tubeW - 10, tubeY + 2);
        } else {
            dc.setColor(COLOR_SUN_OFF_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(tubeX, tubeY, tubeW, tubeH, cornerR);

            dc.setColor(COLOR_SUN_OFF_RIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawRoundedRectangle(tubeX, tubeY, tubeW, tubeH, cornerR);

            var wireYOff = tubeY + (tubeH / 2);
            var wireX1Off = tubeX + bracketW - 2;
            var wireX2Off = tubeX + tubeW - bracketW + 2;

            dc.setColor(COLOR_SUN_OFF_WIRE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(wireX1Off, wireYOff, wireX2Off, wireYOff);
            dc.drawCircle(_centerX, wireYOff, 3);

            dc.setColor(0x182834, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tubeX + 10, tubeY + 2, tubeX + tubeW - 10, tubeY + 2);
        }
    }

    // =========================================================================
    // ROW 3: SUB-SCRIPT SECONDS ON RIGHT & SIDE ICONS
    // =========================================================================

    //! Sub-script seconds displayed on the RIGHT side of the minutes tubes, baseline aligned to bottom
    private function drawSubscriptSeconds(dc as Graphics.Dc, seconds as Lang.Number) as Void {
        // Minutes tube right edge is at X = 226, bottom is at Y = 175. Gap = 4 px.
        var x = 230;
        var y = 162;

        var secText = _isSleepMode ? "--" : seconds.format("%02d");
        var secColor = _isSleepMode ? 0x332211 : COLOR_TEXT_AMBER;

        dc.setColor(secColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            y,
            Graphics.FONT_SYSTEM_XTINY,
            secText,
            Graphics.TEXT_JUSTIFY_LEFT
        );
    }

    private function drawSideIcons(dc as Graphics.Dc) as Void {
        var settings = System.getDeviceSettings();
        var isConnected = settings.phoneConnected;
        var alarmCount = settings.alarmCount;
        var notifCount = settings.notificationCount;

        // --- Left Side: Bluetooth + Dynamic Alarm Icon (Centered at Y: 140) ---
        var bx = 32;
        var hasAlarm = (alarmCount != null && alarmCount > 0);

        if (hasAlarm) {
            // Stacked vertically around Y = 140: Bluetooth at Y: 131, Alarm Bell at Y: 149
            var colBt = isConnected ? COLOR_TEXT_CYAN : 0x222C32;
            drawBluetoothIcon(dc, bx, 131, colBt);
            drawBellIcon(dc, bx - 4, 144, COLOR_TEXT_AMBER);
        } else {
            // Centered Bluetooth at Y: 140
            var colBt = isConnected ? COLOR_TEXT_CYAN : 0x222C32;
            drawBluetoothIcon(dc, bx, 140, colBt);
        }

        // --- Right Side: Notification Status Icon (Moved to Y: 125, clear of seconds at Y: 162) ---
        var px = 248;
        var py = 125;
        if (notifCount != null && notifCount > 0) {
            drawNotificationIcon(dc, px, py, COLOR_TEXT_CYAN);
            dc.setColor(COLOR_TEXT_CYAN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + 4, py - 4, 2);
        } else {
            drawNotificationIcon(dc, px, py, 0x222C32);
        }
    }

    // =========================================================================
    // SEAMLESS STEPPED PYRAMID GRID (ZERO GAPS, INNER DIVIDERS ONLY - NO OUTER BORDER)
    // =========================================================================

    private function drawSeamlessGrid(dc as Graphics.Dc, isSunlit as Lang.Boolean) as Void {
        var ya = 202;
        var yb = 224;
        var yc = 246;
        var yd = 268;

        var xaL = 26;
        var xaR = 254;
        var xbL = 64;
        var xbR = 216;
        var xcL = 104;
        var xcR = 176;

        // 1. Fill base plates seamlessly (subtle dark cell fill, zero gaps)
        dc.setColor(COLOR_PLATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xaL, ya, xaR - xaL, yb - ya);
        dc.fillRectangle(xbL, yb, xbR - xbL, yc - yb);
        dc.fillRectangle(xcL, yc, xcR - xcL, yd - yc);

        // 2. Step 5: Thin dim dark-green INNER divider lines ONLY (NO outer border!)
        dc.setColor(COLOR_PLATE_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        // Row A vertical interior dividing lines
        dc.drawLine(102, ya, 102, yb); // Divider between Cell A1 and A2
        dc.drawLine(178, ya, 178, yb); // Divider between Cell A2 and A3

        // Shared horizontal divider between Row A and Row B (where they touch: 64 to 216)
        dc.drawLine(xbL, yb, xbR, yb);

        // Row B vertical interior dividing line
        dc.drawLine(140, yb, 140, yc); // Divider between Cell B1 and B2

        // Shared horizontal divider between Row B and Row C (where they touch: 104 to 176)
        dc.drawLine(xcL, yc, xcR, yc);

        // 3. Render Cell Contents (mathematically centered)
        var cyA = (ya + yb) / 2; // 213
        var cyB = (yb + yc) / 2; // 235
        var cyC = (yc + yd) / 2; // 257

        // Row A: 3 cells of 76 px
        drawMetricFieldInPlate(dc, 64, cyA, _slotMidLeft, isSunlit);
        drawMetricFieldInPlate(dc, 140, cyA, _slotMidCenter, isSunlit);
        drawMetricFieldInPlate(dc, 216, cyA, _slotMidRight, isSunlit);

        // Row B: 2 cells of 76 px
        drawMetricFieldInPlate(dc, 102, cyB, _slotLowerLeft, isSunlit);
        drawMetricFieldInPlate(dc, 178, cyB, _slotLowerRight, isSunlit);

        // Row C: 1 cell of 72 px (centered at X=140)
        drawMetricFieldInPlate(dc, 140, cyC, _slotBottom, isSunlit);
    }

    //! Draw metric icon + text strictly centered around (centerX, cy)
    private function drawMetricFieldInPlate(
        dc as Graphics.Dc,
        centerX as Lang.Number,
        cy as Lang.Number,
        metricType as Lang.Number,
        isSunlit as Lang.Boolean
    ) as Void {
        if (metricType == METRIC_NONE) {
            return;
        }

        var iconType = ICON_NONE;
        var text = "";
        var col = COLOR_TEXT_AMBER;
        var iconW = 12;

        switch (metricType) {
            case METRIC_ALTITUDE:
                iconType = ICON_ALTITUDE;
                text = getAltitudeString();
                col = COLOR_TEXT_CYAN;
                iconW = 14;
                break;

            case METRIC_WEATHER:
                iconType = ICON_WEATHER;
                text = getWeatherString();
                col = COLOR_TEXT_CYAN;
                iconW = 13;
                break;

            case METRIC_WEATHER_FEELS_LIKE:
                iconType = ICON_WEATHER;
                text = getWeatherFeelsLikeString();
                col = COLOR_TEXT_CYAN;
                iconW = 13;
                break;

            case METRIC_CALORIES:
                iconType = ICON_FLAME;
                text = getCalories().format("%d");
                col = COLOR_TEXT_ORANGE;
                iconW = 12;
                break;

            case METRIC_STEPS:
                iconType = ICON_STEPS;
                text = getSteps().format("%d");
                col = COLOR_TEXT_GREEN;
                iconW = 12;
                break;

            case METRIC_HEART_RATE:
                iconType = ICON_HEART;
                var hr = getHeartRate();
                text = (hr != null) ? hr.format("%d") : "--";
                col = COLOR_TEXT_RED;
                iconW = 13;
                break;

            case METRIC_DISTANCE:
                iconType = ICON_DISTANCE;
                text = getDistanceString();
                col = COLOR_TEXT_AMBER;
                iconW = 11;
                break;

            case METRIC_BODY_BATTERY:
                iconType = ICON_VITALITY;
                var bb = getBodyBattery();
                text = (bb != null) ? bb.format("%d") + "%" : "--%";
                col = COLOR_TEXT_GREEN;
                iconW = 12;
                break;

            case METRIC_BATTERY:
                iconType = ICON_BATTERY;
                text = getBatteryPercent().format("%d") + "%";
                col = COLOR_TEXT_AMBER;
                iconW = 14;
                break;

            case METRIC_ACTIVE_MINUTES:
                iconType = ICON_VITALITY;
                text = getActiveMinutes().format("%d") + "m";
                col = COLOR_TEXT_AMBER;
                iconW = 12;
                break;

            case METRIC_SUNRISE_SUNSET:
                iconType = ICON_WEATHER;
                text = getSunTimeString(isSunlit);
                col = isSunlit ? COLOR_TEXT_AMBER : COLOR_TEXT_CYAN;
                iconW = 13;
                break;

            case METRIC_FLOORS:
                iconType = ICON_STAIRS;
                text = getFloors().format("%d"); // Plain number, no "f" suffix
                col = COLOR_TEXT_GREEN;
                iconW = 12;
                break;
        }

        // Value text font: consistent FONT_SYSTEM_XTINY for all cells
        var font = Graphics.FONT_SYSTEM_XTINY;
        var textW = dc.getTextWidthInPixels(text, font);
        var gap = 4;
        var totalW = iconW + gap + textW;

        var startX = centerX - (totalW / 2);

        // Draw Vector Icon
        drawIcon(dc, startX, cy, iconType, col);

        // Draw Metric Text
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            startX + iconW + gap,
            cy,
            font,
            text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // =========================================================================
    // VECTOR ICON RENDERING SYSTEM
    // =========================================================================

    private function drawIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, iconType as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        switch (iconType) {
            case ICON_ALTITUDE:
                // Mountain icon (14x11 px)
                var my = cy - 5;
                dc.drawLine(x, my + 10, x + 14, my + 10);
                dc.drawLine(x + 1, my + 10, x + 5, my + 1);
                dc.drawLine(x + 5, my + 1, x + 9, my + 10);
                dc.drawLine(x + 8, my + 10, x + 11, my + 4);
                dc.drawLine(x + 11, my + 4, x + 14, my + 10);
                break;

            case ICON_WEATHER:
                // Cloud / Weather icon (13x10 px)
                var wy = cy - 5;
                dc.drawLine(x + 2, wy + 9, x + 11, wy + 9);
                dc.drawCircle(x + 4, wy + 6, 3);
                dc.drawCircle(x + 8, wy + 5, 4);
                dc.drawPoint(x + 11, wy + 2);
                break;

            case ICON_CALENDAR:
                drawCalendarIcon(dc, x, cy - 5, col);
                break;

            case ICON_BELL:
                drawBellIcon(dc, x, cy - 5, col);
                break;

            case ICON_BLUETOOTH:
                drawBluetoothIcon(dc, x, cy, col);
                break;

            case ICON_PHONE:
                drawPhoneIcon(dc, x, cy, col);
                break;

            case ICON_FLAME:
                // Enlarged multi-point flame icon with licking tongue & hot inner core (12x14 px)
                var fy = cy - 7;
                dc.setColor(COLOR_TEXT_ORANGE, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([
                    [x + 5, fy],
                    [x + 8, fy + 3],
                    [x + 11, fy + 7],
                    [x + 10, fy + 11],
                    [x + 7, fy + 13],
                    [x + 3, fy + 13],
                    [x + 1, fy + 10],
                    [x + 1, fy + 6],
                    [x + 4, fy + 4],
                    [x + 3, fy + 1]
                ]);
                dc.setColor(COLOR_TEXT_AMBER, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([
                    [x + 5, fy + 4],
                    [x + 8, fy + 8],
                    [x + 7, fy + 11],
                    [x + 4, fy + 11],
                    [x + 4, fy + 7]
                ]);
                break;

            case ICON_STEPS:
                // Footsteps icon (12x12 px)
                var sy = cy - 6;
                dc.fillRoundedRectangle(x, sy + 4, 4, 7, 1);
                dc.fillCircle(x + 2, sy + 2, 2);
                dc.fillRoundedRectangle(x + 7, sy, 4, 7, 1);
                dc.fillCircle(x + 9, sy + 9, 2);
                break;

            case ICON_HEART:
                // Heart icon (13x11 px)
                var hy = cy - 6;
                dc.fillCircle(x + 3, hy + 3, 3);
                dc.fillCircle(x + 9, hy + 3, 3);
                dc.fillPolygon([
                    [x, hy + 3],
                    [x + 12, hy + 3],
                    [x + 6, hy + 11]
                ]);
                break;

            case ICON_DISTANCE:
                // Location / Route pin icon (11x12 px)
                var dy = cy - 6;
                dc.drawCircle(x + 5, dy + 4, 4);
                dc.drawPoint(x + 5, dy + 4);
                dc.drawLine(x + 1, dy + 5, x + 5, dy + 11);
                dc.drawLine(x + 9, dy + 5, x + 5, dy + 11);
                break;

            case ICON_VITALITY:
                // Body Battery / Vitality human silhouette with energy core (12x14 px)
                drawVitalityIcon(dc, x, cy, col);
                break;

            case ICON_BATTERY:
                drawBatteryIcon(dc, x, cy - 4, getBatteryPercent(), isBatteryCharging(), col);
                break;

            case ICON_HAZARD:
                drawHazardIcon(dc, x, cy - 5, col);
                break;

            case ICON_STAIRS:
                // Ascending staircase icon (12x12 px)
                var sty = cy - 6;
                dc.fillRectangle(x, sty + 8, 3, 4);
                dc.fillRectangle(x + 4, sty + 4, 3, 8);
                dc.fillRectangle(x + 8, sty, 3, 12);
                break;
        }
    }

    private function drawVitalityIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        var hy = cy - 7;

        // Head
        dc.fillCircle(x + 6, hy + 2, 2);

        // Torso / shoulders silhouette
        dc.drawLine(x + 1, hy + 5, x + 11, hy + 5);
        dc.drawLine(x + 1, hy + 5, x + 2, hy + 11);
        dc.drawLine(x + 11, hy + 5, x + 10, hy + 11);
        dc.drawLine(x + 2, hy + 11, x + 6, hy + 13);
        dc.drawLine(x + 10, hy + 11, x + 6, hy + 13);

        // Glowing energy core inside chest
        dc.setColor(COLOR_TEXT_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + 6, hy + 4],
            [x + 4, hy + 8],
            [x + 6, hy + 7],
            [x + 5, hy + 11],
            [x + 8, hy + 7],
            [x + 6, hy + 7]
        ]);
    }

    private function drawBatteryIcon(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, bat as Lang.Number, charging as Lang.Boolean, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, 12, 8, 2);
        dc.fillRectangle(x + 12, y + 2, 2, 4);

        if (charging) {
            dc.drawLine(x + 7, y + 1, x + 4, y + 4);
            dc.drawLine(x + 4, y + 4, x + 8, y + 4);
            dc.drawLine(x + 8, y + 4, x + 5, y + 7);
        } else {
            var fillW = ((bat / 100.0) * 8).toNumber();
            if (fillW > 8) { fillW = 8; }
            if (fillW > 0) {
                dc.fillRectangle(x + 2, y + 2, fillW, 4);
            }
        }
    }

    private function drawCalendarIcon(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y + 2, 10, 8, 1);
        dc.fillRectangle(x + 1, y + 2, 8, 2);
        dc.drawLine(x + 2, y, x + 2, y + 3);
        dc.drawLine(x + 7, y, x + 7, y + 3);
        dc.drawPoint(x + 3, y + 6);
        dc.drawPoint(x + 6, y + 6);
    }

    private function drawBellIcon(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(x + 5, y + 4, 4, Graphics.ARC_CLOCKWISE, 180, 0);
        dc.drawLine(x + 1, y + 4, x, y + 7);
        dc.drawLine(x + 9, y + 4, x + 10, y + 7);
        dc.drawLine(x, y + 7, x + 10, y + 7);
        dc.drawPoint(x + 5, y + 9);
    }

    private function drawNotificationIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var my = cy - 4;
        dc.drawRoundedRectangle(x - 5, my, 10, 7, 2);
        dc.drawLine(x - 3, my + 7, x - 1, my + 9);
        dc.drawLine(x - 1, my + 9, x - 1, my + 7);
    }

    private function drawBluetoothIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x, cy - 6, x, cy + 6);
        dc.drawLine(x - 3, cy - 3, x + 3, cy + 3);
        dc.drawLine(x + 3, cy + 3, x, cy + 6);
        dc.drawLine(x - 3, cy + 3, x + 3, cy - 3);
        dc.drawLine(x + 3, cy - 3, x, cy - 6);
    }

    private function drawPhoneIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x - 4, cy - 6, 8, 12, 2);
        dc.fillRectangle(x - 2, cy - 4, 5, 7);
        dc.drawPoint(x, cy + 4);
    }

    private function drawHazardIcon(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.fillPolygon([
            [x + 5, y],
            [x + 9, y + 8],
            [x + 1, y + 8]
        ]);
        dc.setColor(COLOR_PLATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.drawPoint(x + 5, y + 4);
        dc.drawPoint(x + 5, y + 6);
    }

    // =========================================================================
    // 7-SEGMENT NIXIE TUBE RENDERING (HH:MM AT Y: 105-175, W: 38, H: 70)
    // =========================================================================

    private function drawNixieTube(
        dc as Graphics.Dc,
        tubeIndex as Lang.Number,
        x as Lang.Number,
        y as Lang.Number,
        w as Lang.Number,
        h as Lang.Number,
        digit as Lang.Number
    ) as Void {
        // 1. Metal base socket at bottom
        dc.setColor(COLOR_SOCKET_BASE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + 3, y + h - 3, w - 6, 7, 2);
        dc.setColor(COLOR_SOCKET_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x + 3, y + h - 3, w - 6, 7, 2);

        // 2. Glass Tube Body: Dark interior cavity
        dc.setColor(COLOR_TUBE_GLASS_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 8);

        // 3. Wire Anode Mesh Grid (Crosshatch pattern inside the tube)
        dc.setColor(COLOR_MESH_GRID, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var my = y + 8; my < y + h - 6; my += 6) {
            dc.drawLine(x + 4, my, x + w - 4, my);
        }
        for (var mx = x + 5; mx < x + w - 4; mx += 5) {
            dc.drawLine(mx, y + 8, mx, y + h - 6);
        }

        // 4. Glass Capsule Border
        dc.setColor(COLOR_TUBE_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, y, w, h, 8);

        // 5. Classic 7-Segment Digit Rendering
        var mask = (digit >= 0 && digit <= 9) ? SEGMENT_MASKS[digit] : 0;
        var polys = _tubePolygons != null ? _tubePolygons[tubeIndex] : null;
        var spines = _tubeSpines != null ? _tubeSpines[tubeIndex] : null;

        if (polys != null && spines != null) {
            // Pass A: Unlit Ghost Segments for all unlit segments (faint "8" background)
            dc.setColor(COLOR_GHOST_FILAMENT, Graphics.COLOR_TRANSPARENT);
            for (var s = 0; s < 7; s++) {
                if ((mask & (1 << s)) == 0) {
                    dc.fillPolygon(polys[s]);
                }
            }

            // Pass B: Lit Segments with Multi-Pass Neon Glow
            if (mask != 0) {
                // Pass 1: Outer glowing plasma halo around lit segments
                dc.setColor(COLOR_HALO_OUTER, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(7);
                for (var s = 0; s < 7; s++) {
                    if ((mask & (1 << s)) != 0) {
                        var sp = spines[s];
                        dc.drawLine(sp[0], sp[1], sp[2], sp[3]);
                    }
                }

                // Pass 2: Bright neon-orange mid glow (beveled hexagon polygon body)
                dc.setColor(COLOR_GLOW_MID, Graphics.COLOR_TRANSPARENT);
                for (var s = 0; s < 7; s++) {
                    if ((mask & (1 << s)) != 0) {
                        dc.fillPolygon(polys[s]);
                    }
                }

                // Pass 3: White-hot core filament spine
                dc.setColor(COLOR_CORE_HOT, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
                for (var s = 0; s < 7; s++) {
                    if ((mask & (1 << s)) != 0) {
                        var sp = spines[s];
                        dc.drawLine(sp[0], sp[1], sp[2], sp[3]);
                    }
                }
            }
        }

        // 6. Glass Specular Reflections (Left edge highlight streak and top shoulder)
        dc.setColor(COLOR_TUBE_HIGHLIGHT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x + 2, y + 10, x + 2, y + h - 10);
        dc.drawArc(x + 8, y + 8, 5, Graphics.ARC_CLOCKWISE, 180, 90);
    }

    private function drawColonIndicator(dc as Graphics.Dc) as Void {
        var colonX = 140;
        var bulbYCoords = [126, 154];

        for (var i = 0; i < 2; i++) {
            var cy = bulbYCoords[i];

            dc.setColor(COLOR_TUBE_GLASS_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(colonX - 3, cy - 5, 6, 10, 2);
            dc.setColor(COLOR_TUBE_BORDER, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawRoundedRectangle(colonX - 3, cy - 5, 6, 10, 2);

            dc.setColor(COLOR_HALO_OUTER, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(colonX, cy, 3);
            dc.setColor(COLOR_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(colonX, cy, 2);
            dc.setColor(COLOR_CORE_HOT, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(colonX, cy, 1);
        }
    }

    // =========================================================================
    // PCB BACKGROUND DRAWING (MUTED, DARKER, ONLY OUTSIDE GRID!)
    // =========================================================================

    private function drawPcbBackground(dc as Graphics.Dc) as Void {
        dc.setColor(COLOR_PCB_BG, COLOR_PCB_BG);
        dc.clear();

        dc.setColor(COLOR_PCB_TRACE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1); // Thinner traces

        // Top rails feeding battery & sunlight tube
        dc.drawLine(96, 25, 96, 42);
        dc.drawLine(184, 25, 184, 42);

        // Side bus traces around side status icons
        dc.drawLine(25, 120, 25, 160);
        dc.drawLine(255, 100, 255, 140);

        // Traces in the transition area between Time and Grid (Y: 180 - 200)
        dc.drawLine(64, 188, 216, 188);
        dc.drawLine(64, 188, 64, 196);
        dc.drawLine(216, 188, 216, 196);

        // Side traces outside Row B and C
        dc.drawLine(48, 224, 48, 246);
        dc.drawLine(232, 224, 232, 246);

        // Solder Vias with copper pads (uses static table to prevent allocations)
        for (var i = 0; i < VIA_COORDS.size(); i++) {
            var vx = VIA_COORDS[i][0];
            var vy = VIA_COORDS[i][1];
            dc.setColor(COLOR_PCB_VIA_PAD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(vx, vy, 2);
            dc.setColor(COLOR_PCB_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(vx, vy, 1);
        }

        // Silkscreen technical markings
        dc.setColor(COLOR_PCB_SILK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        drawFiducial(dc, 24, 140);
    }

    private function drawFiducial(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number) as Void {
        dc.drawLine(x - 3, y, x + 3, y);
        dc.drawLine(x, y - 3, x, y + 3);
        dc.drawCircle(x, y, 2);
    }

    // =========================================================================
    // DATA METRIC PROVIDERS
    // =========================================================================

    private function getAltitudeString() as Lang.String {
        var altMeters = null;
        if (Toybox has :Activity && Activity has :getActivityInfo) {
            var info = Activity.getActivityInfo();
            if (info != null && info.altitude != null) {
                altMeters = info.altitude;
            }
        }
        if (altMeters == null && Toybox has :SensorHistory && SensorHistory has :getElevationHistory) {
            try {
                var elIter = SensorHistory.getElevationHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
                if (elIter != null) {
                    var sample = elIter.next();
                    if (sample != null && sample.data != null) {
                        altMeters = (sample.data as Lang.Number).toFloat();
                    }
                }
            } catch (e) {
                // Ignore
            }
        }

        if (altMeters != null) {
            var settings = System.getDeviceSettings();
            var isMetric = true;
            if (settings has :elevationUnits && settings.elevationUnits == System.UNIT_STATUTE) {
                isMetric = false;
            }
            if (isMetric) {
                return Lang.format("$1$m", [altMeters.toNumber()]);
            } else {
                var feet = altMeters * 3.28084;
                return Lang.format("$1$ft", [feet.toNumber()]);
            }
        }
        return "--m";
    }

    private function getWeatherString() as Lang.String {
        if (Toybox has :Weather && Weather has :getCurrentConditions) {
            try {
                var conditions = Weather.getCurrentConditions();
                if (conditions != null && conditions.temperature != null) {
                    var temp = conditions.temperature;
                    var settings = System.getDeviceSettings();
                    var isMetric = true;
                    if (settings has :temperatureUnits && settings.temperatureUnits == System.UNIT_STATUTE) {
                        isMetric = false;
                    }
                    if (!isMetric) {
                        temp = (temp * 9 / 5) + 32;
                        return Lang.format("$1$°F", [temp.toNumber()]);
                    } else {
                        return Lang.format("$1$°C", [temp.toNumber()]);
                    }
                }
            } catch (e) {
                // Weather pending
            }
        }
        return "--°";
    }

    //! Temperature + feels-like temperature (e.g. "21° / 19°")
    private function getWeatherFeelsLikeString() as Lang.String {
        if (Toybox has :Weather && Weather has :getCurrentConditions) {
            try {
                var conditions = Weather.getCurrentConditions();
                if (conditions != null) {
                    var temp = conditions.temperature;
                    var feels = (conditions has :feelsLikeTemperature) ? conditions.feelsLikeTemperature : null;
                    var settings = System.getDeviceSettings();
                    var isMetric = true;
                    if (settings has :temperatureUnits && settings.temperatureUnits == System.UNIT_STATUTE) {
                        isMetric = false;
                    }

                    if (temp != null) {
                        var tempVal = isMetric ? temp.toNumber() : ((temp * 9 / 5) + 32).toNumber();
                        if (feels != null) {
                            var feelsVal = isMetric ? feels.toNumber() : ((feels * 9 / 5) + 32).toNumber();
                            return Lang.format("$1$°/$2$°", [tempVal, feelsVal]);
                        } else {
                            return Lang.format("$1$°/--°", [tempVal]);
                        }
                    }
                }
            } catch (e) {
                // Weather pending
            }
        }
        return "--°/--°";
    }

    private function getBodyBattery() as Lang.Number? {
        if (Toybox has :SensorHistory && SensorHistory has :getBodyBatteryHistory) {
            try {
                var bbIter = SensorHistory.getBodyBatteryHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
                if (bbIter != null) {
                    var sample = bbIter.next();
                    if (sample != null && sample.data != null) {
                        return sample.data as Lang.Number;
                    }
                }
            } catch (e) {
                // Ignore
            }
        }
        return null;
    }

    private function getHeartRate() as Lang.Number? {
        if (Toybox has :Activity && Activity has :getActivityInfo) {
            var activityInfo = Activity.getActivityInfo();
            if (activityInfo != null && activityInfo.currentHeartRate != null) {
                return activityInfo.currentHeartRate;
            }
        }
        if (Toybox has :SensorHistory && SensorHistory has :getHeartRateHistory) {
            try {
                var hrIter = SensorHistory.getHeartRateHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
                if (hrIter != null) {
                    var sample = hrIter.next();
                    if (sample != null && sample.data != null) {
                        return sample.data as Lang.Number;
                    }
                }
            } catch (e) {
                // Ignore
            }
        }
        return null;
    }

    private function getBatteryPercent() as Lang.Number {
        var stats = System.getSystemStats();
        return stats.battery.toNumber();
    }

    private function isBatteryCharging() as Lang.Boolean {
        var stats = System.getSystemStats();
        if (stats has :charging && stats.charging != null) {
            return stats.charging as Lang.Boolean;
        }
        return false;
    }

    private function getSteps() as Lang.Number {
        if (Toybox has :ActivityMonitor && ActivityMonitor has :getInfo) {
            var info = ActivityMonitor.getInfo();
            if (info != null && info.steps != null) {
                return info.steps;
            }
        }
        return 0;
    }

    private function getCalories() as Lang.Number {
        if (Toybox has :ActivityMonitor && ActivityMonitor has :getInfo) {
            var info = ActivityMonitor.getInfo();
            if (info != null && info.calories != null) {
                return info.calories;
            }
        }
        return 0;
    }

    private function getDistanceString() as Lang.String {
        if (Toybox has :ActivityMonitor && ActivityMonitor has :getInfo) {
            var info = ActivityMonitor.getInfo();
            if (info != null && info.distance != null) {
                var distCm = info.distance;
                var isMetric = true;
                var settings = System.getDeviceSettings();
                if (settings has :distanceUnits && settings.distanceUnits == System.UNIT_STATUTE) {
                    isMetric = false;
                }
                if (isMetric) {
                    var km = distCm / 100000.0;
                    return Lang.format("$1$ km", [km.format("%.1f")]);
                } else {
                    var mi = distCm / 160934.4;
                    return Lang.format("$1$ mi", [mi.format("%.1f")]);
                }
            }
        }
        return "-- km";
    }

    private function getSunTimeString(isSunlit as Lang.Boolean) as Lang.String {
        if (Toybox has :Weather && Weather has :getSunrise && Weather has :getSunset) {
            try {
                var conditions = Weather.getCurrentConditions();
                if (conditions != null && conditions.observationLocationPosition != null) {
                    var now = Time.now();
                    var loc = conditions.observationLocationPosition as Position.Location;
                    var nextEvent = isSunlit ? Weather.getSunset(loc, now) : Weather.getSunrise(loc, now);
                    if (nextEvent != null) {
                        var info = Gregorian.info(nextEvent, Time.FORMAT_SHORT);
                        return Lang.format("$1$:$2$", [
                            info.hour.format("%02d"),
                            info.min.format("%02d")
                        ]);
                    }
                }
            } catch (e) {
                // Fallback
            }
        }
        return isSunlit ? "19:30" : "06:30";
    }

    private function getActiveMinutes() as Lang.Number {
        if (Toybox has :ActivityMonitor && ActivityMonitor has :getInfo) {
            var info = ActivityMonitor.getInfo();
            if (info != null && info.activeMinutesDay != null && info.activeMinutesDay.total != null) {
                return info.activeMinutesDay.total;
            }
        }
        return 0;
    }

    private function getFloors() as Lang.Number {
        if (Toybox has :ActivityMonitor && ActivityMonitor has :getInfo) {
            var info = ActivityMonitor.getInfo();
            if (info != null && info.floorsClimbed != null) {
                return info.floorsClimbed;
            }
        }
        return 0;
    }

    // =========================================================================
    // CHASSIS BOLTS (PERIMETER CORNER SCREWS)
    // =========================================================================

    private function drawChassisBolts(dc as Graphics.Dc) as Void {
        dc.setPenWidth(1);
        for (var i = 0; i < CHASSIS_BOLTS.size(); i++) {
            var bx = CHASSIS_BOLTS[i][0];
            var by = CHASSIS_BOLTS[i][1];

            dc.setColor(COLOR_SCREW_RIM, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, 5);

            dc.setColor(COLOR_SCREW_HEAD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, 3);

            dc.setColor(COLOR_SCREW_SLOT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(bx - 2, by - 2, bx + 2, by + 2);
        }
    }
}
