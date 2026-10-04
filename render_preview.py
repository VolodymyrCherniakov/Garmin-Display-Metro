import math
from PIL import Image, ImageDraw, ImageFont

# 7-Segment Display Definitions
# Segments: a=bit0(1), b=bit1(2), c=bit2(4), d=bit3(8), e=bit4(16), f=bit5(32), g=bit6(64)
SEGMENT_MASKS = [
    0x3F, # 0: a, b, c, d, e, f
    0x06, # 1: b, c
    0x5B, # 2: a, b, d, e, g
    0x4F, # 3: a, b, c, d, g
    0x66, # 4: b, c, f, g
    0x6D, # 5: a, c, d, f, g
    0x7D, # 6: a, c, d, e, f, g
    0x07, # 7: a, b, c
    0x7F, # 8: a, b, c, d, e, f, g
    0x6F  # 9: a, b, c, d, f, g
]

# Base 7-segment polygon coordinates (relative to digit top-left origin, 26x52 px, thickness 5)
BASE_SEG_POLYGONS = [
    [(3, 2), (5, 0), (21, 0), (23, 2), (21, 4), (5, 4)],        # a (top horizontal)
    [(24, 3), (26, 5), (26, 23), (24, 25), (22, 23), (22, 5)],   # b (upper-right vertical)
    [(24, 27), (26, 29), (26, 47), (24, 49), (22, 47), (22, 29)],# c (lower-right vertical)
    [(3, 50), (5, 48), (21, 48), (23, 50), (21, 52), (5, 52)],   # d (bottom horizontal)
    [(2, 27), (4, 29), (4, 47), (2, 49), (0, 47), (0, 29)],      # e (lower-left vertical)
    [(2, 3), (4, 5), (4, 23), (2, 25), (0, 23), (0, 5)],        # f (upper-left vertical)
    [(3, 26), (5, 24), (21, 24), (23, 26), (21, 28), (5, 28)]    # g (middle horizontal)
]

BASE_SPINE_LINES = [
    [(5, 2), (21, 2)],   # a
    [(24, 5), (24, 23)], # b
    [(24, 29), (24, 47)],# c
    [(5, 50), (21, 50)], # d
    [(2, 29), (2, 47)],  # e
    [(2, 5), (2, 23)],   # f
    [(5, 26), (21, 26)]  # g
]

def draw_7seg_nixie_tube(draw, tx, ty, tw, th, digit):
    # 1. Stamped metal base socket
    draw.rounded_rectangle([tx + 3, ty + th - 3, tx + tw - 3, ty + th + 4], radius=2, fill=(31, 36, 38, 255), outline=(16, 19, 20, 255))
    # 2. Glass tube cavity
    draw.rounded_rectangle([tx, ty, tx + tw, ty + th], radius=8, fill=(10, 13, 11, 255))
    # 3. Anode mesh grid
    for my in range(ty + 8, ty + th - 6, 6):
        draw.line([tx + 4, my, tx + tw - 4, my], fill=(26, 34, 28, 255), width=1)
    for mx in range(tx + 5, tx + tw - 4, 5):
        draw.line([mx, ty + 8, mx, ty + th - 6], fill=(26, 34, 28, 255), width=1)
    # 4. Clear glass capsule border
    draw.rounded_rectangle([tx, ty, tx + tw, ty + th], radius=8, outline=(56, 66, 62, 255), width=2)

    # 5. 7-Segment Digit
    ox = tx + 6
    oy = ty + 9
    mask = SEGMENT_MASKS[digit] if (digit is not None and 0 <= digit <= 9) else 0

    # Unlit ghost segments (faint "8" in every tube)
    ghost_col = (34, 20, 10, 255)
    for s in range(7):
        if not (mask & (1 << s)):
            poly = [(x + ox, y + oy) for x, y in BASE_SEG_POLYGONS[s]]
            draw.polygon(poly, fill=ghost_col)

    # Lit segments with multi-pass neon glow
    if mask != 0:
        # Pass 1: Outer halo
        halo_col = (136, 34, 0, 255)
        for s in range(7):
            if mask & (1 << s):
                p1, p2 = BASE_SPINE_LINES[s]
                draw.line([(p1[0] + ox, p1[1] + oy), (p2[0] + ox, p2[1] + oy)], fill=halo_col, width=8)

        # Pass 2: Bright neon orange mid glow
        glow_col = (255, 85, 0, 255)
        for s in range(7):
            if mask & (1 << s):
                poly = [(x + ox, y + oy) for x, y in BASE_SEG_POLYGONS[s]]
                draw.polygon(poly, fill=glow_col)

        # Pass 3: White-hot core filament spine
        core_col = (255, 255, 120, 255)
        for s in range(7):
            if mask & (1 << s):
                p1, p2 = BASE_SPINE_LINES[s]
                draw.line([(p1[0] + ox, p1[1] + oy), (p2[0] + ox, p2[1] + oy)], fill=core_col, width=1)

    # 6. Highlights
    draw.line([tx + 2, ty + 10, tx + 2, ty + th - 10], fill=(88, 120, 128, 180), width=1)
    draw.arc([tx + 6, ty + 6, tx + 16, ty + 16], start=180, end=270, fill=(88, 120, 128, 180), width=1)

def render_watchface(lit=True, output_path="preview_full.png"):
    w, h = 280, 280
    cx, cy = 140, 140
    img = Image.new("RGBA", (w, h), (8, 16, 12, 255)) # COLOR_PCB_BG
    draw = ImageDraw.Draw(img)

    # Color Palette
    pcb_bg = (8, 16, 12, 255)
    plate_bg = (12, 20, 16, 255)
    plate_border = (36, 54, 42, 255) # Dim dark-green inner divider
    trace_col = (18, 36, 24, 255)    # Muted, darker outside trace
    via_pad = (58, 50, 24, 255)
    silk_col = (35, 52, 40, 255)

    amber = (255, 170, 0, 255)
    orange = (255, 119, 0, 255)
    green = (0, 255, 136, 255)
    cyan = (0, 208, 255, 255)
    red = (255, 51, 0, 255)

    # Font setup
    try:
        font_bat = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 9)
        font_val = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 9)
        font_sec = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 8)
    except:
        font_bat = ImageFont.load_default()
        font_val = font_bat
        font_sec = font_bat

    # 1. PCB Background Traces (Muted, Darker, Outside Only!)
    draw.line([96, 25, 96, 42], fill=trace_col, width=1)
    draw.line([184, 25, 184, 42], fill=trace_col, width=1)
    draw.line([25, 120, 25, 160], fill=trace_col, width=1)
    draw.line([255, 100, 255, 140], fill=trace_col, width=1)

    # Traces in the transition area between Time and Grid (Y: 180 - 200)
    draw.line([64, 188, 216, 188], fill=trace_col, width=1)
    draw.line([64, 188, 64, 196], fill=trace_col, width=1)
    draw.line([216, 188, 216, 196], fill=trace_col, width=1)

    # Side traces outside Row B and C
    draw.line([48, 224, 48, 246], fill=trace_col, width=1)
    draw.line([232, 224, 232, 246], fill=trace_col, width=1)

    vias = [
        [96, 14], [184, 14],
        [25, 120], [25, 160],
        [255, 100], [255, 140],
        [64, 188], [140, 188], [216, 188],
        [48, 246], [232, 246]
    ]
    for vx, vy in vias:
        draw.ellipse([vx-2, vy-2, vx+2, vy+2], fill=via_pad)
        draw.ellipse([vx-1, vy-1, vx+1, vy+1], fill=pcb_bg)

    draw.line([21, 140, 27, 140], fill=silk_col, width=1)
    draw.line([24, 137, 24, 143], fill=silk_col, width=1)
    draw.ellipse([22, 138, 26, 142], outline=silk_col, width=1)

    # 2. Row 1: Centralized Top Battery (Center Y = 25)
    bat_pct = 85
    bat_str = f"{bat_pct}%"
    bbox = font_bat.getbbox(bat_str)
    tw = bbox[2] - bbox[0]
    total_w = 14 + 4 + tw
    start_x = cx - total_w // 2
    bat_y = 25
    bx, by = start_x, bat_y - 4
    draw.rounded_rectangle([bx, by, bx + 12, by + 8], radius=2, outline=amber, width=1)
    draw.rectangle([bx + 12, by + 2, bx + 14, by + 6], fill=amber)
    draw.rectangle([bx + 2, by + 2, bx + 2 + int((bat_pct / 100.0) * 8), by + 6], fill=amber)
    draw.text((start_x + 18, bat_y - 5), bat_str, font=font_bat, fill=amber)

    # 3. Row 2: BIGGER Sunlight Neon Tube (W=116, H=15, X=82-198, Y: 42-57, Center Y = 49.5)
    tx, ty, tw_t, th_t = 82, 42, 116, 15
    bw, bh = 8, 17

    if lit:
        # Copper Mounting Brackets
        draw.rounded_rectangle([tx - 4, ty - 1, tx - 4 + bw, ty - 1 + bh], radius=2, fill=(90, 72, 48, 255), outline=(56, 44, 30, 255))
        draw.rounded_rectangle([tx + tw_t - bw + 4, ty - 1, tx + tw_t + 4, ty - 1 + bh], radius=2, fill=(90, 72, 48, 255), outline=(56, 44, 30, 255))
        for rx in [tx - 1, tx + tw_t + 1]:
            draw.ellipse([rx - 1, ty + 2, rx + 1, ty + 4], fill=(156, 126, 76, 255))
            draw.ellipse([rx - 1, ty + bh - 5, rx + 1, ty + bh - 3], fill=(156, 126, 76, 255))

        # Glowing Glass Body (Vibrant electric cyan bloom & white-hot core)
        draw.rounded_rectangle([tx, ty, tx + tw_t, ty + th_t], radius=5, fill=(6, 29, 43, 255))
        draw.rounded_rectangle([tx - 1, ty - 1, tx + tw_t + 1, ty + th_t + 1], radius=6, outline=(0, 85, 170, 255), width=2)
        draw.rounded_rectangle([tx, ty, tx + tw_t, ty + th_t], radius=5, outline=(0, 204, 255, 255), width=1)
        wy = ty + th_t // 2
        draw.line([tx + bw - 2, wy, tx + tw_t - bw + 2, wy], fill=(0, 85, 170, 255), width=6)
        draw.line([tx + bw - 2, wy, tx + tw_t - bw + 2, wy], fill=(0, 204, 255, 255), width=3)
        draw.line([tx + bw - 2, wy, tx + tw_t - bw + 2, wy], fill=(255, 255, 255, 255), width=1)
        draw.ellipse([cx - 5, wy - 5, cx + 5, wy + 5], fill=(0, 204, 255, 255))
        draw.ellipse([cx - 2, wy - 2, cx + 2, wy + 2], fill=(255, 255, 255, 255))
        draw.line([tx + 10, ty + 2, tx + tw_t - 10, ty + 2], fill=(170, 238, 255, 220), width=1)
    else:
        # Dark Unlit Brackets
        draw.rounded_rectangle([tx - 4, ty - 1, tx - 4 + bw, ty - 1 + bh], radius=2, fill=(40, 38, 36, 255), outline=(22, 22, 24, 255))
        draw.rounded_rectangle([tx + tw_t - bw + 4, ty - 1, tx + tw_t + 4, ty - 1 + bh], radius=2, fill=(40, 38, 36, 255), outline=(22, 22, 24, 255))
        for rx in [tx - 1, tx + tw_t + 1]:
            draw.ellipse([rx - 1, ty + 2, rx + 1, ty + 4], fill=(72, 66, 58, 255))
            draw.ellipse([rx - 1, ty + bh - 5, rx + 1, ty + bh - 3], fill=(72, 66, 58, 255))

        # Unlit Glass Body
        draw.rounded_rectangle([tx, ty, tx + tw_t, ty + th_t], radius=5, fill=(10, 16, 20, 255))
        draw.rounded_rectangle([tx, ty, tx + tw_t, ty + th_t], radius=5, outline=(42, 52, 58, 255), width=1)
        wy = ty + th_t // 2
        draw.line([tx + bw - 2, wy, tx + tw_t - bw + 2, wy], fill=(34, 44, 50, 255), width=1)
        draw.ellipse([cx - 3, wy - 3, cx + 3, wy + 3], fill=(24, 36, 44, 255))
        draw.line([tx + 10, ty + 2, tx + tw_t - 10, ty + 2], fill=(24, 40, 52, 255), width=1)

    # 4. Row 3: 7-SEGMENT NIXIE CLOCK CENTERED AT (140, 140)
    # Tubes: W=38, H=70, vertically centered at Y=140 -> Y: 105 - 175
    tube_w, tube_h = 38, 70
    tube_y = 105
    tube_xs = [54, 96, 146, 188]
    digits = [1, 2, 3, 4]

    for i, x in enumerate(tube_xs):
        draw_7seg_nixie_tube(draw, x, tube_y, tube_w, tube_h, digits[i])

    # INS-1 Colon bulbs (Centered at X: 140, symmetric around Y: 140 -> Y: 126 and 154)
    for cy_c in [126, 154]:
        draw.rounded_rectangle([140 - 3, cy_c - 5, 140 + 3, cy_c + 5], radius=2, fill=(10, 13, 11, 255), outline=(56, 66, 62, 255))
        draw.ellipse([140 - 3, cy_c - 3, 140 + 3, cy_c + 3], fill=(136, 34, 0, 255))
        draw.ellipse([140 - 2, cy_c - 2, 140 + 2, cy_c + 2], fill=(255, 85, 0, 255))
        draw.ellipse([140 - 1, cy_c - 1, 140 + 1, cy_c + 1], fill=(255, 255, 102, 255))

    # Sub-script Seconds: On RIGHT side of minutes tubes, baseline aligned to bottom edge (Y=175)
    # Gap to minutes tube is 4 px (226 -> 230), Y: 163 (baseline ~175)
    sec_x = 230
    sec_y = 163
    draw.text((sec_x, sec_y), "42", font=font_sec, fill=amber)

    # Left Side Icons: Bluetooth centered around Y: 140
    # At (32, 131) and Dynamic Alarm Bell at (32, 149)
    draw.line([32, 125, 32, 137], fill=cyan, width=1)
    draw.line([29, 128, 35, 134], fill=cyan, width=1)
    draw.line([35, 134, 32, 137], fill=cyan, width=1)
    draw.line([29, 134, 35, 128], fill=cyan, width=1)
    draw.line([35, 128, 32, 125], fill=cyan, width=1)

    draw.arc([28, 144, 36, 151], start=180, end=360, fill=amber, width=1)
    draw.line([27, 150, 37, 150], fill=amber, width=1)
    draw.point([32, 152], fill=amber)

    # Right Side Icon: Notification message bubble moved to (248, 125), well clear of seconds!
    draw.rounded_rectangle([243, 121, 253, 129], radius=2, outline=cyan, width=1)
    draw.line([245, 128, 247, 130], fill=cyan, width=1)
    draw.line([247, 130, 247, 128], fill=cyan, width=1)
    draw.ellipse([251, 119, 254, 122], fill=cyan)

    # 5. Seamless Stepped Pyramid Grid (Step 3 & 4: Smaller cells H=22, lowered to 8-10px from bottom edge)
    # Row A: Y: 202 - 224 (H=22)
    # Row B: Y: 224 - 246 (H=22)
    # Row C: Y: 246 - 268 (H=22) -> Bottom at Y=268, exactly 8-10px from round display edge!
    ya = 202
    yb = 224
    yc = 246
    yd = 268

    xa_l, xa_r = 26, 254
    xb_l, xb_r = 64, 216
    xc_l, xc_r = 104, 176 # Narrowed to 72px for clean 8-10px margin to circular curvature

    # Seamless plate fills (subtle dark cell fill, ZERO gaps)
    draw.rectangle([xa_l, ya, xa_r, yb], fill=plate_bg)
    draw.rectangle([xb_l, yb, xb_r, yc], fill=plate_bg)
    draw.rectangle([xc_l, yc, xc_r, yd], fill=plate_bg)

    # Step 5: Thin dim dark-green INNER divider lines ONLY (NO outer border!)
    # Row A vertical dividers:
    draw.line([102, ya, 102, yb], fill=plate_border, width=1)
    draw.line([178, ya, 178, yb], fill=plate_border, width=1)

    # Horizontal shared divider between Row A and Row B (where they touch: 64 to 216):
    draw.line([xb_l, yb, xb_r, yb], fill=plate_border, width=1)

    # Row B vertical divider:
    draw.line([140, yb, 140, yc], fill=plate_border, width=1)

    # Horizontal shared divider between Row B and Row C (where they touch: 104 to 176):
    draw.line([xc_l, yc, xc_r, yc], fill=plate_border, width=1)

    cy_a = (ya + yb) // 2 # 213
    cy_b = (yb + yc) // 2 # 235
    cy_c = (yc + yd) // 2 # 257

    # Row A - Cell A1: Floors (Ascending stairs + plain number '12')
    fl_txt = "12"
    bbox = font_val.getbbox(fl_txt)
    fl_tw = bbox[2] - bbox[0]
    fl_icon_w = 11
    fl_w = fl_icon_w + 4 + fl_tw
    fl_sx = 64 - fl_w // 2
    sty = cy_a - 5
    draw.rectangle([fl_sx, sty + 7, fl_sx + 2, sty + 10], fill=green)
    draw.rectangle([fl_sx + 3, sty + 4, fl_sx + 5, sty + 10], fill=green)
    draw.rectangle([fl_sx + 6, sty, fl_sx + 8, sty + 10], fill=green)
    draw.text((fl_sx + fl_icon_w + 4, cy_a - 6), fl_txt, font=font_val, fill=green)

    # Row A - Cell A2: Heart Rate (Heart icon + '80')
    hr_txt = "80"
    bbox = font_val.getbbox(hr_txt)
    htw = bbox[2] - bbox[0]
    hr_icon_w = 11
    hr_w = hr_icon_w + 4 + htw
    hr_sx = 140 - hr_w // 2
    hx, hy = hr_sx, cy_a - 5
    draw.ellipse([hx + 1, hy, hx + 4, hy + 3], fill=red)
    draw.ellipse([hx + 6, hy, hx + 9, hy + 3], fill=red)
    draw.polygon([(hx, hy + 2), (hx + 10, hy + 2), (hx + 5, hy + 9)], fill=red)
    draw.text((hr_sx + hr_icon_w + 4, cy_a - 6), hr_txt, font=font_val, fill=red)

    # Row A - Cell A3: Compact Temp ('24°/25°', NO spaces around slash!)
    wea_txt = "24°/25°"
    bbox = font_val.getbbox(wea_txt)
    wtw = bbox[2] - bbox[0]
    wea_icon_w = 11
    wea_w = wea_icon_w + 3 + wtw
    wea_sx = 216 - wea_w // 2
    wx, wy_i = wea_sx, cy_a - 4
    draw.line([wx + 2, wy_i + 8, wx + 10, wy_i + 8], fill=cyan, width=1)
    draw.ellipse([wx + 2, wy_i + 3, wx + 6, wy_i + 8], outline=cyan)
    draw.ellipse([wx + 4, wy_i + 1, wx + 10, wy_i + 8], outline=cyan)
    draw.point([wx + 10, wy_i + 2], fill=cyan)
    draw.text((wea_sx + wea_icon_w + 3, cy_a - 6), wea_txt, font=font_val, fill=cyan)

    # Row B - Cell B1: Steps (Footsteps icon + '10741', Center X = 102)
    step_txt = "10741"
    bbox = font_val.getbbox(step_txt)
    stw = bbox[2] - bbox[0]
    step_icon_w = 11
    step_w = step_icon_w + 4 + stw
    step_sx = 102 - step_w // 2
    sx, sy = step_sx, cy_b - 5
    draw.rounded_rectangle([sx, sy + 3, sx + 3, sy + 9], radius=1, fill=green)
    draw.ellipse([sx, sy, sx + 2, sy + 2], fill=green)
    draw.rounded_rectangle([sx + 6, sy, sx + 9, sy + 6], radius=1, fill=green)
    draw.ellipse([sx + 6, sy + 7, sx + 8, sy + 9], fill=green)
    draw.text((step_sx + step_icon_w + 4, cy_b - 6), step_txt, font=font_val, fill=green)

    # Row B - Cell B2: Calories (Recognizable multi-point flame icon + '1840', Center X = 178)
    cal_txt = "1840"
    bbox = font_val.getbbox(cal_txt)
    ctw = bbox[2] - bbox[0]
    cal_icon_w = 11
    cal_w = cal_icon_w + 4 + ctw
    cal_sx = 178 - cal_w // 2
    fx, fy = cal_sx, cy_b - 6
    draw.polygon([
        (fx + 4, fy),
        (fx + 7, fy + 2),
        (fx + 9, fy + 6),
        (fx + 8, fy + 10),
        (fx + 6, fy + 11),
        (fx + 2, fy + 11),
        (fx + 1, fy + 8),
        (fx + 1, fy + 5),
        (fx + 3, fy + 3),
        (fx + 2, fy + 1)
    ], fill=orange)
    draw.polygon([
        (fx + 4, fy + 3),
        (fx + 7, fy + 7),
        (fx + 6, fy + 9),
        (fx + 3, fy + 9),
        (fx + 3, fy + 6)
    ], fill=amber)
    draw.text((cal_sx + cal_icon_w + 4, cy_b - 6), cal_txt, font=font_val, fill=orange)

    # Row C - Cell C: Body Battery (Vitality silhouette icon + '75%', Center X = 140)
    bb_txt = "75%"
    bbox = font_val.getbbox(bb_txt)
    btw = bbox[2] - bbox[0]
    bb_icon_w = 11
    bb_w = bb_icon_w + 4 + btw
    bb_sx = 140 - bb_w // 2
    vx, vy = bb_sx, cy_c - 6
    draw.ellipse([vx + 3, vy, vx + 7, vy + 3], fill=green)
    draw.line([vx + 1, vy + 4, vx + 9, vy + 4], fill=green, width=1)
    draw.line([vx + 1, vy + 4, vx + 2, vy + 9], fill=green, width=1)
    draw.line([vx + 9, vy + 4, vx + 8, vy + 9], fill=green, width=1)
    draw.line([vx + 2, vy + 9, vx + 5, vy + 11], fill=green, width=1)
    draw.line([vx + 8, vy + 9, vx + 5, vy + 11], fill=green, width=1)
    draw.polygon([(vx + 5, vy + 4), (vx + 3, vy + 7), (vx + 5, vy + 6), (vx + 4, vy + 9), (vx + 7, vy + 6), (vx + 5, vy + 6)], fill=(238, 255, 255, 255))
    draw.text((bb_sx + bb_icon_w + 4, cy_c - 6), bb_txt, font=font_val, fill=green)

    # 6. Chassis Bolts (Perimeter Corner Screws - Repositioned to clear lowered grid)
    bolts = [[36, 54], [244, 54], [48, 228], [232, 228]]
    for bx, by in bolts:
        draw.ellipse([bx - 5, by - 5, bx + 5, by + 5], fill=(64, 69, 74, 255))
        draw.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=(40, 44, 48, 255))
        draw.line([bx - 2, by - 2, bx + 2, by + 2], fill=(16, 18, 20, 255), width=1)

    # 7. Circular mask for 280x280 round display
    mask = Image.new("L", (w, h), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse([0, 0, w - 1, h - 1], fill=255)
    output = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    output.paste(img, (0, 0), mask)

    output.save(output_path)
    print(f"Successfully generated {output_path} (lit={lit})")

def render_all_digits_preview(output_path="all_digits_preview.png"):
    w, h = 434, 114
    img = Image.new("RGBA", (w, h), (8, 16, 12, 255))
    draw = ImageDraw.Draw(img)

    try:
        font_lbl = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 9)
    except:
        font_lbl = ImageFont.load_default()

    trace_col = (18, 36, 24, 255)
    via_pad = (58, 50, 24, 255)
    silk_col = (55, 80, 65, 255)

    # Top & bottom PCB bus rails
    draw.line([10, 14, w - 10, 14], fill=trace_col, width=1)
    draw.line([10, 104, w - 10, 104], fill=trace_col, width=1)

    tube_w, tube_h = 38, 70
    tube_y = 24

    for d in range(10):
        tx = 8 + d * 42

        # Feeder trace & via
        draw.line([tx + 19, 14, tx + 19, tube_y - 2], fill=trace_col, width=1)
        draw.ellipse([tx + 17, 12, tx + 21, 16], fill=via_pad)
        draw.ellipse([tx + 18, 13, tx + 20, 15], fill=(8, 16, 12, 255))

        draw.line([tx + 19, tube_y + tube_h + 4, tx + 19, 104], fill=trace_col, width=1)
        draw.ellipse([tx + 17, 102, tx + 21, 106], fill=via_pad)
        draw.ellipse([tx + 18, 103, tx + 20, 105], fill=(8, 16, 12, 255))

        # Tube & 7-Segment digit
        draw_7seg_nixie_tube(draw, tx, tube_y, tube_w, tube_h, d)

        # Label above tube
        lbl = f"[{d}]"
        bbox = font_lbl.getbbox(lbl)
        lw = bbox[2] - bbox[0]
        draw.text((tx + 19 - lw // 2, 4), lbl, font=font_lbl, fill=silk_col)

    img.save(output_path)
    print(f"Successfully generated {output_path}")

if __name__ == "__main__":
    # Generate lit preview as standard preview_full.png
    render_watchface(lit=True, output_path="preview_full.png")
    # Also generate unlit preview as preview_dark.png
    render_watchface(lit=False, output_path="preview_dark.png")
    # Generate all digits preview (0-9)
    render_all_digits_preview(output_path="all_digits_preview.png")
