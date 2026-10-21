#!/usr/bin/env python3
"""Derive the Android splash and adaptive-icon art from an opaque brand tile.

SUPERSEDED (v1.1.4). The Vyana 2.0 handover now ships both outputs
vector-derived at the sizes the tooling wants — vyana-android12-splash.png
(1152px) and vyana-adaptive-foreground.png (432px) — and those are copied
into assets/ directly. Cutting the mark back out of a tile estimates the
background per row and feathers an alpha from it, which is lossy next to
the real vector export. Do not run this against the current assets: it
expects an opaque tile, and assets/splash_logo.png is now the transparent
mark. Kept only for the case where the exports are unavailable.

The brand mark (a drop inside an open gold ring, 9 Oct 2026) ships as an
opaque dark tile, which is what iOS wants. Android does not: both the
Android 12+ splash and the adaptive launcher icon mask their artwork to a
circle about two-thirds of the canvas, so a tile whose mark already fills
66% loses the gold ring's edges and the drop's tip — that is bug 5.

This cuts the mark out of the tile and re-centres it inside the central 62%:

    assets/splash_logo_android12.png   1152px, on the splash colour
    assets/logo_adaptive_foreground.png 432px, transparent (108dp grid)

To regenerate the launcher icons and splash from the handover exports:

    dart run flutter_launcher_icons
    dart run flutter_native_splash:create

Needs Pillow (pip install Pillow).
"""

from PIL import Image

SRC = 'assets/splash_logo.png'
SPLASH_COLOR = (7, 18, 17)          # #071211, matching pubspec
INSET = 0.62                        # fraction of the canvas the mark may fill


def extract_mark(path):
    """The mark alone, with a feathered alpha, cut from its tile."""
    src = Image.open(path).convert('RGB')
    w, h = src.size
    px = src.load()

    # The tile's background is a vertical gradient, so estimate it per row
    # from the outer columns, which the mark never reaches.
    bg_row = []
    for y in range(h):
        s = [px[x, y] for x in list(range(0, 60)) + list(range(w - 60, w))]
        bg_row.append(tuple(sum(v[i] for v in s) // len(s) for i in range(3)))

    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        br, bg, bb = bg_row[y]
        for x in range(w):
            r, g, b = px[x, y]
            d = max(abs(r - br), abs(g - bg), abs(b - bb))
            a = (d - 10) / 28.0
            a = 0.0 if a < 0 else (1.0 if a > 1 else a)
            if a > 0:
                op[x, y] = (r, g, b, int(a * 255))

    bbox = out.getchannel('A').point(lambda p: 255 if p > 24 else 0).getbbox()
    return out.crop(bbox)


def place(mark, canvas, background):
    scale = int(canvas * INSET) / max(mark.size)
    art = mark.resize(
        (round(mark.width * scale), round(mark.height * scale)), Image.LANCZOS
    )
    out = Image.new('RGBA', (canvas, canvas), background)
    out.alpha_composite(art, ((canvas - art.width) // 2,
                              (canvas - art.height) // 2))
    return out


def main():
    mark = extract_mark(SRC)
    print(f'mark cut from {SRC}: {mark.size[0]}x{mark.size[1]}')

    splash = place(mark, 1152, SPLASH_COLOR + (255,))
    splash.convert('RGB').save('assets/splash_logo_android12.png')
    print('wrote assets/splash_logo_android12.png 1152x1152')

    fg = place(mark, 432, (0, 0, 0, 0))
    fg.save('assets/logo_adaptive_foreground.png')
    print('wrote assets/logo_adaptive_foreground.png 432x432')


if __name__ == '__main__':
    main()
