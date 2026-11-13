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
//!    Date (Center Y = 81): DD.MM.YY, WEEKDAY in muted amber above the clock
//! 3. Row 3 (Y: 100-180, Center Y = 140): Centered 7-segment Nixie clock (HH:MM, 42x80), INS-1 colon bulbs, sub-script seconds on right (X=240, Y=167), side icons
//! 4. Seamless Stepped Pyramid Grid (Y: 190-268, Zero gaps, shared 1px inner dividers, no outer border):
//!    - Row A (Y: 190-216, Center Y = 203, 3 cells): Floors | Heart Rate | Weather & Feels-like
//!    - Row B (Y: 216-242, Center Y = 229, 2 cells): Steps | Calories
//!    - Row C (Y: 242-268, Center Y = 255, 1 cell): Body Battery (8-10px from bottom display edge)
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

    // Display geometry (280x280 for fenix7x) - see ThemeConstants
    private var _screenW as Lang.Number = SCREEN_W;
    private var _centerX as Lang.Number = CENTER_X;

    // Centered Nixie tube layout (Y: 100-180, Center Y = 140) - see ThemeConstants
    private var _tubeW as Lang.Number = TUBE_W;
    private var _tubeH as Lang.Number = TUBE_H;
    private var _tubeY as Lang.Number = TUBE_Y;
    private var _tubeXs as Lang.Array<Lang.Number> = TUBE_XS;

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

    // ------------------------------------------------------------------
    // Centralized Theme Constants (colors, dimensions, fonts)
    // ------------------------------------------------------------------
    // Nixie Tube Color Palette (Orange-Amber Glow)
    static const COLOR_HALO_OUTER      = 0x882200; // Deep glowing red-orange plasma halo
    static const COLOR_GLOW_MID        = 0xFF5500; // Bright neon orange
    static const COLOR_CORE_HOT        = 0xFFFF66; // White-hot filament center
    static const COLOR_GHOST_FILAMENT  = 0x22140A; // Dim unlit cathode wire in background
    static const COLOR_TUBE_GLASS_BG   = 0x0A0D0B; // Deep dark cavity inside tube
    static const COLOR_TUBE_BORDER     = 0x38423E; // Outer glass capsule rim
    static const COLOR_TUBE_HIGHLIGHT  = 0x587880; // Specular glass reflection
    static const COLOR_MESH_GRID       = 0x1A221C; // Anode wire mesh grid
    static const COLOR_SOCKET_BASE     = 0x1F2426; // Stamped metal socket base
    static const COLOR_SOCKET_BORDER   = 0x101314; // Socket outline

    // Top Sunlight Neon Tube Palette (Electric Cyan & Ice-Blue Glow)
    static const COLOR_SUN_HALO        = 0x0055AA; // Brilliant electric cobalt bloom
    static const COLOR_SUN_GLOW_MID    = 0x00CCFF; // Vibrant neon cyan beam
    static const COLOR_SUN_CORE_HOT    = 0xFFFFFF; // White-hot center filament
    static const COLOR_SUN_OFF_BG      = 0x0A1014; // Dark cavity when unlit
    static const COLOR_SUN_OFF_RIM     = 0x2A343A; // Unlit glass border
    static const COLOR_SUN_OFF_WIRE    = 0x222C32; // Unlit grey tungsten wire
    static const COLOR_SUN_BRACKET     = 0x5A4830; // Stamped copper bracket
    static const COLOR_SUN_BRACKET_RIM = 0x382C1E; // Bracket outline
    static const COLOR_SUN_RIVET       = 0x9C7E4C; // Copper rivets

    // PCB Background Colors (Muted, Darker Outside Traces)
    static const COLOR_PCB_BG          = 0x08100C; // Dark industrial solder mask
    static const COLOR_PCB_TRACE       = 0x122418; // Muted, dark copper/green trace
    static const COLOR_PCB_VIA_PAD     = 0x3A3218; // Muted gold solder via pad
    static const COLOR_PCB_SILK        = 0x233428; // Silkscreen markings
    static const COLOR_SCREW_RIM       = 0x40454A; // Perimeter chassis screw rim
    static const COLOR_SCREW_HEAD      = 0x282C30; // Screw head face
    static const COLOR_SCREW_SLOT      = 0x101214; // Screw drive slot

    // Tactical Plates & Phosphor Text Colors
    static const COLOR_PLATE_BG        = 0x0C1410; // Dark stamped plate
    static const COLOR_PLATE_BORDER    = 0x24362A; // Single 1px border rim
    static const COLOR_TEXT_AMBER      = 0xD1A568; // Shared muted amber for date, metrics & status icons
    static const COLOR_TEXT_DIM        = 0x34291A; // Dim amber for inactive indicators

    // Display Geometry (280x280 for fenix7x)
    static const SCREEN_W              = 280;
    static const CENTER_X              = 140;

    // Larger tubes centered at (140, 140), clear of date, side icons and grid.
    static const TUBE_W                = 42;
    static const TUBE_H                = 80;
    static const TUBE_Y                = 100;
    static const TUBE_XS               = [44, 90, 148, 194];

    // Pre-allocated per-tube segment polygons & spine lines (zero GC allocations in onUpdate)
    private var _tubePolygons as Lang.Array<Lang.Array<Lang.Array<[Lang.Numeric, Lang.Numeric]> > >?;
    private var _tubeSpines as Lang.Array<Lang.Array<Lang.Array<Lang.Number> > >?;
    private var _digitsCache as Lang.Array<Lang.Number> = [0, 0, 0, 0];

    // Gregorian FORMAT_SHORT weekdays are numbered Sunday (1) through Saturday (7).
    private const DATE_WEEKDAYS = [
        "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"
    ];
    private var _displayFont as Graphics.FontType = Graphics.FONT_SYSTEM_XTINY;
    private var _dateKey as Lang.Number = -1;
    private var _dateText as Lang.String = "";

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
        // Cache the bitmap font once per layout; no runtime font scaling.
        _displayFont = WatchUi.loadResource(Rez.Fonts.MetroReadable) as WatchUi.FontResource;

        _tubeW = TUBE_W;
        _tubeH = TUBE_H;
        _tubeY = TUBE_Y;
        _tubeXs = TUBE_XS;

        // Anti-aliasing capability is device-level and does not change at runtime,
        // so enable it once here rather than every frame in onUpdate().
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // Scale the original 26x52 geometry once, keeping updates allocation-free.
        var digitW = 32;
        var digitH = 64;
        var dxOff = (_tubeW - digitW) / 2; // 5
        var dyOff = (_tubeH - digitH) / 2; // 8

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
                    poly[p] = [
                        ((basePoly[p][0] * digitW + 13) / 26).toNumber() + ox,
                        ((basePoly[p][1] * digitH + 26) / 52).toNumber() + oy
                    ];
                }
                segList[s] = poly;

                var baseSp = BASE_SPINE_LINES[s] as Lang.Array<Lang.Number>;
                spList[s] = [
                    ((baseSp[0] * digitW + 13) / 26).toNumber() + ox,
                    ((baseSp[1] * digitH + 26) / 52).toNumber() + oy,
                    ((baseSp[2] * digitW + 13) / 26).toNumber() + ox,
                    ((baseSp[3] * digitH + 26) / 52).toNumber() + oy
                ];
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

        // 1. Draw Integrated PCB Background Grid Frame (Muted, Outside Only)
        drawPcbBackground(dc);

        // 2. Row 1: Centralized Top Battery Icon + Percentage (Y: ~8-16, Center Y = 12)
        drawTopBattery(dc);

        // 3. Row 2: Wider & Taller Sunlight / Ambient Tube Directly Below Battery (Y: ~25-38, Center Y = 31)
        drawTopSunlightTube(dc, isSolarLampLit());

        // Centered in the free space between the sunlight glow and Nixie tubes.
        drawDate(dc);

        // 4. Nixie Clock (HH:MM) + INS-1 Colon + Seconds + Side Icons (Y: 100-180)
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
        // The sunrise/sunset metric follows daylight, independently of the
        // solar lamp (which can be dark indoors even during the day).
        drawSeamlessGrid(dc, isDaylight());

        // 6. Outer Industrial Chassis Bolts (Corner Screws)
        drawChassisBolts(dc);
    }

    //! Refresh the formatted string only when the local calendar date changes.
    private function drawDate(dc as Graphics.Dc) as Void {
        var date = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateKey = date.year * 10000 + date.month * 100 + date.day;
        if (dateKey != _dateKey) {
            _dateText = Lang.format("$1$.$2$.$3$, $4$", [
                date.day.format("%02d"),
                date.month.format("%02d"),
                (date.year % 100).format("%02d"),
                DATE_WEEKDAYS[date.day_of_week - 1]
            ]);
            _dateKey = dateKey;
        }

        dc.setColor(COLOR_TEXT_AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _centerX, 81, _displayFont, _dateText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // =========================================================================
    // ROW 1: CENTRALIZED TOP BATTERY (Center Y = 25)
    // =========================================================================

    private function drawTopBattery(dc as Graphics.Dc) as Void {
        var bat = getBatteryPercent();
        var charging = isBatteryCharging();

        var text = Lang.format("$1$%", [bat]);
        var textW = dc.getTextWidthInPixels(text, _displayFont);

        var iconW = 18;
        var gap = 4;
        var totalW = iconW + gap + textW;

        var startX = _centerX - (totalW / 2);
        var cy = 25;

        var col = COLOR_TEXT_AMBER;
        drawBatteryIcon(dc, startX, cy - 5, bat, charging, col);

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            startX + iconW + gap,
            cy,
            _displayFont,
            text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // =========================================================================
    // ROW 2: BIGGER SUNLIGHT TUBE (W: 116, H: 15, X: 82-198, Y: 42-57, Center Y = 49.5)
    // =========================================================================

    public function toggleDebugSunlight() as Void {
        // Automatic mode must always follow the sensor on the real watch.
        // Touch toggling is reserved for explicitly selected simulation modes.
        if (_sunlightMode == 0) {
            return;
        }
        if (_debugSunlightOverride == null) {
            _debugSunlightOverride = !isSolarLampLit();
        } else {
            _debugSunlightOverride = !_debugSunlightOverride;
        }
        WatchUi.requestUpdate();
    }

    private function isSolarLampLit() as Lang.Boolean {
        if (_sunlightMode == 1 || _sunlightMode == 2) {
            if (_debugSunlightOverride != null) {
                return _debugSunlightOverride as Lang.Boolean;
            }
            return _sunlightMode == 1;
        }

        // solarIntensity measures solar charge efficiency, not ambient lux.
        // Null means unsupported; a negative value means no solar charging.
        // Do not substitute sunrise/sunset when there is no measured input.
        var stats = System.getSystemStats();
        if (stats has :solarIntensity) {
            var intensity = stats.solarIntensity;
            return intensity != null && intensity > 0;
        }
        return false;
    }

    private function isDaylight() as Lang.Boolean {
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
        // Follow the enlarged minutes tube with the original 4 px gap/alignment.
        var x = _tubeXs[3] + _tubeW + 4;
        var y = _tubeY + _tubeH - 13;

        var secText = _isSleepMode ? "--" : seconds.format("%02d");
        var secColor = _isSleepMode ? 0x332211 : 0xFFAA00;

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

        // --- Left Side: Bluetooth + Alarm Status (fixed positions) ---
        var bx = 32;
        var hasAlarm = (alarmCount != null && alarmCount > 0);
        var colBt = isConnected ? COLOR_TEXT_AMBER : COLOR_TEXT_DIM;
        var colAlarm = hasAlarm ? COLOR_TEXT_AMBER : COLOR_TEXT_DIM;
        // Bluetooth spans Y=123-139; bell Y=143-154, clear of the clock at X=44.
        // Read alarmCount on each normal update so changes need no extra timer.
        drawBluetoothIcon(dc, bx, 131, colBt);
        drawBellIcon(dc, bx - 6, 143, colAlarm);

        // --- Right Side: Notification Status Icon (Y=125, clear of seconds at Y=167) ---
        var px = 248;
        var py = 125;
        if (notifCount != null && notifCount > 0) {
            drawNotificationIcon(dc, px, py, COLOR_TEXT_AMBER);
            dc.setColor(COLOR_TEXT_AMBER, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + 6, py - 6, 2);
        } else {
            drawNotificationIcon(dc, px, py, COLOR_TEXT_DIM);
        }
    }

    // =========================================================================
    // SEAMLESS STEPPED PYRAMID GRID (ZERO GAPS, INNER DIVIDERS ONLY - NO OUTER BORDER)
    // =========================================================================

    private function drawSeamlessGrid(dc as Graphics.Dc, isSunlit as Lang.Boolean) as Void {
        var ya = 190;
        var yb = 216;
        var yc = 242;
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
        var cyA = (ya + yb) / 2; // 203
        var cyB = (yb + yc) / 2; // 229
        var cyC = (yc + yd) / 2; // 255

        // Row A: 3 cells of 76 px
        drawMetricFieldInPlate(dc, 64, cyA, _slotMidLeft, isSunlit, 76);
        drawMetricFieldInPlate(dc, 140, cyA, _slotMidCenter, isSunlit, 76);
        drawMetricFieldInPlate(dc, 216, cyA, _slotMidRight, isSunlit, 76);

        // Row B: 2 cells of 76 px
        drawMetricFieldInPlate(dc, 102, cyB, _slotLowerLeft, isSunlit, 76);
        drawMetricFieldInPlate(dc, 178, cyB, _slotLowerRight, isSunlit, 76);

        // Row C: 1 cell of 72 px (centered at X=140)
        drawMetricFieldInPlate(dc, 140, cyC, _slotBottom, isSunlit, 72);
    }

    //! Draw metric icon + text strictly centered around (centerX, cy)
    private function drawMetricFieldInPlate(
        dc as Graphics.Dc,
        centerX as Lang.Number,
        cy as Lang.Number,
        metricType as Lang.Number,
        isSunlit as Lang.Boolean,
        cellWidth as Lang.Number
    ) as Void {
        if (metricType == METRIC_NONE) {
            return;
        }

        var iconType = ICON_NONE;
        var text = "";
        var col = COLOR_TEXT_AMBER;
        var iconW = 15;

        switch (metricType) {
            case METRIC_ALTITUDE:
                iconType = ICON_ALTITUDE;
                text = getAltitudeString();
                iconW = 18;
                break;

            case METRIC_WEATHER:
                iconType = ICON_WEATHER;
                text = getWeatherString();
                iconW = 16;
                break;

            case METRIC_WEATHER_FEELS_LIKE:
                iconType = ICON_WEATHER;
                text = getWeatherFeelsLikeString();
                iconW = 16;
                break;

            case METRIC_CALORIES:
                iconType = ICON_FLAME;
                text = getCalories().format("%d");
                iconW = 15;
                break;

            case METRIC_STEPS:
                iconType = ICON_STEPS;
                text = getSteps().format("%d");
                iconW = 15;
                break;

            case METRIC_HEART_RATE:
                iconType = ICON_HEART;
                var hr = getHeartRate();
                text = (hr != null) ? hr.format("%d") : "--";
                iconW = 16;
                break;

            case METRIC_DISTANCE:
                iconType = ICON_DISTANCE;
                text = getDistanceString();
                iconW = 14;
                break;

            case METRIC_BODY_BATTERY:
                iconType = ICON_VITALITY;
                var bb = getBodyBattery();
                text = (bb != null) ? bb.format("%d") + "%" : "--%";
                iconW = 15;
                break;

            case METRIC_BATTERY:
                iconType = ICON_BATTERY;
                text = getBatteryPercent().format("%d") + "%";
                iconW = 18;
                break;

            case METRIC_ACTIVE_MINUTES:
                iconType = ICON_VITALITY;
                text = getActiveMinutes().format("%d") + "m";
                iconW = 15;
                break;

            case METRIC_SUNRISE_SUNSET:
                iconType = ICON_WEATHER;
                text = getSunTimeString(isSunlit);
                iconW = 16;
                break;

            case METRIC_FLOORS:
                iconType = ICON_STAIRS;
                text = getFloors().format("%d"); // Plain number, no "f" suffix
                iconW = 15;
                break;
        }

        // Prefer larger text, then fall back for long weather/distance readings.
        var font = _displayFont;
        var textW = dc.getTextWidthInPixels(text, font);
        var gap = 3;
        var availableW = cellWidth - 4; // Keep 2 px clear of each divider.
        if (iconW + gap + textW > availableW) {
            font = Graphics.FONT_SYSTEM_XTINY;
            textW = dc.getTextWidthInPixels(text, font);
        }
        if (iconW + gap + textW > availableW) {
            // Give unusually long readings the full cell instead of overlapping.
            iconType = ICON_NONE;
            iconW = 0;
            gap = 0;
        }
        if (textW > availableW) {
            // Bound extreme values too; normal readings retain their full value.
            var shortened = text;
            do {
                shortened = shortened.substring(0, shortened.length() - 1);
                text = shortened + "...";
                textW = dc.getTextWidthInPixels(text, font);
            } while (textW > availableW && shortened.length() > 0);
        }
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
                // Mountain icon (19x14 px)
                var my = cy - 6;
                dc.drawLine(x, my + 13, x + 18, my + 13);
                dc.drawLine(x + 1, my + 13, x + 6, my + 1);
                dc.drawLine(x + 6, my + 1, x + 11, my + 13);
                dc.drawLine(x + 10, my + 13, x + 14, my + 5);
                dc.drawLine(x + 14, my + 5, x + 18, my + 13);
                break;

            case ICON_WEATHER:
                // Cloud / Weather icon (16x14 px)
                var wy = cy - 6;
                dc.drawLine(x + 3, wy + 11, x + 14, wy + 11);
                dc.drawCircle(x + 5, wy + 8, 4);
                dc.drawCircle(x + 10, wy + 6, 5);
                dc.drawPoint(x + 14, wy + 3);
                break;

            case ICON_CALENDAR:
                drawCalendarIcon(dc, x, cy - 6, col);
                break;

            case ICON_BELL:
                drawBellIcon(dc, x, cy - 6, col);
                break;

            case ICON_BLUETOOTH:
                drawBluetoothIcon(dc, x, cy, col);
                break;

            case ICON_PHONE:
                drawPhoneIcon(dc, x, cy, col);
                break;

            case ICON_FLAME:
                // Enlarged multi-point flame icon with licking tongue & inner core (15x17 px)
                var fy = cy - 9;
                dc.setColor(COLOR_TEXT_AMBER, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([
                    [x + 6, fy],
                    [x + 10, fy + 4],
                    [x + 14, fy + 9],
                    [x + 13, fy + 14],
                    [x + 9, fy + 16],
                    [x + 4, fy + 16],
                    [x + 1, fy + 13],
                    [x + 1, fy + 8],
                    [x + 5, fy + 5],
                    [x + 4, fy + 1]
                ]);
                dc.setColor(COLOR_TEXT_AMBER, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([
                    [x + 6, fy + 5],
                    [x + 10, fy + 10],
                    [x + 9, fy + 14],
                    [x + 5, fy + 14],
                    [x + 5, fy + 9]
                ]);
                break;

            case ICON_STEPS:
                // Footsteps icon (15x15 px)
                var sy = cy - 8;
                dc.fillRoundedRectangle(x, sy + 5, 5, 9, 1);
                dc.fillCircle(x + 3, sy + 3, 3);
                dc.fillRoundedRectangle(x + 9, sy, 5, 9, 1);
                dc.fillCircle(x + 11, sy + 11, 3);
                break;

            case ICON_HEART:
                // Heart icon (16x15 px)
                var hy = cy - 8;
                dc.fillCircle(x + 4, hy + 4, 4);
                dc.fillCircle(x + 11, hy + 4, 4);
                dc.fillPolygon([
                    [x, hy + 4],
                    [x + 15, hy + 4],
                    [x + 8, hy + 14]
                ]);
                break;

            case ICON_DISTANCE:
                // Location / Route pin icon (14x15 px)
                var dy = cy - 8;
                dc.drawCircle(x + 6, dy + 5, 5);
                dc.drawPoint(x + 6, dy + 5);
                dc.drawLine(x + 1, dy + 6, x + 6, dy + 14);
                dc.drawLine(x + 11, dy + 6, x + 6, dy + 14);
                break;

            case ICON_VITALITY:
                // Body Battery / Vitality human silhouette with energy core (15x18 px)
                drawVitalityIcon(dc, x, cy, col);
                break;

            case ICON_BATTERY:
                drawBatteryIcon(dc, x, cy - 5, getBatteryPercent(), isBatteryCharging(), col);
                break;

            case ICON_HAZARD:
                drawHazardIcon(dc, x, cy - 6, col);
                break;

            case ICON_STAIRS:
                // Ascending staircase icon (15x15 px)
                var sty = cy - 8;
                dc.fillRectangle(x, sty + 10, 4, 5);
                dc.fillRectangle(x + 5, sty + 5, 4, 10);
                dc.fillRectangle(x + 10, sty, 4, 15);
                break;
        }
    }

    private function drawVitalityIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        var hy = cy - 9;

        // Head
        dc.fillCircle(x + 8, hy + 3, 3);

        // Torso / shoulders silhouette
        dc.drawLine(x + 1, hy + 6, x + 14, hy + 6);
        dc.drawLine(x + 1, hy + 6, x + 3, hy + 14);
        dc.drawLine(x + 14, hy + 6, x + 13, hy + 14);
        dc.drawLine(x + 3, hy + 14, x + 8, hy + 16);
        dc.drawLine(x + 13, hy + 14, x + 8, hy + 16);

        // Glowing energy core inside chest
        dc.setColor(COLOR_TEXT_AMBER, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + 8, hy + 5],
            [x + 5, hy + 10],
            [x + 8, hy + 9],
            [x + 6, hy + 14],
            [x + 10, hy + 9],
            [x + 8, hy + 9]
        ]);
    }

    private function drawBatteryIcon(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, bat as Lang.Number, charging as Lang.Boolean, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, 15, 10, 3);
        dc.fillRectangle(x + 15, y + 3, 3, 5);

        if (charging) {
            dc.drawLine(x + 9, y + 1, x + 5, y + 5);
            dc.drawLine(x + 5, y + 5, x + 10, y + 5);
            dc.drawLine(x + 10, y + 5, x + 6, y + 9);
        } else {
            var fillW = ((bat / 100.0) * 10).toNumber();
            if (fillW > 10) { fillW = 10; }
            if (fillW > 0) {
                dc.fillRectangle(x + 3, y + 3, fillW, 5);
            }
        }
    }

    private function drawCalendarIcon(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y + 3, 13, 10, 1);
        dc.fillRectangle(x + 1, y + 3, 10, 3);
        dc.drawLine(x + 3, y, x + 3, y + 4);
        dc.drawLine(x + 9, y, x + 9, y + 4);
        dc.drawPoint(x + 4, y + 8);
        dc.drawPoint(x + 8, y + 8);
    }

    private function drawBellIcon(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(x + 6, y + 5, 5, Graphics.ARC_CLOCKWISE, 180, 0);
        dc.drawLine(x + 1, y + 5, x, y + 9);
        dc.drawLine(x + 11, y + 5, x + 13, y + 9);
        dc.drawLine(x, y + 9, x + 13, y + 9);
        dc.drawPoint(x + 6, y + 11);
    }

    private function drawNotificationIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var my = cy - 5;
        dc.drawRoundedRectangle(x - 6, my, 13, 9, 3);
        dc.drawLine(x - 4, my + 9, x - 1, my + 11);
        dc.drawLine(x - 1, my + 11, x - 1, my + 9);
    }

    private function drawBluetoothIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x, cy - 8, x, cy + 8);
        dc.drawLine(x - 4, cy - 4, x + 4, cy + 4);
        dc.drawLine(x + 4, cy + 4, x, cy + 8);
        dc.drawLine(x - 4, cy + 4, x + 4, cy - 4);
        dc.drawLine(x + 4, cy - 4, x, cy - 8);
    }

    private function drawPhoneIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x - 5, cy - 8, 10, 15, 3);
        dc.fillRectangle(x - 3, cy - 5, 6, 9);
        dc.drawPoint(x, cy + 5);
    }

    private function drawHazardIcon(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.fillPolygon([
            [x + 6, y],
            [x + 11, y + 10],
            [x + 1, y + 10]
        ]);
        dc.setColor(COLOR_PLATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.drawPoint(x + 6, y + 5);
        dc.drawPoint(x + 6, y + 8);
    }

    // =========================================================================
    // 7-SEGMENT NIXIE TUBE RENDERING (HH:MM AT Y: 100-180, W: 42, H: 80)
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
        var bulbYCoords = [124, 156];

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
                // Some firmware returns an empty iterator when :period is 1.
                // Leave the period unset and read recent samples newest first.
                var bbIter = SensorHistory.getBodyBatteryHistory({:order => SensorHistory.ORDER_NEWEST_FIRST});
                if (bbIter != null) {
                    // A recent sample can be missing; bound the fallback search
                    // so a watch-face update never scans the whole history.
                    for (var i = 0; i < 10; i++) {
                        var sample = bbIter.next();
                        if (sample == null) {
                            break;
                        }
                        var value = sample.data;
                        if ((value instanceof Lang.Number || value instanceof Lang.Float)
                            && value >= 0 && value <= 100) {
                            return value.toNumber();
                        }
                    }
                }
            } catch (e) {
                // Sensor history may be temporarily unavailable.
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
