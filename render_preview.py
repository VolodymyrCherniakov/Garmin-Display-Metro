import math
from PIL import Image, ImageDraw, ImageFont

def render_watchface():
    w, h = 280, 280
    cx, cy = 140, 140
    img = Image.new("RGBA", (w, h), (8, 16, 12, 255)) # COLOR_PCB_BG
    draw = ImageDraw.Draw(img)

    # 1. PCB Traces & Integrated Grid Frame
    trace_col = (24, 48, 32, 255) # COLOR_PCB_TRACE
    via_pad = (74, 64, 32, 255)   # COLOR_PCB_VIA_PAD
    via_bg = (8, 16, 12, 255)
    silk_col = (45, 66, 52, 255)

    def draw_via(x, y):
        draw.ellipse([x-3, y-3, x+3, y+3], fill=via_pad)
        draw.ellipse([x-1, y-1, x+1, y+1], fill=via_bg)

    def draw_fiducial(x, y):
        draw.line([x-3, y, x+3, y], fill=silk_col, width=1)
        draw.line([x, y-3, x, y+3], fill=silk_col, width=1)
        draw.ellipse([x-2, y-2, x+2, y+2], outline=silk_col, width=1)

    # Top rails feeding battery & sunlight tube
    draw.line([86, 12, 86, 24], fill=trace_col, width=2)
    draw.line([86, 24, 92, 24], fill=trace_col, width=2)
    draw.line([194, 12, 194, 24], fill=trace_col, width=2)
    draw.line([194, 24, 188, 24], fill=trace_col, width=2)

    # Guide traces framing Row 3 and Row 4
    draw.line([28, 52, 50, 52], fill=trace_col, width=2)
    draw.line([230, 52, 252, 52], fill=trace_col, width=2)
    draw.line([26, 68, 48, 68], fill=trace_col, width=2)
    draw.line([232, 68, 254, 68], fill=trace_col, width=2)

    # Side bus traces around side status icons
    draw.line([16, 114, 22, 120], fill=trace_col, width=2)
    draw.line([22, 120, 22, 150], fill=trace_col, width=2)
    draw.line([22, 150, 16, 156], fill=trace_col, width=2)

    draw.line([264, 114, 258, 120], fill=trace_col, width=2)
    draw.line([258, 120, 258, 150], fill=trace_col, width=2)
    draw.line([258, 150, 264, 156], fill=trace_col, width=2)

    # Integrated PCB grid rails connecting Row 6, Row 7, and Row 8
    draw.line([86, 175, 86, 238], fill=trace_col, width=2)
    draw.line([86, 205, 92, 205], fill=trace_col, width=2)
    draw.line([86, 229, 92, 229], fill=trace_col, width=2)

    draw.line([194, 175, 194, 238], fill=trace_col, width=2)
    draw.line([194, 205, 188, 205], fill=trace_col, width=2)
    draw.line([194, 229, 188, 229], fill=trace_col, width=2)

    # Bottom feeder traces
    draw.line([18, 238, 42, 238], fill=trace_col, width=2)
    draw.line([42, 238, 42, 218], fill=trace_col, width=2)
    draw.line([262, 238, 238, 238], fill=trace_col, width=2)
    draw.line([238, 238, 238, 218], fill=trace_col, width=2)
    draw.line([80, 252, 200, 252], fill=trace_col, width=2)

    vias = [
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
    ]
    for vx, vy in vias:
        draw_via(vx, vy)

    draw_fiducial(16, 135)
    draw_fiducial(264, 135)

    # Font setup
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 9)
        font_sm = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 8)
        font_sec = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 8)
    except:
        font = ImageFont.load_default()
        font_sm = font
        font_sec = font

    # 1. Row 1: Centralized Battery at very top (Y: ~10-16)
    bat_pct = 85
    bat_str = f"{bat_pct}%"
    bbox = font.getbbox(bat_str)
    tw = bbox[2] - bbox[0]
    total_w = 14 + 4 + tw
    start_x = cx - total_w // 2
    bat_y = 12
    bx, by = start_x, bat_y - 4
    draw.rounded_rectangle([bx, by, bx + 12, by + 8], radius=2, outline=(255, 170, 0, 255), width=1)
    draw.rectangle([bx + 12, by + 2, bx + 14, by + 6], fill=(255, 170, 0, 255))
    fill_w = int((bat_pct / 100.0) * 8)
    draw.rectangle([bx + 2, by + 2, bx + 2 + fill_w, by + 6], fill=(255, 170, 0, 255))
    draw.text((start_x + 18, bat_y - 5), bat_str, font=font, fill=(255, 170, 0, 255))

    # 2. Row 2: Sunlight Tube directly below battery (Y: ~24-34)
    tx, ty, tw_t, th_t = 96, 24, 88, 10
    bw, bh = 8, 12
    draw.rounded_rectangle([tx - 4, ty - 1, tx - 4 + bw, ty - 1 + bh], radius=2, fill=(72, 58, 38, 255), outline=(46, 36, 22, 255))
    draw.rounded_rectangle([tx + tw_t - bw + 4, ty - 1, tx + tw_t + 4, ty - 1 + bh], radius=2, fill=(72, 58, 38, 255), outline=(46, 36, 22, 255))
    draw.rounded_rectangle([tx, ty, tx + tw_t, ty + th_t], radius=4, fill=(6, 29, 43, 255))
    draw.rounded_rectangle([tx, ty, tx + tw_t, ty + th_t], radius=4, outline=(0, 68, 136, 255), width=2)
    draw.rounded_rectangle([tx + 1, ty + 1, tx + tw_t - 1, ty + th_t - 1], radius=3, outline=(0, 170, 255, 255), width=1)
    wy = ty + th_t // 2
    draw.line([tx + bw - 2, wy, tx + tw_t - bw + 2, wy], fill=(0, 170, 255, 255), width=2)
    draw.line([tx + bw - 2, wy, tx + tw_t - bw + 2, wy], fill=(238, 255, 255, 255), width=1)
    draw.ellipse([cx - 3, wy - 3, cx + 3, wy + 3], fill=(0, 170, 255, 255))
    draw.ellipse([cx - 1, wy - 1, cx + 1, wy + 1], fill=(238, 255, 255, 255))
    draw.line([tx + 8, ty + 2, tx + tw_t - 8, ty + 2], fill=(170, 238, 255, 200), width=1)

    # Helper: draw stamped plate
    def draw_plate(x, y, w, h):
        draw.rounded_rectangle([x, y, x + w, y + h], radius=3, fill=(12, 20, 16, 255), outline=(36, 54, 42, 255), width=1)
        draw.point([x + 2, y + 2], fill=(64, 85, 72, 255))
        draw.point([x + w - 3, y + 2], fill=(64, 85, 72, 255))
        draw.point([x + 2, y + h - 3], fill=(64, 85, 72, 255))
        draw.point([x + w - 3, y + h - 3], fill=(64, 85, 72, 255))

    # 3. Row 3: Upper 2 Symmetrical Slots tightly placed below tube (Y: 42 - 62)
    draw_plate(54, 42, 78, 20)
    draw_plate(148, 42, 78, 20)

    # Altitude Mountain Icon + "145m"
    alt_txt = "145m"
    bbox = font.getbbox(alt_txt)
    atw = bbox[2] - bbox[0]
    alt_w = 12 + 4 + atw
    alt_sx = 93 - alt_w // 2
    mx, my = alt_sx, 52 - 4
    draw.line([mx, my + 8, mx + 12, my + 8], fill=(0, 208, 255, 255), width=1)
    draw.line([mx + 1, my + 8, mx + 4, my + 1], fill=(0, 208, 255, 255), width=1)
    draw.line([mx + 4, my + 1, mx + 7, my + 8], fill=(0, 208, 255, 255), width=1)
    draw.line([mx + 6, my + 8, mx + 9, my + 3], fill=(0, 208, 255, 255), width=1)
    draw.line([mx + 9, my + 3, mx + 12, my + 8], fill=(0, 208, 255, 255), width=1)
    draw.text((alt_sx + 16, 47), alt_txt, font=font, fill=(0, 208, 255, 255))

    # Weather Cloud Icon + "21°C"
    wea_txt = "21°C"
    bbox = font.getbbox(wea_txt)
    wtw = bbox[2] - bbox[0]
    wea_w = 11 + 4 + wtw
    wea_sx = 187 - wea_w // 2
    wx, wy_i = wea_sx, 52 - 4
    draw.line([wx + 2, wy_i + 7, wx + 9, wy_i + 7], fill=(0, 208, 255, 255), width=1)
    draw.ellipse([wx + 2, wy_i + 3, wx + 6, wy_i + 7], outline=(0, 208, 255, 255))
    draw.ellipse([wx + 4, wy_i + 1, wx + 9, wy_i + 7], outline=(0, 208, 255, 255))
    draw.point([wx + 9, wy_i + 2], fill=(0, 208, 255, 255))
    draw.text((wea_sx + 15, 47), wea_txt, font=font, fill=(0, 208, 255, 255))

    # 4. Row 4: Full-Width 3-Slot Date Bar (Y: 72 - 90)
    draw.rounded_rectangle([36, 72, 244, 90], radius=3, fill=(12, 20, 16, 255), outline=(36, 54, 42, 255), width=1)
    draw.line([96, 73, 96, 89], fill=(36, 54, 42, 255), width=1)
    draw.line([184, 73, 184, 89], fill=(36, 54, 42, 255), width=1)
    draw.point([38, 74], fill=(64, 85, 72, 255))
    draw.point([242, 74], fill=(64, 85, 72, 255))
    draw.point([38, 88], fill=(64, 85, 72, 255))
    draw.point([242, 88], fill=(64, 85, 72, 255))

    # Left: Day
    draw.text((58, 76), "WED", font=font, fill=(255, 170, 0, 255))

    # Center: Calendar + 30 SEP
    date_str = "30 SEP"
    bbox = font.getbbox(date_str)
    dtw = bbox[2] - bbox[0]
    cal_w = 10 + 4 + dtw
    cal_sx = 140 - cal_w // 2
    cx_i, cy_i = cal_sx, 76
    draw.rounded_rectangle([cx_i, cy_i + 2, cx_i + 10, cy_i + 10], radius=1, outline=(255, 170, 0, 255), width=1)
    draw.rectangle([cx_i + 1, cy_i + 2, cx_i + 9, cy_i + 4], fill=(255, 170, 0, 255))
    draw.line([cx_i + 2, cy_i, cx_i + 2, cy_i + 3], fill=(255, 170, 0, 255), width=1)
    draw.line([cx_i + 7, cy_i, cx_i + 7, cy_i + 3], fill=(255, 170, 0, 255), width=1)
    draw.text((cal_sx + 14, 76), date_str, font=font, fill=(255, 170, 0, 255))

    # Right: Hazard / Status Icon
    hx_i, hy_i = 214 - 5, 76
    draw.polygon([(hx_i + 5, hy_i), (hx_i + 9, hy_i + 8), (hx_i + 1, hy_i + 8)], fill=(255, 170, 0, 255))
    draw.point([hx_i + 5, hy_i + 4], fill=(12, 20, 16, 255))
    draw.point([hx_i + 5, hy_i + 6], fill=(12, 20, 16, 255))

    # 5. Row 5: Centered Nixie Tubes (HH:MM at Y: 100 - 150)
    tube_w, tube_h = 26, 50
    tube_y = 100
    digits = [1, 2, 3, 4]
    tube_xs = [64, 94, 160, 190]

    def draw_digit_wire(x0, y0, w, h, digit, col, width):
        xl = x0 + 4
        xr = x0 + w - 4
        xm = x0 + w // 2
        yt = y0 + 6
        yb = y0 + h - 6
        ym = y0 + h // 2
        r = (xr - xl) // 2

        if digit == 1:
            draw.line([xm + 1, yt, xm + 1, yb], fill=col, width=width)
            draw.line([xl + 1, yt + 8, xm + 1, yt], fill=col, width=width)
            draw.line([xm - 5, yb, xm + 6, yb], fill=col, width=width)
        elif digit == 2:
            draw.arc([xm - r, yt, xm + r, yt + 2*r], start=180, end=360, fill=col, width=width)
            draw.line([xr, yt + r, xl, yb], fill=col, width=width)
            draw.line([xl, yb, xr, yb], fill=col, width=width)
            draw.line([xr, yb, xr, yb - 4], fill=col, width=width)
        elif digit == 3:
            draw.arc([xm - r, yt, xm + r, yt + 2*r], start=180, end=360, fill=col, width=width)
            draw.line([xr, yt + r, xm + 1, ym], fill=col, width=width)
            draw.line([xm + 1, ym, xr, yb - r], fill=col, width=width)
            draw.arc([xm - r, yb - 2*r, xm + r, yb], start=0, end=180, fill=col, width=width)
        elif digit == 4:
            draw.line([xr - 2, yt, xr - 2, yb], fill=col, width=width)
            draw.line([xr - 2, yt, xl, ym + 2], fill=col, width=width)
            draw.line([xl, ym + 2, xr, ym + 2], fill=col, width=width)
        elif digit == 8:
            draw.ellipse([xm - r + 1, yt, xm + r - 1, yt + 2*r - 2], outline=col, width=width)
            draw.ellipse([xm - r, yb - 2*r, xm + r, yb], outline=col, width=width)

    for i, x in enumerate(tube_xs):
        draw.rounded_rectangle([x + 2, tube_y + tube_h - 3, x + tube_w - 2, tube_y + tube_h + 2], radius=2, fill=(31, 36, 38, 255), outline=(16, 19, 20, 255))
        draw.rounded_rectangle([x, tube_y, x + tube_w, tube_y + tube_h], radius=6, fill=(10, 13, 11, 255))
        for my in range(tube_y + 5, tube_y + tube_h - 4, 5):
            draw.line([x + 3, my, x + tube_w - 3, my], fill=(26, 34, 28, 255), width=1)
        for mx in range(x + 4, x + tube_w - 3, 4):
            draw.line([mx, tube_y + 5, mx, tube_y + tube_h - 4], fill=(26, 34, 28, 255), width=1)
        draw.rounded_rectangle([x, tube_y, x + tube_w, tube_y + tube_h], radius=6, outline=(56, 66, 62, 255), width=2)
        draw_digit_wire(x, tube_y, tube_w, tube_h, 8, (34, 20, 10, 255), 1)
        d = digits[i]
        draw_digit_wire(x, tube_y, tube_w, tube_h, d, (136, 34, 0, 255), 3)
        draw_digit_wire(x, tube_y, tube_w, tube_h, d, (255, 85, 0, 255), 2)
        draw_digit_wire(x, tube_y, tube_w, tube_h, d, (255, 255, 102, 255), 1)
        draw.line([x + 2, tube_y + 8, x + 2, tube_y + tube_h - 8], fill=(88, 120, 128, 180), width=1)

    # Colon bulbs (X: 140, Y: 115 and 135)
    for cy_c in [115, 135]:
        draw.rounded_rectangle([140 - 3, cy_c - 5, 140 + 3, cy_c + 5], radius=2, fill=(10, 13, 11, 255), outline=(56, 66, 62, 255))
        draw.ellipse([140 - 3, cy_c - 3, 140 + 3, cy_c + 3], fill=(136, 34, 0, 255))
        draw.ellipse([140 - 2, cy_c - 2, 140 + 2, cy_c + 2], fill=(255, 85, 0, 255))
        draw.ellipse([140 - 1, cy_c - 1, 140 + 1, cy_c + 1], fill=(255, 255, 102, 255))

    # Sub-script Seconds directly underneath minutes digits (X: 172 to 204, Y: 152 to 164)
    draw.rounded_rectangle([172, 152, 204, 164], radius=2, fill=(12, 20, 16, 255), outline=(36, 54, 42, 255), width=1)
    draw.text((182, 154), "42", font=font_sec, fill=(255, 170, 0, 255))

    # Left Side Icons: Bluetooth + Dynamic Alarm Bell (Stacked)
    # Bluetooth at Y: 118
    draw.line([36, 112, 36, 124], fill=(0, 208, 255, 255), width=1)
    draw.line([33, 115, 39, 121], fill=(0, 208, 255, 255), width=1)
    draw.line([39, 121, 36, 124], fill=(0, 208, 255, 255), width=1)
    draw.line([33, 121, 39, 115], fill=(0, 208, 255, 255), width=1)
    draw.line([39, 115, 36, 112], fill=(0, 208, 255, 255), width=1)

    # Dynamic Alarm Bell at Y: 136
    draw.arc([32, 131, 40, 138], start=180, end=360, fill=(255, 170, 0, 255), width=1)
    draw.line([31, 137, 41, 137], fill=(255, 170, 0, 255), width=1)
    draw.point([36, 139], fill=(255, 170, 0, 255))

    # Right Side Icon: Notification message bubble at Y: 125
    draw.rounded_rectangle([239, 121, 249, 129], radius=2, outline=(0, 208, 255, 255), width=1)
    draw.line([241, 128, 243, 130], fill=(0, 208, 255, 255), width=1)
    draw.line([243, 130, 243, 128], fill=(0, 208, 255, 255), width=1)
    draw.ellipse([247, 119, 250, 122], fill=(0, 208, 255, 255))

    # 6. Row 6: Lower 3 Data Slots right under time block (Y: 170 - 190)
    # Left: Calories (38-100, w=62), Center: Steps (108-172, w=64), Right: Heart Rate (180-242, w=62)
    draw_plate(38, 170, 62, 20)
    draw_plate(108, 170, 64, 20)
    draw_plate(180, 170, 62, 20)

    # Calories: Flame Icon + "1840"
    cal_txt = "1840"
    bbox = font.getbbox(cal_txt)
    ctw = bbox[2] - bbox[0]
    cal_w = 9 + 4 + ctw
    cal_sx = 69 - cal_w // 2
    fx, fy = cal_sx, 180 - 5
    draw.line([fx + 4, fy, fx + 1, fy + 6], fill=(255, 119, 0, 255), width=1)
    draw.line([fx + 1, fy + 6, fx + 4, fy + 9], fill=(255, 119, 0, 255), width=1)
    draw.line([fx + 4, fy + 9, fx + 7, fy + 6], fill=(255, 119, 0, 255), width=1)
    draw.line([fx + 7, fy + 6, fx + 4, fy], fill=(255, 119, 0, 255), width=1)
    draw.point([fx + 4, fy + 6], fill=(255, 119, 0, 255))
    draw.text((cal_sx + 13, 175), cal_txt, font=font, fill=(255, 119, 0, 255))

    # Steps: Footsteps Icon + "10741"
    step_txt = "10741"
    bbox = font.getbbox(step_txt)
    stw = bbox[2] - bbox[0]
    step_w = 10 + 4 + stw
    step_sx = 140 - step_w // 2
    sx, sy = step_sx, 180 - 4
    draw.rounded_rectangle([sx, sy + 3, sx + 3, sy + 8], radius=1, fill=(0, 255, 136, 255))
    draw.ellipse([sx, sy, sx + 2, sy + 2], fill=(0, 255, 136, 255))
    draw.rounded_rectangle([sx + 6, sy, sx + 9, sy + 5], radius=1, fill=(0, 255, 136, 255))
    draw.ellipse([sx + 6, sy + 6, sx + 8, sy + 8], fill=(0, 255, 136, 255))
    draw.text((step_sx + 14, 175), step_txt, font=font, fill=(0, 255, 136, 255))

    # Heart Rate: Heart Icon + "80"
    hr_txt = "80"
    bbox = font.getbbox(hr_txt)
    htw = bbox[2] - bbox[0]
    hr_w = 10 + 4 + htw
    hr_sx = 211 - hr_w // 2
    hx, hy = hr_sx, 180 - 4
    draw.ellipse([hx + 1, hy, hx + 4, hy + 3], fill=(255, 51, 0, 255))
    draw.ellipse([hx + 5, hy, hx + 8, hy + 3], fill=(255, 51, 0, 255))
    draw.polygon([(hx, hy + 2), (hx + 9, hy + 2), (hx + 4, hy + 8)], fill=(255, 51, 0, 255))
    draw.text((hr_sx + 14, 175), hr_txt, font=font, fill=(255, 51, 0, 255))

    # 7. Row 7: Distance (Y: 196 - 214, center 205)
    draw_plate(92, 196, 96, 18)
    dist_txt = "5.4 km"
    bbox = font_sm.getbbox(dist_txt)
    dtw = bbox[2] - bbox[0]
    dist_w = 9 + 4 + dtw
    dist_sx = 140 - dist_w // 2
    dx, dy = dist_sx, 205 - 5
    draw.ellipse([dx + 1, dy, dx + 7, dy + 6], outline=(255, 170, 0, 255), width=1)
    draw.point([dx + 4, dy + 3], fill=(255, 170, 0, 255))
    draw.line([dx + 1, dy + 4, dx + 4, dy + 9], fill=(255, 170, 0, 255), width=1)
    draw.line([dx + 7, dy + 4, dx + 4, dy + 9], fill=(255, 170, 0, 255), width=1)
    draw.text((dist_sx + 13, 201), dist_txt, font=font_sm, fill=(255, 170, 0, 255))

    # 8. Row 8: Updated Body Battery Vitality Icon + "75%" (Y: 220 - 238, center 229)
    draw_plate(92, 220, 96, 18)
    bb_txt = "75%"
    bbox = font_sm.getbbox(bb_txt)
    btw = bbox[2] - bbox[0]
    bb_w = 10 + 4 + btw
    bb_sx = 140 - bb_w // 2
    vx, vy = bb_sx, 229 - 6
    # Human silhouette + energy core
    draw.ellipse([vx + 3, vy, vx + 7, vy + 4], fill=(0, 255, 136, 255)) # Head
    draw.line([vx + 1, vy + 5, vx + 9, vy + 5], fill=(0, 255, 136, 255), width=1) # Shoulders
    draw.line([vx + 1, vy + 5, vx + 2, vy + 9], fill=(0, 255, 136, 255), width=1)
    draw.line([vx + 9, vy + 5, vx + 8, vy + 9], fill=(0, 255, 136, 255), width=1)
    draw.line([vx + 2, vy + 9, vx + 5, vy + 11], fill=(0, 255, 136, 255), width=1)
    draw.line([vx + 8, vy + 9, vx + 5, vy + 11], fill=(0, 255, 136, 255), width=1)
    # Energy core
    draw.polygon([(vx + 5, vy + 4), (vx + 3, vy + 7), (vx + 5, vy + 6), (vx + 4, vy + 9), (vx + 7, vy + 6), (vx + 5, vy + 6)], fill=(238, 255, 255, 255))
    draw.text((bb_sx + 14, 225), bb_txt, font=font_sm, fill=(0, 255, 136, 255))

    # 9. Chassis Bolts (Perimeter Corner Screws)
    bolts = [[38, 52], [242, 52], [48, 224], [232, 224]]
    for bx, by in bolts:
        draw.ellipse([bx - 6, by - 6, bx + 6, by + 6], fill=(64, 69, 74, 255))
        draw.ellipse([bx - 4, by - 4, bx + 4, by + 4], fill=(40, 44, 48, 255))
        draw.line([bx - 3, by - 3, bx + 3, by + 3], fill=(16, 18, 20, 255), width=1)

    # 10. Circular mask for 280x280 round display
    mask = Image.new("L", (w, h), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse([0, 0, w - 1, h - 1], fill=255)
    output = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    output.paste(img, (0, 0), mask)

    output.save("preview_full.png")
    print("Successfully generated preview_full.png")

if __name__ == "__main__":
    render_watchface()
