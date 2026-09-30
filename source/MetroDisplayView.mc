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
//! Layout Structure (Strict Top-to-Bottom Alignment):
//! 1. Row 1 (Y: ~10-16): Centralized Battery icon + percentage at the very top
//! 2. Row 2 (Y: ~24-34): Horizontal blue/cyan glowing neon tube directly below battery
//! 3. Row 3 (Y: ~42-62): 2 Upper symmetrical slots (Left: Altitude, Right: Weather)
//! 4. Row 4 (Y: ~72-90): Full-width 3-slot date bar (Day, Calendar + Date, Status)
//! 5. Row 5 (Y: ~100-166): Centered Nixie tubes (HH:MM), INS-1 colon, sub-script seconds under minutes, side icons
//! 6. Row 6 (Y: ~170-190): 3 Lower data slots (Left: Calories, Center: Steps, Right: Heart Rate)
//! 7. Row 7 (Y: ~196-214): Distance block (location pin icon)
//! 8. Row 8 (Y: ~220-238): Body Battery block (vitality human silhouette + energy core)
class MetroDisplayView extends WatchUi.WatchFace {

    // Metric Types Enum
    enum MetricType {
        METRIC_NONE           = 0,
        METRIC_HEART_RATE     = 1,
        METRIC_BATTERY        = 2,
        METRIC_STEPS          = 3,
        METRIC_CALORIES       = 4,
        METRIC_DISTANCE       = 5,
        METRIC_WEATHER        = 6,
        METRIC_SUNRISE_SUNSET = 7,
        METRIC_ACTIVE_MINUTES = 8,
        METRIC_FLOORS         = 9,
        METRIC_ALTITUDE       = 10,
        METRIC_BODY_BATTERY   = 11
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
        ICON_HAZARD       = 13
    }

    // Display geometry (280x280 for fenix7x)
    private var _screenW as Lang.Number = 280;
    private var _centerX as Lang.Number = 140;

    // Centered Nixie tube layout coordinates (Y: 100 - 150)
    private var _tubeW as Lang.Number = 26;
    private var _tubeH as Lang.Number = 50;
    private var _tubeY as Lang.Number = 100;
    private var _tubeXs as Lang.Array<Lang.Number> = [64, 94, 160, 190];

    // State & Interactive Flags
    private var _isSleepMode as Lang.Boolean = false;
    private var _debugSunlightOverride as Lang.Boolean? = null;

    // User Settings Cache
    private var _sunlightMode as Lang.Number = 0;
    private var _slotUpperLeft as Lang.Number = 10;         // Altitude
    private var _slotUpperRight as Lang.Number = 6;         // Weather
    private var _slotLowerLeft as Lang.Number = 4;          // Calories
    private var _slotLowerCenter as Lang.Number = 3;        // Steps
    private var _slotLowerRight as Lang.Number = 1;         // Heart Rate
    private var _slotBottomDistance as Lang.Number = 5;     // Distance
    private var _slotBottomBodyBattery as Lang.Number = 11; // Body Battery

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

    // Top Sunlight Neon Tube Palette
    private const COLOR_SUN_HALO        = 0x004488; // Deep electric cobalt glow bloom
    private const COLOR_SUN_GLOW_MID    = 0x00AAFF; // Vibrant cyan neon beam
    private const COLOR_SUN_CORE_HOT    = 0xEEFFFF; // White-hot ice-blue center filament
    private const COLOR_SUN_OFF_BG      = 0x0A1014; // Dark transparent cavity when unlit
    private const COLOR_SUN_OFF_RIM     = 0x2A343A; // Unlit transparent/grey glass border
    private const COLOR_SUN_OFF_WIRE    = 0x222C32; // Unlit grey tungsten wire
    private const COLOR_SUN_BRACKET     = 0x483A26; // Stamped copper/brass bracket
    private const COLOR_SUN_BRACKET_RIM = 0x2E2416; // Bracket outline
    private const COLOR_SUN_RIVET       = 0x8C7040; // Copper rivets

    // PCB background colors
    private const COLOR_PCB_BG          = 0x08100C; // Dark industrial solder mask
    private const COLOR_PCB_TRACE       = 0x183020; // Copper / dark green PCB traces
    private const COLOR_PCB_VIA_PAD     = 0x4A4020; // Gold/copper solder via pad
    private const COLOR_PCB_SILK        = 0x2D4234; // Silkscreen markings
    private const COLOR_SCREW_RIM       = 0x40454A; // Perimeter chassis screw rim
    private const COLOR_SCREW_HEAD      = 0x282C30; // Screw head face
    private const COLOR_SCREW_SLOT      = 0x101214; // Screw drive slot

    // Tactical Badges & Phosphor Colors
    private const COLOR_PLATE_BG        = 0x0C1410; // Dark stamped plate
    private const COLOR_PLATE_BORDER    = 0x24362A; // Plate rim
    private const COLOR_TEXT_AMBER      = 0xFFAA00; // Phosphor amber
    private const COLOR_TEXT_ORANGE     = 0xFF7700; // Phosphor orange
    private const COLOR_TEXT_GREEN      = 0x00FF88; // Phosphor electric green
    private const COLOR_TEXT_CYAN       = 0x00D0FF; // Phosphor ice cyan
    private const COLOR_TEXT_RED        = 0xFF3300; // Warning red

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    //! Load user-configurable settings
    public function loadSettings() as Void {
        _sunlightMode = readProperty("SunlightMode", 0);
        _slotUpperLeft = readProperty("SlotUpperLeft", 10);
        _slotUpperRight = readProperty("SlotUpperRight", 6);
        _slotLowerLeft = readProperty("SlotLowerLeft", 4);
        _slotLowerCenter = readProperty("SlotLowerCenter", 3);
        _slotLowerRight = readProperty("SlotLowerRight", 1);
        _slotBottomDistance = readProperty("SlotBottomDistance", 5);
        _slotBottomBodyBattery = readProperty("SlotBottomBodyBattery", 11);
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

        _tubeW = 26;
        _tubeH = 50;
        _tubeY = 100;
        _tubeXs = [64, 94, 160, 190];
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

        // 1. Draw Integrated PCB Background Grid Frame
        drawPcbBackground(dc);

        // 2. Row 1: Centralized Top Battery Icon + Percentage (Y: ~10-16)
        drawTopBattery(dc);

        // 3. Row 2: Sunlight / Ambient Tube Directly Below Battery (Y: ~24-34)
        var isSunlit = isSunlitEnvironment();
        drawTopSunlightTube(dc, isSunlit);

        // 4. Row 3: Upper 2 Symmetrical Slots Tightly Placed Under Tube (Y: ~42-62)
        // Left: Altitude, Right: Weather
        drawMetricSlotWithIcon(dc, 54, 42, 78, 20, _slotUpperLeft, isSunlit);
        drawMetricSlotWithIcon(dc, 148, 42, 78, 20, _slotUpperRight, isSunlit);

        // 5. Row 4: Full-Width 3-Field Date Bar Positioned Above Time (Y: ~72-90)
        drawFullWidthDateBar(dc);

        // 6. Row 5: Scaled Nixie Clock (HH:MM) + INS-1 Colon + Sub-script Seconds + Side Icons
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

        var digits = [hTens, hOnes, mTens, mOnes];
        for (var i = 0; i < 4; i++) {
            drawNixieTube(dc, _tubeXs[i], _tubeY, _tubeW, _tubeH, digits[i]);
        }

        // INS-1 Colon Lamps (X: 140, between Hours and Minutes)
        drawColonIndicator(dc);

        // Sub-script Digital Seconds (Rendered directly underneath the minutes digits)
        drawSubscriptSeconds(dc, seconds);

        // Side Status Icons (Left: Bluetooth + Dynamic Alarm; Right: Notification)
        drawSideIcons(dc);

        // 7. Row 6: Lower 3 Data Slots Right Under Time Block (Y: ~170-190)
        // Left: Calories, Center: Steps, Right: Heart Rate
        drawMetricSlotWithIcon(dc, 38, 170, 62, 20, _slotLowerLeft, isSunlit);
        drawMetricSlotWithIcon(dc, 108, 170, 64, 20, _slotLowerCenter, isSunlit);
        drawMetricSlotWithIcon(dc, 180, 170, 62, 20, _slotLowerRight, isSunlit);

        // 8. Row 7 & 8: Stacked Bottom Rows Pushed Closer to Edge
        // Row 7 (Y: 196 - 214): Distance (location pin icon)
        drawMetricSlotWithIcon(dc, 92, 196, 96, 18, _slotBottomDistance, isSunlit);

        // Row 8 (Y: 220 - 238): Body Battery (Vitality silhouette with energy core)
        drawMetricSlotWithIcon(dc, 92, 220, 96, 18, _slotBottomBodyBattery, isSunlit);

        // 9. Outer Industrial Chassis Bolts (Corner Screws)
        drawChassisBolts(dc);
    }

    // =========================================================================
    // ROW 1: CENTRALIZED TOP BATTERY (Y: ~10-16)
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
        var cy = 12;

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
    // ROW 2: TOP SUNLIGHT INDICATOR TUBE (Y: ~24-34)
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
        var tubeW = 88;
        var tubeH = 10;
        var tubeX = _centerX - (tubeW / 2); // 96
        var tubeY = 24;                     // Center Y: 29

        var bracketW = 8;
        var bracketH = 12;
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
        var cornerR = 4;
        if (isSunlit) {
            dc.setColor(0x061D2B, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(tubeX, tubeY, tubeW, tubeH, cornerR);

            dc.setColor(COLOR_SUN_HALO, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            dc.drawRoundedRectangle(tubeX, tubeY, tubeW, tubeH, cornerR);

            dc.setColor(COLOR_SUN_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(tubeX, tubeY, tubeW, tubeH, cornerR);

            var wireY = tubeY + (tubeH / 2);
            var wireX1 = tubeX + bracketW - 2;
            var wireX2 = tubeX + tubeW - bracketW + 2;

            dc.setColor(COLOR_SUN_HALO, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            dc.drawLine(wireX1, wireY, wireX2, wireY);

            dc.setColor(COLOR_SUN_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(wireX1, wireY, wireX2, wireY);
            dc.drawCircle(_centerX, wireY, 3);

            dc.setColor(COLOR_SUN_CORE_HOT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(wireX1, wireY, wireX2, wireY);
            dc.drawCircle(_centerX, wireY, 1);

            dc.setColor(0xAAEEFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tubeX + 8, tubeY + 2, tubeX + tubeW - 8, tubeY + 2);
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
            dc.drawCircle(_centerX, wireYOff, 2);

            dc.setColor(0x182834, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tubeX + 10, tubeY + 2, tubeX + tubeW - 10, tubeY + 2);
        }
    }

    // =========================================================================
    // ROW 4: FULL-WIDTH 3-SLOT DATE BAR (Y: ~72-90)
    // =========================================================================

    private function drawFullWidthDateBar(dc as Graphics.Dc) as Void {
        var barW = 208;
        var barH = 18;
        var barX = _centerX - (barW / 2); // 36
        var barY = 72;

        // Base Stamped Metal Bar
        dc.setColor(COLOR_PLATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, barY, barW, barH, 3);

        dc.setColor(COLOR_PLATE_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(barX, barY, barW, barH, 3);

        // Vertical Slot Dividers at X: 96 and X: 184
        dc.setColor(COLOR_PLATE_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(96, barY + 1, 96, barY + barH - 2);
        dc.drawLine(184, barY + 1, 184, barY + barH - 2);

        // Corner micro-rivets
        dc.setColor(0x405548, Graphics.COLOR_TRANSPARENT);
        dc.drawPoint(barX + 2, barY + 2);
        dc.drawPoint(barX + barW - 3, barY + 2);
        dc.drawPoint(barX + 2, barY + barH - 3);
        dc.drawPoint(barX + barW - 3, barY + barH - 3);

        var now = Time.now();
        var dateInfo = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var dayOfWeek = dateInfo.day_of_week.toUpper();
        var dateText = Lang.format("$1$ $2$", [dateInfo.day, dateInfo.month]).toUpper();

        var midY = barY + (barH / 2);

        // 1. Left Field: Day of week (X: 36 - 96, Center: 66)
        dc.setColor(COLOR_TEXT_AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(66, midY, Graphics.FONT_SYSTEM_XTINY, dayOfWeek, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 2. Center Field: Calendar Icon + Date (X: 96 - 184, Center: 140)
        var dateTextW = dc.getTextWidthInPixels(dateText, Graphics.FONT_SYSTEM_XTINY);
        var calIconW = 10;
        var calGap = 4;
        var calTotalW = calIconW + calGap + dateTextW;
        var calStartX = 140 - (calTotalW / 2);

        drawCalendarIcon(dc, calStartX, midY - 5, COLOR_TEXT_AMBER);
        dc.setColor(COLOR_TEXT_AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(calStartX + calIconW + calGap, midY, Graphics.FONT_SYSTEM_XTINY, dateText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // 3. Right Field: Status Icon (X: 184 - 244, Center: 214)
        drawHazardIcon(dc, 214 - 5, midY - 5, COLOR_TEXT_AMBER);
    }

    // =========================================================================
    // ROW 5: SUB-SCRIPT SECONDS & SIDE ICONS
    // =========================================================================

    //! Sub-script seconds displayed directly underneath the minutes digits
    private function drawSubscriptSeconds(dc as Graphics.Dc, seconds as Lang.Number) as Void {
        // Minutes digits span X = 160 to 216, center is X = 188
        var x = 172;
        var y = 152;
        var w = 32;
        var h = 12;

        dc.setColor(COLOR_PLATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 2);
        dc.setColor(COLOR_PLATE_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, w, h, 2);

        var secText = _isSleepMode ? "--" : seconds.format("%02d");
        var secColor = _isSleepMode ? 0x332211 : COLOR_TEXT_AMBER;

        dc.setColor(secColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + (w / 2),
            y + (h / 2),
            Graphics.FONT_SYSTEM_XTINY,
            secText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawSideIcons(dc as Graphics.Dc) as Void {
        var settings = System.getDeviceSettings();
        var isConnected = settings.phoneConnected;
        var alarmCount = settings.alarmCount;
        var notifCount = settings.notificationCount;

        // --- Left Side: Bluetooth + Dynamic Alarm Icon ---
        var bx = 36;
        var hasAlarm = (alarmCount != null && alarmCount > 0);

        if (hasAlarm) {
            // Stacked vertically: Bluetooth at Y: 118, Dynamic Alarm Bell at Y: 136
            var colBt = isConnected ? COLOR_TEXT_CYAN : 0x222C32;
            drawBluetoothIcon(dc, bx, 118, colBt);
            drawBellIcon(dc, bx - 5, 131, COLOR_TEXT_AMBER);
        } else {
            // Centered Bluetooth at Y: 125
            var colBt = isConnected ? COLOR_TEXT_CYAN : 0x222C32;
            drawBluetoothIcon(dc, bx, 125, colBt);
        }

        // --- Right Side: Notification Status Icon (Y: 125) ---
        var px = 244;
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
    // PROCEDURAL METRIC SLOT WITH ICON (MATHEMATICALLY CENTERED)
    // =========================================================================

    private function drawMetricSlotWithIcon(
        dc as Graphics.Dc,
        x as Lang.Number,
        y as Lang.Number,
        w as Lang.Number,
        h as Lang.Number,
        metricType as Lang.Number,
        isSunlit as Lang.Boolean
    ) as Void {
        dc.setColor(COLOR_PLATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 3);

        dc.setColor(COLOR_PLATE_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, w, h, 3);

        // Corner micro-rivets
        dc.setColor(0x405548, Graphics.COLOR_TRANSPARENT);
        dc.drawPoint(x + 2, y + 2);
        dc.drawPoint(x + w - 3, y + 2);
        dc.drawPoint(x + 2, y + h - 3);
        dc.drawPoint(x + w - 3, y + h - 3);

        if (metricType == METRIC_NONE) {
            return;
        }

        var iconType = ICON_NONE;
        var text = "";
        var col = COLOR_TEXT_AMBER;
        var iconW = 10;

        switch (metricType) {
            case METRIC_ALTITUDE:
                iconType = ICON_ALTITUDE;
                text = getAltitudeString();
                col = COLOR_TEXT_CYAN;
                iconW = 12;
                break;

            case METRIC_WEATHER:
                iconType = ICON_WEATHER;
                text = getWeatherString();
                col = COLOR_TEXT_CYAN;
                iconW = 11;
                break;

            case METRIC_CALORIES:
                iconType = ICON_FLAME;
                text = getCalories().format("%d");
                col = COLOR_TEXT_ORANGE;
                iconW = 9;
                break;

            case METRIC_STEPS:
                iconType = ICON_STEPS;
                text = getSteps().format("%d");
                col = COLOR_TEXT_GREEN;
                iconW = 10;
                break;

            case METRIC_HEART_RATE:
                iconType = ICON_HEART;
                var hr = getHeartRate();
                text = (hr != null) ? hr.format("%d") : "--";
                col = COLOR_TEXT_RED;
                iconW = 10;
                break;

            case METRIC_DISTANCE:
                iconType = ICON_DISTANCE;
                text = getDistanceString();
                col = COLOR_TEXT_AMBER;
                iconW = 9;
                break;

            case METRIC_BODY_BATTERY:
                iconType = ICON_VITALITY;
                var bb = getBodyBattery();
                text = (bb != null) ? bb.format("%d") + "%" : "--%";
                col = COLOR_TEXT_GREEN;
                iconW = 10;
                break;

            case METRIC_BATTERY:
                iconType = ICON_BATTERY;
                text = getBatteryPercent().format("%d") + "%";
                col = COLOR_TEXT_AMBER;
                iconW = 13;
                break;

            case METRIC_ACTIVE_MINUTES:
                iconType = ICON_VITALITY;
                text = getActiveMinutes().format("%d") + "m";
                col = COLOR_TEXT_AMBER;
                iconW = 10;
                break;

            case METRIC_SUNRISE_SUNSET:
                iconType = ICON_WEATHER;
                text = getSunTimeString(isSunlit);
                col = isSunlit ? COLOR_TEXT_AMBER : COLOR_TEXT_CYAN;
                iconW = 11;
                break;

            case METRIC_FLOORS:
                iconType = ICON_ALTITUDE;
                text = getFloors().format("%d") + "f";
                col = COLOR_TEXT_GREEN;
                iconW = 12;
                break;
        }

        // Strict Mathematical Centering
        var textW = dc.getTextWidthInPixels(text, Graphics.FONT_SYSTEM_XTINY);
        var gap = 4;
        var totalW = iconW + gap + textW;
        var startX = x + (w - totalW) / 2;
        var cy = y + (h / 2);

        // Draw Vector Icon
        drawIcon(dc, startX, cy, iconType, col);

        // Draw Metric Text
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
    // VECTOR ICON RENDERING SYSTEM
    // =========================================================================

    private function drawIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, iconType as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        switch (iconType) {
            case ICON_ALTITUDE:
                // Mountain icon (12x9 px)
                var my = cy - 4;
                dc.drawLine(x, my + 8, x + 12, my + 8);
                dc.drawLine(x + 1, my + 8, x + 4, my + 1);
                dc.drawLine(x + 4, my + 1, x + 7, my + 8);
                dc.drawLine(x + 6, my + 8, x + 9, my + 3);
                dc.drawLine(x + 9, my + 3, x + 12, my + 8);
                break;

            case ICON_WEATHER:
                // Cloud / Weather icon (11x9 px)
                var wy = cy - 4;
                dc.drawLine(x + 2, wy + 7, x + 9, wy + 7);
                dc.drawCircle(x + 4, wy + 5, 2);
                dc.drawCircle(x + 7, wy + 4, 3);
                dc.drawPoint(x + 9, wy + 2);
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
                // Flame icon (9x10 px)
                var fy = cy - 5;
                dc.drawLine(x + 4, fy, x + 1, fy + 6);
                dc.drawLine(x + 1, fy + 6, x + 4, fy + 9);
                dc.drawLine(x + 4, fy + 9, x + 7, fy + 6);
                dc.drawLine(x + 7, fy + 6, x + 4, fy);
                dc.drawPoint(x + 4, fy + 6);
                break;

            case ICON_STEPS:
                // Footsteps icon (10x9 px)
                var sy = cy - 4;
                dc.fillRoundedRectangle(x, sy + 3, 3, 5, 1);
                dc.fillCircle(x + 1, sy + 1, 1);
                dc.fillRoundedRectangle(x + 6, sy, 3, 5, 1);
                dc.fillCircle(x + 7, sy + 7, 1);
                break;

            case ICON_HEART:
                // Heart icon (10x8 px)
                var hy = cy - 4;
                dc.fillCircle(x + 2, hy + 2, 2);
                dc.fillCircle(x + 6, hy + 2, 2);
                dc.fillPolygon([
                    [x, hy + 3],
                    [x + 8, hy + 3],
                    [x + 4, hy + 8]
                ]);
                break;

            case ICON_DISTANCE:
                // Location / Route pin icon (9x10 px)
                var dy = cy - 5;
                dc.drawCircle(x + 4, dy + 3, 3);
                dc.drawPoint(x + 4, dy + 3);
                dc.drawLine(x + 1, dy + 4, x + 4, dy + 9);
                dc.drawLine(x + 7, dy + 4, x + 4, dy + 9);
                break;

            case ICON_VITALITY:
                // Updated Body Battery / Vitality human silhouette with energy core (10x12 px)
                drawVitalityIcon(dc, x, cy, col);
                break;

            case ICON_BATTERY:
                drawBatteryIcon(dc, x, cy - 4, getBatteryPercent(), isBatteryCharging(), col);
                break;

            case ICON_HAZARD:
                drawHazardIcon(dc, x, cy - 5, col);
                break;
        }
    }

    //! Updated Body Battery icon: Stylized human silhouette with energy core
    private function drawVitalityIcon(dc as Graphics.Dc, x as Lang.Number, cy as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        var hy = cy - 6;

        // Head
        dc.fillCircle(x + 5, hy + 2, 2);

        // Torso / shoulders silhouette
        dc.drawLine(x + 1, hy + 5, x + 9, hy + 5);
        dc.drawLine(x + 1, hy + 5, x + 2, hy + 9);
        dc.drawLine(x + 9, hy + 5, x + 8, hy + 9);
        dc.drawLine(x + 2, hy + 9, x + 5, hy + 11);
        dc.drawLine(x + 8, hy + 9, x + 5, hy + 11);

        // Glowing energy core inside chest (hot cyan/green spark)
        dc.setColor(COLOR_TEXT_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + 5, hy + 4],
            [x + 3, hy + 7],
            [x + 5, hy + 6],
            [x + 4, hy + 9],
            [x + 7, hy + 6],
            [x + 5, hy + 6]
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
    // NIXIE TUBE RENDERING (HH:MM AT Y: 100-150)
    // =========================================================================

    private function drawNixieTube(
        dc as Graphics.Dc,
        x as Lang.Number,
        y as Lang.Number,
        w as Lang.Number,
        h as Lang.Number,
        digit as Lang.Number
    ) as Void {
        dc.setColor(COLOR_SOCKET_BASE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + 2, y + h - 3, w - 4, 5, 2);
        dc.setColor(COLOR_SOCKET_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x + 2, y + h - 3, w - 4, 5, 2);

        dc.setColor(COLOR_TUBE_GLASS_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 6);

        // Anode mesh grid
        dc.setColor(COLOR_MESH_GRID, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var my = y + 5; my < y + h - 4; my += 5) {
            dc.drawLine(x + 3, my, x + w - 3, my);
        }
        for (var mx = x + 4; mx < x + w - 3; mx += 4) {
            dc.drawLine(mx, y + 5, mx, y + h - 4);
        }

        dc.setColor(COLOR_TUBE_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, y, w, h, 6);

        // Unlit ghost filament (8)
        dc.setColor(COLOR_GHOST_FILAMENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        drawNixieDigitWire(dc, x, y, w, h, 8);

        // Active digit with 3-pass neon glow
        if (digit >= 0) {
            dc.setColor(COLOR_HALO_OUTER, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            drawNixieDigitWire(dc, x, y, w, h, digit);

            dc.setColor(COLOR_GLOW_MID, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            drawNixieDigitWire(dc, x, y, w, h, digit);

            dc.setColor(COLOR_CORE_HOT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            drawNixieDigitWire(dc, x, y, w, h, digit);
        }

        // Specular reflections
        dc.setColor(COLOR_TUBE_HIGHLIGHT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x + 2, y + 8, x + 2, y + h - 8);
        dc.drawArc(x + 6, y + 6, 4, Graphics.ARC_CLOCKWISE, 180, 90);
    }

    private function drawNixieDigitWire(
        dc as Graphics.Dc,
        x0 as Lang.Number,
        y0 as Lang.Number,
        w as Lang.Number,
        h as Lang.Number,
        digit as Lang.Number
    ) as Void {
        var xl = x0 + 4;
        var xr = x0 + w - 4;
        var xm = x0 + (w / 2);
        var yt = y0 + 6;
        var yb = y0 + h - 6;
        var ym = y0 + (h / 2);
        var r  = (xr - xl) / 2;

        switch (digit) {
            case 0:
                dc.drawRoundedRectangle(xl, yt, xr - xl, yb - yt, 8);
                break;
            case 1:
                dc.drawLine(xm + 1, yt, xm + 1, yb);
                dc.drawLine(xl + 1, yt + 8, xm + 1, yt);
                dc.drawLine(xm - 5, yb, xm + 6, yb);
                break;
            case 2:
                dc.drawArc(xm, yt + r, r, Graphics.ARC_CLOCKWISE, 180, 0);
                dc.drawLine(xr, yt + r, xl, yb);
                dc.drawLine(xl, yb, xr, yb);
                dc.drawLine(xr, yb, xr, yb - 4);
                break;
            case 3:
                dc.drawArc(xm, yt + r, r, Graphics.ARC_CLOCKWISE, 180, 0);
                dc.drawLine(xr, yt + r, xm + 1, ym);
                dc.drawLine(xm + 1, ym, xr, yb - r);
                dc.drawArc(xm, yb - r, r, Graphics.ARC_CLOCKWISE, 0, 180);
                break;
            case 4:
                dc.drawLine(xr - 2, yt, xr - 2, yb);
                dc.drawLine(xr - 2, yt, xl, ym + 2);
                dc.drawLine(xl, ym + 2, xr, ym + 2);
                break;
            case 5:
                dc.drawLine(xr, yt, xl, yt);
                dc.drawLine(xl, yt, xl, ym);
                dc.drawLine(xl, ym, xm, ym);
                dc.drawArc(xm, yb - r, r, Graphics.ARC_CLOCKWISE, 90, 180);
                break;
            case 6:
                dc.drawCircle(xm, yb - r, r);
                dc.drawLine(xr - 2, yt + 2, xl, yb - r);
                break;
            case 7:
                dc.drawLine(xl, yt, xr, yt);
                dc.drawLine(xr, yt, xl + 2, yb);
                dc.drawLine(xm - 4, ym, xm + 4, ym);
                break;
            case 8:
                dc.drawCircle(xm, yt + r - 1, r - 2);
                dc.drawCircle(xm, yb - r + 1, r);
                break;
            case 9:
                dc.drawCircle(xm, yt + r, r);
                dc.drawLine(xr, yt + r, xl + 2, yb);
                break;
        }
    }

    private function drawColonIndicator(dc as Graphics.Dc) as Void {
        var colonX = 140;
        var dotY1 = 115;
        var dotY2 = 135;

        var bulbYCoords = [dotY1, dotY2];
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
    // PCB BACKGROUND DRAWING & INTEGRATED GRID FRAME
    // =========================================================================

    private function drawPcbBackground(dc as Graphics.Dc) as Void {
        dc.setColor(COLOR_PCB_BG, COLOR_PCB_BG);
        dc.clear();

        dc.setColor(COLOR_PCB_TRACE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        // Top rails feeding battery & sunlight tube
        dc.drawLine(86, 12, 86, 24);
        dc.drawLine(86, 24, 92, 24);
        dc.drawLine(194, 12, 194, 24);
        dc.drawLine(194, 24, 188, 24);

        // Guide traces framing Row 3 and Row 4
        dc.drawLine(28, 52, 50, 52);
        dc.drawLine(230, 52, 252, 52);

        dc.drawLine(26, 68, 48, 68);
        dc.drawLine(232, 68, 254, 68);

        // Side bus traces around side status icons
        dc.drawLine(16, 114, 22, 120);
        dc.drawLine(22, 120, 22, 150);
        dc.drawLine(22, 150, 16, 156);

        dc.drawLine(264, 114, 258, 120);
        dc.drawLine(258, 120, 258, 150);
        dc.drawLine(258, 150, 264, 156);

        // Integrated PCB grid rails connecting Row 6, Row 7, and Row 8
        dc.drawLine(86, 175, 86, 238);
        dc.drawLine(86, 205, 92, 205);
        dc.drawLine(86, 229, 92, 229);

        dc.drawLine(194, 175, 194, 238);
        dc.drawLine(194, 205, 188, 205);
        dc.drawLine(194, 229, 188, 229);

        // Bottom feeder traces
        dc.drawLine(18, 238, 42, 238);
        dc.drawLine(42, 238, 42, 218);
        dc.drawLine(262, 238, 238, 238);
        dc.drawLine(238, 238, 238, 218);

        dc.drawLine(80, 252, 200, 252);

        // Solder Vias with copper pads
        var viaCoords = [
            [86, 12], [194, 12],
            [28, 52], [252, 52],
            [26, 68], [254, 68],
            [22, 120], [22, 150],
            [258, 120], [258, 150],
            [86, 175], [194, 175],
            [86, 205], [194, 205],
            [86, 229], [194, 229],
            [42, 238], [238, 238],
            [80, 252], [200, 252]
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
        drawFiducial(dc, 16, 135);
        drawFiducial(dc, 264, 135);
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
        var boltPositions = [
            [38, 52],
            [242, 52],
            [48, 224],
            [232, 224]
        ];

        dc.setPenWidth(1);
        for (var i = 0; i < boltPositions.size(); i++) {
            var bx = boltPositions[i][0];
            var by = boltPositions[i][1];

            dc.setColor(COLOR_SCREW_RIM, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, 6);

            dc.setColor(COLOR_SCREW_HEAD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, 4);

            dc.setColor(COLOR_SCREW_SLOT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(bx - 3, by - 3, bx + 3, by + 3);
        }
    }
}
