import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Position;
import Toybox.WatchUi;
import Toybox.Weather;

//! MetroDisplayView
//! Post-apocalyptic Nixie tube watch face inspired by Metro 2033 / Artyom's wristwatch.
//! Features scaled-down glowing neon-amber Nixie tubes, Artyom's top horizontal blue
//! neon sunlight/ambient indicator tube, unlit cathode ghost filaments,
//! industrial PCB circuit background with vias, military silkscreen, and
//! Geiger dosimeter / battery complications.
class MetroDisplayView extends WatchUi.WatchFace {

    // Display geometry (280x280 for fenix7x)
    private var _screenW as Lang.Number = 280;
    private var _screenH as Lang.Number = 280;
    private var _centerX as Lang.Number = 140;
    private var _centerY as Lang.Number = 140;

    // Scaled Nixie tube layout coordinates
    private var _tubeW as Lang.Number = 34;
    private var _tubeH as Lang.Number = 74;
    private var _tubeY as Lang.Number = 105;
    private var _tubeXs as Lang.Array<Lang.Number> = [54, 94, 152, 192];

    // State
    private var _isSleepMode as Lang.Boolean = false;
    private var _debugSunlight as Lang.Boolean = false; // Interactive debug flag (default: true)

    // Nixie tube color palette (Orange-Amber Glow)
    private const COLOR_HALO_OUTER      = 0x882200; // Deep glowing red-orange plasma halo
    private const COLOR_GLOW_MID        = 0xFF5500; // Bright neon orange (Graphics.COLOR_ORANGE)
    private const COLOR_CORE_HOT        = 0xFFFF66; // White-hot filament center
    private const COLOR_GHOST_FILAMENT  = 0x22140A; // Dim unlit cathode wire in background
    private const COLOR_TUBE_GLASS_BG   = 0x0A0D0B; // Deep dark cavity inside tube
    private const COLOR_TUBE_BORDER     = 0x38423E; // Outer glass capsule rim
    private const COLOR_TUBE_HIGHLIGHT  = 0x587880; // Specular glass reflection
    private const COLOR_MESH_GRID       = 0x1A221C; // Anode wire mesh grid
    private const COLOR_SOCKET_BASE     = 0x1F2426; // Stamped metal socket base
    private const COLOR_SOCKET_BORDER   = 0x101314; // Socket outline

    // Top Sunlight / Ambient Light Blue Neon Tube Palette (Metro Stealth Sensor)
    private const COLOR_SUN_HALO        = 0x004488; // Deep electric cobalt glow bloom
    private const COLOR_SUN_GLOW_MID    = 0x00AAFF; // Vibrant cyan neon beam
    private const COLOR_SUN_CORE_HOT    = 0xEEFFFF; // White-hot ice-blue center filament
    private const COLOR_SUN_OFF_BG      = 0x0A1014; // Dark transparent cavity when unlit
    private const COLOR_SUN_OFF_RIM     = 0x2A343A; // Unlit transparent/grey glass border
    private const COLOR_SUN_OFF_WIRE    = 0x222C32; // Unlit grey tungsten/cathode wire
    private const COLOR_SUN_BRACKET     = 0x483A26; // Stamped copper/brass mounting bracket
    private const COLOR_SUN_BRACKET_RIM = 0x2E2416; // Bracket outline
    private const COLOR_SUN_RIVET       = 0x8C7040; // Copper rivets

    // PCB background colors
    private const COLOR_PCB_BG          = 0x08100C; // Dark industrial solder mask
    private const COLOR_PCB_TRACE       = 0x183020; // Copper / dark green PCB traces
    private const COLOR_PCB_VIA_PAD     = 0x4A4020; // Gold/copper solder via pad
    private const COLOR_PCB_SILK        = 0x2D4234; // Faint silkscreen text and lines
    private const COLOR_SCREW_RIM       = 0x40454A; // Perimeter chassis screw rim
    private const COLOR_SCREW_HEAD      = 0x282C30; // Screw head face
    private const COLOR_SCREW_SLOT      = 0x101214; // Screw drive slot

    // Complication colors
    private const COLOR_DATE_BORDER     = 0x2D4234;
    private const COLOR_DATE_BG         = 0x0E1612;
    private const COLOR_DATE_TEXT       = 0xFFAA00; // Phosphor amber
    private const COLOR_BAT_GOOD        = 0xFF5500; // Amber dosimeter
    private const COLOR_BAT_LOW         = 0xFF0000; // Radiation warning red
    private const COLOR_BAT_CHARGING    = 0x00FF88; // Electric green
    private const COLOR_BAT_EMPTY       = 0x1A221D; // Unlit segment

    function initialize() {
        WatchFace.initialize();
    }

    //! Load resources and layout metrics
    function onLayout(dc as Graphics.Dc) as Void {
        _screenW = dc.getWidth();
        _screenH = dc.getHeight();
        _centerX = _screenW / 2;
        _centerY = _screenH / 2;

        // Scaled-down Nixie tubes layout to give ample breathing room
        _tubeW = 34;
        _tubeH = 74;
        _tubeY = 105;

        // Symmetrical positioning with 54px left/right margins and central colon gap
        _tubeXs = [
            54,  // Hour Tens
            94,  // Hour Ones
            152, // Minute Tens
            192  // Minute Ones
        ];
    }

    //! Called when view is brought to foreground
    function onShow() as Void {
    }

    //! Called when view is removed from screen
    function onHide() as Void {
    }

    //! User has looked at watch (high power mode)
    function onExitSleep() as Void {
        _isSleepMode = false;
        WatchUi.requestUpdate();
    }

    //! Terminate active high-frequency updates (low power mode)
    function onEnterSleep() as Void {
        _isSleepMode = true;
        WatchUi.requestUpdate();
    }

    //! Update the display
    function onUpdate(dc as Graphics.Dc) as Void {
        // Enable anti-aliasing if supported by hardware (fenix7x / CIQ 4+)
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // 1. Draw Industrial PCB Background
        drawPcbBackground(dc);

        // 2. Draw Top Ambient / Sunlight Indicator Neon Tube (Metro light sensor)
        var isSunlit = isSunlitEnvironment();
        drawTopSunlightTube(dc, isSunlit);

        // 3. Draw Top Complication: Industrial Date Badge
        drawDateBadge(dc);

        // 4. Fetch Time
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        var minutes = clockTime.min;

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

        // In 12-hour mode, blank the leading zero tube (leave it unlit)
        if (!is24Hour && hTens == 0) {
            hTens = -1;
        }

        // 5. Draw 4 Scaled Nixie Glass Tubes with Glowing Digits
        var digits = [hTens, hOnes, mTens, mOnes];
        for (var i = 0; i < 4; i++) {
            drawNixieTube(dc, _tubeXs[i], _tubeY, _tubeW, _tubeH, digits[i]);
        }

        // 6. Draw Center Colon (INS-1 Neon Glow Indicator Lamps)
        drawColonIndicator(dc);

        // 7. Draw Bottom Complication: Geiger Dosimeter / Battery Gauge
        drawBatteryDosimeter(dc);

        // 8. Outer Industrial Bezel Screws
        drawChassisBolts(dc);
    }

    // =========================================================================
    // SUNLIGHT / AMBIENT LIGHT DETECTION LOGIC
    // =========================================================================

    //! Toggle debug sunlight state (interactive simulator tap)
    public function toggleDebugSunlight() as Void {
        _debugSunlight = !_debugSunlight;
        WatchUi.requestUpdate();
    }

    private function isSunlitEnvironment() as Lang.Boolean {
        // 1. Check user setting / simulation toggle (0: Auto, 1: Always Lit, 2: Always Dark)
        var mode = 0;
        try {
            if (Application has :Properties && Application.Properties has :getValue) {
                var propVal = Application.Properties.getValue("SunlightMode");
                if (propVal != null) {
                    mode = propVal as Lang.Number;
                }
            } else {
                var propVal = Application.getApp().getProperty("SunlightMode");
                if (propVal != null) {
                    mode = propVal as Lang.Number;
                }
            }
        } catch (e) {
            mode = 0;
        }

        if (mode == 1) {
            return true; // Force Sunlit / Active from settings
        } else if (mode == 2) {
            return false; // Force Darkness / Stealth from settings
        }

        // 2. Interactive simulator tap / debug flag (default: true)
        if (_debugSunlight != null) {
            return _debugSunlight;
        }

        // 3. Astronomical Sunrise / Sunset calculation via Toybox.Weather
        if (Toybox has :Weather && Weather has :getSunrise && Weather has :getSunset) {
            try {
                var conditions = Weather.getCurrentConditions();
                if (conditions != null && conditions.observationLocationPosition != null) {
                    var now = Time.now();
                    var loc = conditions.observationLocationPosition as Position.Location;
                    var sunrise = Weather.getSunrise(loc, now);
                    var sunset = Weather.getSunset(loc, now);
                    if (sunrise != null && sunset != null) {
                        if (now.greaterThan(sunrise) && now.lessThan(sunset)) {
                            return true;
                        } else {
                            return false;
                        }
                    }
                }
            } catch (e) {
                // Ignore and fall back to local clock
            }
        }

        // 3. Fallback: Local Civil Daylight calculation (approx 06:30 - 19:30)
        var clockTime = System.getClockTime();
        var currentMinuteOfDay = (clockTime.hour * 60) + clockTime.min;
        return (currentMinuteOfDay >= 390 && currentMinuteOfDay <= 1170);
    }

    // =========================================================================
    // TOP SUNLIGHT / AMBIENT LIGHT INDICATOR TUBE (METRO ARTYOM SENSOR)
    // =========================================================================

    private function drawTopSunlightTube(dc as Graphics.Dc, isSunlit as Lang.Boolean) as Void {
        var tubeW = 104;
        var tubeH = 16;
        var tubeX = _centerX - (tubeW / 2); // 140 - 52 = 88
        var tubeY = 32;

        var bracketW = 9;
        var bracketH = 18;
        var bracketY = tubeY - 1;

        // 1. Metal mounting end brackets (Left and Right)
        var leftBx = tubeX - 4;
        var rightBx = tubeX + tubeW - bracketW + 4;

        var bracketColor = isSunlit ? COLOR_SUN_BRACKET : 0x282624;
        var bracketRim = isSunlit ? COLOR_SUN_BRACKET_RIM : 0x161618;
        var rivetColor = isSunlit ? COLOR_SUN_RIVET : 0x48423A;

        // Left bracket
        dc.setColor(bracketColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(leftBx, bracketY, bracketW, bracketH, 2);
        dc.setColor(bracketRim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(leftBx, bracketY, bracketW, bracketH, 2);
        dc.setColor(rivetColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(leftBx + 3, bracketY + 4, 1);
        dc.fillCircle(leftBx + 3, bracketY + bracketH - 4, 1);

        // Right bracket
        dc.setColor(bracketColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rightBx, bracketY, bracketW, bracketH, 2);
        dc.setColor(bracketRim, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rightBx, bracketY, bracketW, bracketH, 2);
        dc.setColor(rivetColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(rightBx + bracketW - 3, bracketY + 4, 1);
        dc.fillCircle(rightBx + bracketW - 3, bracketY + bracketH - 4, 1);

        // 2. Glass Tube Body
        var glassX = tubeX;
        var glassY = tubeY;
        var glassW = tubeW;
        var glassH = tubeH;
        var cornerR = 7;

        if (isSunlit) {
            // --- SUNLIGHT / ACTIVE STATE (Bright Cyan Glow) ---

            // Background internal plasma
            dc.setColor(0x061D2B, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(glassX, glassY, glassW, glassH, cornerR);

            // Outer Bloom Halo
            dc.setColor(COLOR_SUN_HALO, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(5);
            dc.drawRoundedRectangle(glassX, glassY, glassW, glassH, cornerR);

            // Mid Glow on Glass Capsule Rim
            dc.setColor(COLOR_SUN_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(glassX, glassY, glassW, glassH, cornerR);

            // Internal horizontal cathode wire filament
            var wireY = glassY + (glassH / 2);
            var wireX1 = glassX + bracketW - 2;
            var wireX2 = glassX + glassW - bracketW + 2;

            // Halo pass on wire
            dc.setColor(COLOR_SUN_HALO, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(6);
            dc.drawLine(wireX1, wireY, wireX2, wireY);

            // Mid neon cyan beam
            dc.setColor(COLOR_SUN_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(wireX1, wireY, wireX2, wireY);

            // Center sensor coiled filament element
            dc.drawCircle(_centerX, wireY, 4);

            // White-hot core wire
            dc.setColor(COLOR_SUN_CORE_HOT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(wireX1, wireY, wireX2, wireY);
            dc.drawCircle(_centerX, wireY, 2);

            // Glass specular reflection highlight (top shoulder)
            dc.setColor(0xAAEEFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(glassX + 12, glassY + 2, glassX + glassW - 12, glassY + 2);
        } else {
            // --- DARK / UNLIT STEALTH STATE ---

            // Dark smoked glass
            dc.setColor(COLOR_SUN_OFF_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(glassX, glassY, glassW, glassH, cornerR);

            // Dim translucent rim
            dc.setColor(COLOR_SUN_OFF_RIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawRoundedRectangle(glassX, glassY, glassW, glassH, cornerR);

            // Unlit internal tungsten wire
            var wireYOff = glassY + (glassH / 2);
            var wireX1Off = glassX + bracketW - 2;
            var wireX2Off = glassX + glassW - bracketW + 2;

            dc.setColor(COLOR_SUN_OFF_WIRE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(wireX1Off, wireYOff, wireX2Off, wireYOff);
            dc.drawCircle(_centerX, wireYOff, 2);

            // Faint glass reflection
            dc.setColor(0x182834, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(glassX + 14, glassY + 2, glassX + glassW - 14, glassY + 2);
        }
    }

    // =========================================================================
    // PCB BACKGROUND DRAWING
    // =========================================================================

    private function drawPcbBackground(dc as Graphics.Dc) as Void {
        // Base dark solder mask fill
        dc.setColor(COLOR_PCB_BG, COLOR_PCB_BG);
        dc.clear();

        // Circuit Traces (0, 90, and 45 degree bends)
        dc.setColor(COLOR_PCB_TRACE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        // Top-left traces
        dc.drawLine(24, 60, 50, 60);
        dc.drawLine(50, 60, 64, 74);
        dc.drawLine(64, 74, 64, 98);

        // Top-right traces
        dc.drawLine(256, 60, 230, 60);
        dc.drawLine(230, 60, 216, 74);
        dc.drawLine(216, 74, 216, 98);

        // Top tube feeder traces
        dc.drawLine(80, 22, 80, 31);
        dc.drawLine(200, 22, 200, 31);

        // Bottom-left traces
        dc.drawLine(24, 220, 54, 220);
        dc.drawLine(54, 220, 72, 202);
        dc.drawLine(72, 202, 72, 188);

        // Bottom-right traces
        dc.drawLine(256, 220, 226, 220);
        dc.drawLine(226, 220, 208, 202);
        dc.drawLine(208, 202, 208, 188);

        // Side bus traces
        dc.drawLine(18, 120, 28, 130);
        dc.drawLine(28, 130, 28, 150);
        dc.drawLine(28, 150, 18, 160);

        dc.drawLine(262, 120, 252, 130);
        dc.drawLine(252, 130, 252, 150);
        dc.drawLine(252, 150, 262, 160);

        // Center bottom traces
        dc.drawLine(96, 248, 110, 248);
        dc.drawLine(110, 248, 120, 238);
        dc.drawLine(184, 248, 170, 248);
        dc.drawLine(170, 248, 160, 238);

        // Solder Vias (copper contact ring with drill hole)
        var viaCoords = [
            [50, 60], [230, 60],
            [80, 22], [200, 22],
            [54, 220], [226, 220],
            [28, 130], [28, 150],
            [252, 130], [252, 150],
            [120, 238], [160, 238]
        ];

        for (var i = 0; i < viaCoords.size(); i++) {
            var vx = viaCoords[i][0];
            var vy = viaCoords[i][1];
            dc.setColor(COLOR_PCB_VIA_PAD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(vx, vy, 3);
            dc.setColor(COLOR_PCB_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(vx, vy, 1);
        }

        // Silkscreen technical markings
        dc.setColor(COLOR_PCB_SILK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        // Horizontal bus guide lines
        dc.drawLine(86, 94, 194, 94);
        dc.drawLine(86, 188, 194, 188);

        // Fiducial crosshairs (+)
        drawFiducial(dc, 20, 140);
        drawFiducial(dc, 260, 140);
        drawFiducial(dc, 140, 18);

        // Micro silkscreen text
        dc.drawText(140, 80, Graphics.FONT_SYSTEM_XTINY, "METRO D-6 · DISP-01", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawFiducial(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number) as Void {
        dc.drawLine(x - 4, y, x + 4, y);
        dc.drawLine(x, y - 4, x, y + 4);
        dc.drawCircle(x, y, 3);
    }

    // =========================================================================
    // NIXIE TUBE RENDERING
    // =========================================================================

    private function drawNixieTube(
        dc as Graphics.Dc,
        x as Lang.Number,
        y as Lang.Number,
        w as Lang.Number,
        h as Lang.Number,
        digit as Lang.Number
    ) as Void {
        // 1. Metal base socket at bottom
        dc.setColor(COLOR_SOCKET_BASE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + 3, y + h - 3, w - 6, 6, 2);
        dc.setColor(COLOR_SOCKET_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x + 3, y + h - 3, w - 6, 6, 2);

        // 2. Glass Tube Body: Dark interior
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

        // 5. Unlit Ghost Filament (Cathode wire stack depth - always subtle 8)
        dc.setColor(COLOR_GHOST_FILAMENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        drawNixieDigitWire(dc, x, y, w, h, 8);

        // 6. Glowing Active Digit Filament (Multi-pass glow)
        if (digit >= 0) {
            // Pass 1: Outer glowing plasma halo
            dc.setColor(COLOR_HALO_OUTER, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            drawNixieDigitWire(dc, x, y, w, h, digit);

            // Pass 2: Vibrant neon-orange glow
            dc.setColor(COLOR_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            drawNixieDigitWire(dc, x, y, w, h, digit);

            // Pass 3: White-hot core wire
            dc.setColor(COLOR_CORE_HOT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            drawNixieDigitWire(dc, x, y, w, h, digit);
        }

        // 7. Glass Specular Reflections (Left edge highlight streak and top shoulder)
        dc.setColor(COLOR_TUBE_HIGHLIGHT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x + 2, y + 10, x + 2, y + h - 10);
        dc.drawArc(x + 8, y + 8, 5, Graphics.ARC_CLOCKWISE, 180, 90);
    }

    //! Render bent wire cathode digits (scaled geometry)
    private function drawNixieDigitWire(
        dc as Graphics.Dc,
        x0 as Lang.Number,
        y0 as Lang.Number,
        w as Lang.Number,
        h as Lang.Number,
        digit as Lang.Number
    ) as Void {
        var xl = x0 + 5;
        var xr = x0 + w - 5;
        var xm = x0 + (w / 2);
        var yt = y0 + 9;
        var yb = y0 + h - 9;
        var ym = y0 + (h / 2);
        var r  = (xr - xl) / 2; // 12

        switch (digit) {
            case 0:
                dc.drawRoundedRectangle(xl, yt, xr - xl, yb - yt, 10);
                break;

            case 1:
                dc.drawLine(xm + 1, yt, xm + 1, yb);
                dc.drawLine(xl + 1, yt + 10, xm + 1, yt);
                dc.drawLine(xm - 6, yb, xm + 8, yb);
                break;

            case 2:
                dc.drawArc(xm, yt + r, r, Graphics.ARC_CLOCKWISE, 180, 0);
                dc.drawLine(xr, yt + r, xl, yb);
                dc.drawLine(xl, yb, xr, yb);
                dc.drawLine(xr, yb, xr, yb - 5);
                break;

            case 3:
                dc.drawArc(xm, yt + r, r, Graphics.ARC_CLOCKWISE, 180, 0);
                dc.drawLine(xr, yt + r, xm + 1, ym);
                dc.drawLine(xm + 1, ym, xr, yb - r);
                dc.drawArc(xm, yb - r, r, Graphics.ARC_CLOCKWISE, 0, 180);
                break;

            case 4:
                dc.drawLine(xr - 3, yt, xr - 3, yb);
                dc.drawLine(xr - 3, yt, xl, ym + 3);
                dc.drawLine(xl, ym + 3, xr, ym + 3);
                break;

            case 5:
                dc.drawLine(xr, yt, xl, yt);
                dc.drawLine(xl, yt, xl, ym);
                dc.drawLine(xl, ym, xm, ym);
                dc.drawArc(xm, yb - r, r, Graphics.ARC_CLOCKWISE, 90, 180);
                break;

            case 6:
                dc.drawCircle(xm, yb - r, r);
                dc.drawLine(xr - 3, yt + 2, xl, yb - r);
                break;

            case 7:
                dc.drawLine(xl, yt, xr, yt);
                dc.drawLine(xr, yt, xl + 3, yb);
                dc.drawLine(xm - 5, ym, xm + 5, ym);
                break;

            case 8:
                dc.drawCircle(xm, yt + r - 1, r - 2);
                dc.drawCircle(xm, yb - r + 1, r);
                break;

            case 9:
                dc.drawCircle(xm, yt + r, r);
                dc.drawLine(xr, yt + r, xl + 3, yb);
                break;
        }
    }

    // =========================================================================
    // COLON (INS-1 NEON GLOW INDICATOR BULBS)
    // =========================================================================

    private function drawColonIndicator(dc as Graphics.Dc) as Void {
        var colonX = _centerX;
        var dotY1 = 129;
        var dotY2 = 153;

        var bulbYCoords = [dotY1, dotY2];
        for (var i = 0; i < 2; i++) {
            var cy = bulbYCoords[i];

            // Miniature glass capsule
            dc.setColor(COLOR_TUBE_GLASS_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(colonX - 4, cy - 7, 8, 14, 3);
            dc.setColor(COLOR_TUBE_BORDER, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawRoundedRectangle(colonX - 4, cy - 7, 8, 14, 3);

            // Glowing neon core dot
            dc.setColor(COLOR_HALO_OUTER, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(colonX, cy, 3);
            dc.setColor(COLOR_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(colonX, cy, 2);
            dc.setColor(COLOR_CORE_HOT, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(colonX, cy, 1);

            // Specular reflection
            dc.setColor(COLOR_TUBE_HIGHLIGHT, Graphics.COLOR_TRANSPARENT);
            dc.drawPoint(colonX - 2, cy - 3);
        }
    }

    // =========================================================================
    // TOP COMPLICATION: MILITARY DATE BADGE
    // =========================================================================

    private function drawDateBadge(dc as Graphics.Dc) as Void {
        var now = Time.now();
        var dateInfo = Gregorian.info(now, Time.FORMAT_MEDIUM);

        var dayOfWeek = dateInfo.day_of_week;
        var day = dateInfo.day;
        var month = dateInfo.month;
        var dateString = Lang.format("$1$ · $2$ $3$", [dayOfWeek, day, month]).toUpper();

        var badgeW = 120;
        var badgeH = 20;
        var badgeX = _centerX - (badgeW / 2);
        var badgeY = 56;

        // Dark stamped metal plate
        dc.setColor(COLOR_DATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(badgeX, badgeY, badgeW, badgeH, 4);

        // Industrial border / brackets
        dc.setColor(COLOR_DATE_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(badgeX, badgeY, badgeW, badgeH, 4);

        // Small radiation hazard marker (gold triangle)
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        var tx = badgeX + 6;
        var ty = badgeY + 10;
        dc.fillPolygon([
            [tx, ty - 4],
            [tx + 5, ty],
            [tx, ty + 4]
        ]);

        // Date text in glowing phosphor amber
        dc.setColor(COLOR_DATE_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _centerX + 4,
            badgeY + (badgeH / 2),
            Graphics.FONT_SYSTEM_XTINY,
            dateString,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // =========================================================================
    // BOTTOM COMPLICATION: GEIGER DOSIMETER / BATTERY GAUGE
    // =========================================================================

    private function drawBatteryDosimeter(dc as Graphics.Dc) as Void {
        var stats = System.getSystemStats();
        var battery = stats.battery; // 0.0 to 100.0
        var isCharging = false;
        if (stats has :charging && stats.charging != null) {
            isCharging = stats.charging as Lang.Boolean;
        }

        var barW = 120;
        var barH = 12;
        var barX = _centerX - (barW / 2);
        var barY = 204;

        // Dosimeter tube housing
        dc.setColor(COLOR_DATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, barY, barW, barH, 5);
        dc.setColor(COLOR_DATE_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(barX, barY, barW, barH, 5);

        // 10 Segments
        var totalSegments = 10;
        var litSegments = (battery / 10.0 + 0.5).toNumber();
        if (litSegments > 10) { litSegments = 10; }
        if (litSegments < 1 && battery > 0) { litSegments = 1; }

        // Choose segment glow color based on battery health & charging state
        var activeColor = COLOR_BAT_GOOD;
        if (isCharging) {
            activeColor = COLOR_BAT_CHARGING;
        } else if (battery <= 20.0) {
            activeColor = COLOR_BAT_LOW;
        }

        var segW = 9;
        var segH = 6;
        var segY = barY + 3;

        for (var s = 0; s < totalSegments; s++) {
            var segX = barX + 4 + (s * 11);
            if (s < litSegments) {
                dc.setColor(activeColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(segX, segY, segW, segH);
            } else {
                dc.setColor(COLOR_BAT_EMPTY, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(segX, segY, segW, segH);
            }
        }

        // Battery percentage and dosimeter status text
        var batString = Lang.format("PWR $1$%", [battery.format("%d")]);
        if (isCharging) {
            batString = Lang.format("CHG $1$%", [battery.format("%d")]);
        }

        dc.setColor(COLOR_DATE_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _centerX,
            barY + barH + 5,
            Graphics.FONT_SYSTEM_XTINY,
            batString,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // =========================================================================
    // CHASSIS BOLTS (PERIMETER INDUSTRIAL SCREWS)
    // =========================================================================

    private function drawChassisBolts(dc as Graphics.Dc) as Void {
        // 4 Corner screws at 45 degree angles on the 280x280 round screen
        var boltPositions = [
            [52, 52],
            [228, 52],
            [52, 228],
            [228, 228]
        ];

        dc.setPenWidth(1);
        for (var i = 0; i < boltPositions.size(); i++) {
            var bx = boltPositions[i][0];
            var by = boltPositions[i][1];

            // Outer metallic rim
            dc.setColor(COLOR_SCREW_RIM, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, 7);

            // Screw head face
            dc.setColor(COLOR_SCREW_HEAD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, 5);

            // Screw drive slot (angled at 45 degrees)
            dc.setColor(COLOR_SCREW_SLOT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(bx - 3, by - 3, bx + 3, by + 3);
        }
    }
}
