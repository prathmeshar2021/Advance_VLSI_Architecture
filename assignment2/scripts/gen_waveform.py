#!/usr/bin/env python3
"""
gen_waveform.py - render a Vivado-XSim-style waveform PNG from a per-cycle CSV
produced by sim/wavegen_tb.v.  Drawn with Pillow so the figure matches the
simulation exactly (same data as the results transcript).

  python3 -I scripts/gen_waveform.py sim/wave_test1.csv results/wave_test1.png 9
  python3 -I scripts/gen_waveform.py sim/wave_test2.csv results/wave_test2.png 8
"""
import csv, sys
from PIL import Image, ImageDraw, ImageFont

S = 2  # supersample factor

# ---- Vivado-like palette --------------------------------------------------
C_CANVAS = (0, 0, 0)
C_PANEL  = (37, 37, 38)
C_RULER  = (45, 45, 48)
C_DIV    = (70, 70, 72)
C_GRID   = (34, 34, 36)
C_TRACE  = (0, 200, 255)
C_TEXT   = (222, 222, 222)
C_NAME   = (210, 210, 210)
C_VALUE  = (120, 230, 140)
C_CURSOR = (255, 210, 0)

# ---- geometry (pre-scale px) ----------------------------------------------
NAME_W, VAL_W, CELL_W = 150, 96, 62
ROW_H, RULER_H = 34, 26
PAD = 6

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
def f(path, sz): return ImageFont.truetype(path, sz*S)
fn_name = f(FONT, 13); fn_val = f(MONO, 12); fn_bus = f(MONO, 11)
fn_rule = f(MONO, 10); fn_hdr = f(FONT, 11)

def load(path):
    rows = list(csv.DictReader(open(path)))
    return rows

def main():
    csv_path, out_path, cursor_cycle = sys.argv[1], sys.argv[2], int(sys.argv[3])
    rows = load(csv_path)
    n = len(rows)
    cyc = [int(r["cycle"]) for r in rows]

    # signal rows: (label, kind, getter)   kind: clk|bit|bus
    sigs = [
        ("clk",              "clk", None),
        ("rst",              "bit", lambda r: 0),
        ("req",              "bit", lambda r: int(r["req"])),
        ("stall",            "bit", lambda r: int(r["stall"])),
        ("byte_addr[14:0]",  "bus", lambda r: format(int(r["byte_addr"]), "03x")),
        ("bank_sel[2:0]",    "bus", lambda r: str(int(r["bank"]))),
        ("read_complete",    "bit", lambda r: int(r["read_complete"])),
        ("read_data[31:0]",  "bus", lambda r: r["read_data"].lower()),
    ]
    nrows = len(sigs)

    W = (NAME_W + VAL_W + n*CELL_W) * S
    H = (RULER_H + nrows*ROW_H + 6) * S
    img = Image.new("RGB", (W, H), C_CANVAS)
    d = ImageDraw.Draw(img)

    wave_x0 = (NAME_W + VAL_W) * S
    def cx(i): return wave_x0 + i*CELL_W*S            # left x of cycle column i

    # panels
    d.rectangle([0, 0, (NAME_W+VAL_W)*S, H], fill=C_PANEL)
    d.rectangle([0, 0, W, RULER_H*S], fill=C_RULER)
    d.line([(NAME_W*S,0),(NAME_W*S,H)], fill=C_DIV, width=1*S)
    d.line([((NAME_W+VAL_W)*S,0),((NAME_W+VAL_W)*S,H)], fill=C_DIV, width=1*S)
    d.line([(0,RULER_H*S),(W,RULER_H*S)], fill=C_DIV, width=1*S)
    d.text((8*S, 7*S), "Name", font=fn_hdr, fill=C_TEXT)
    d.text(((NAME_W+8)*S, 7*S), "Value", font=fn_hdr, fill=C_TEXT)

    # time ruler: tick + ns label every 2 cycles (10 ns per cycle)
    for i in range(n+1):
        x = cx(i)
        d.line([(x, (RULER_H-6)*S), (x, RULER_H*S)], fill=C_DIV, width=1*S)
    for i in range(0, n, 2):
        x = cx(i)
        d.text((x+3*S, 6*S), "%d ns" % (cyc[i]*10), font=fn_rule, fill=(170,170,175))

    # vertical grid over wave area
    for i in range(n+1):
        x = cx(i)
        d.line([(x, RULER_H*S), (x, H)], fill=C_GRID, width=1*S)

    # per-signal rows
    for r_i, (label, kind, get) in enumerate(sigs):
        top = (RULER_H + r_i*ROW_H) * S
        y_hi = top + PAD*S
        y_lo = top + (ROW_H-PAD)*S
        y_mid = (y_hi + y_lo)//2
        # name + value-at-cursor
        d.text((10*S, top + 9*S), label, font=fn_name, fill=C_NAME)
        # find cursor column
        ci = min(range(n), key=lambda k: abs(cyc[k]-cursor_cycle))
        if kind == "clk":
            vtext = ""
        elif kind == "bit":
            vtext = str(get(rows[ci]))
        else:
            vtext = get(rows[ci])
        if vtext:
            d.text(((NAME_W+10)*S, top + 9*S), vtext, font=fn_val, fill=C_VALUE)

        if kind == "clk":
            for i in range(n):
                x0 = cx(i); xm = x0 + CELL_W*S//2; x1 = cx(i+1)
                d.line([(x0,y_lo),(x0,y_hi),(xm,y_hi),(xm,y_lo),(x1,y_lo)],
                       fill=C_TRACE, width=2*S, joint="curve")
        elif kind == "bit":
            prev = None
            for i in range(n):
                v = get(rows[i]); x0 = cx(i); x1 = cx(i+1)
                y = y_hi if v else y_lo
                d.line([(x0,y),(x1,y)], fill=C_TRACE, width=2*S)
                if prev is not None and prev != v:
                    d.line([(x0,y_lo),(x0,y_hi)], fill=C_TRACE, width=2*S)
                prev = v
        else:  # bus: merge equal consecutive runs into hexagon cells
            i = 0
            s = 5*S
            while i < n:
                j = i
                val = get(rows[i])
                while j+1 < n and get(rows[j+1]) == val:
                    j += 1
                xa = cx(i); xb = cx(j+1)
                d.line([(xa,y_mid),(xa+s,y_hi),(xb-s,y_hi),(xb,y_mid)],
                       fill=C_TRACE, width=2*S, joint="curve")
                d.line([(xa,y_mid),(xa+s,y_lo),(xb-s,y_lo),(xb,y_mid)],
                       fill=C_TRACE, width=2*S, joint="curve")
                # centered text if it fits
                tw = d.textlength(val, font=fn_bus)
                if tw < (xb-xa) - 6*S:
                    d.text(((xa+xb)//2 - tw//2, y_mid - 7*S), val,
                           font=fn_bus, fill=C_TEXT)
                i = j+1

    # yellow cursor
    ci = min(range(n), key=lambda k: abs(cyc[k]-cursor_cycle))
    xcur = cx(ci)
    d.line([(xcur, 0), (xcur, H)], fill=C_CURSOR, width=1*S)
    d.text((xcur+3*S, 0*S), "%d ns" % (cursor_cycle*10), font=fn_rule, fill=C_CURSOR)

    img = img.resize((W//S, H//S), Image.LANCZOS)
    img.save(out_path)
    print("wrote", out_path, img.size)

if __name__ == "__main__":
    main()
