"""Generate the multi-size Vittix tray icons.

Run from anywhere:
    python Keyboard/Resources/make_icons.py
    cd Keyboard/Resources && brcc32 -fo vikicons.res vikicons.rc

SUPPLYING YOUR OWN ARTWORK
--------------------------
Drop these two files next to this script and re-run it. Nothing else changes.

    Keyboard/Resources/tray_enabled.png     engine on
    Keyboard/Resources/tray_disabled.png    engine off

Both may also be supplied as .ico. PNG-32 with a transparent background is
preferred: square, 256x256 or larger, glyph centred with roughly an 8 percent
margin. Both files should use the same canvas so the glyph does not shift between
states.

If a source is 48px or larger, a 48px frame is added as well.

When neither file is present the script falls back to the shipped 32x32 icons, so
it keeps working before any new artwork arrives:

    Keyboard/icons/keyboard_on..ico    mark in rgb(0, 128, 0)
    Keyboard/icons/keyboard_off..ico   mark in rgb(212, 0, 0)

Output:
  Keyboard/Resources/vittix_on.ico     enabled  state
  Keyboard/Resources/vittix_off.ico    disabled state
  ui-ux-proposal/*.png                 magnified previews, light and dark

The icon resource names the application loads are VIK_ICON_ON and VIK_ICON_OFF,
declared in vikicons.rc and consumed by frmTray.pas.
"""

import struct
import pathlib

from PIL import Image

# Script lives in Keyboard/Resources; the repo root is two levels up from there.
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "Keyboard" / "Resources"

# Optional artwork supplied by the design side, in priority order.
SUPPLIED = {
    "on": ("tray_enabled.png", "tray_enabled.ico"),
    "off": ("tray_disabled.png", "tray_disabled.ico"),
}

# Fallback: the icons that already ship.
SHIPPED = {
    "on": ROOT / "Keyboard" / "icons" / "keyboard_on..ico",
    "off": ROOT / "Keyboard" / "icons" / "keyboard_off..ico",
}

COLOURS = {"on": (0, 128, 0), "off": (212, 0, 0)}

BASE_SIZES = [16, 20, 24, 32]

# A straight downscale leaves thin strokes sitting at partial alpha, which makes
# the 20px and 24px frames lighter than the 16px one. A levels step pulls stroke
# cores back to solid while keeping one anti-aliased edge pixel.
LEVELS_LO = 28
LEVELS_HI = 180


def resolve_source(state):
    """Return (path, supplied?) for a state, preferring supplied artwork."""
    for name in SUPPLIED[state]:
        candidate = OUT / name
        if candidate.exists():
            return candidate, True
    return SHIPPED[state], False


def load_source(path):
    """RGBA image, padded to a square so framing survives a straight resize."""
    img = Image.open(path)
    if path.suffix.lower() == ".ico":
        img = img.ico.getimage(max(img.ico.sizes()))
    img = img.convert("RGBA")

    if img.getchannel("A").getbbox() is None:
        raise SystemExit(f"{path} has no opaque pixels")

    # Do not crop to the ink: the margin around the glyph is part of the design,
    # and the enabled and disabled icons are deliberately framed differently.
    side = max(img.size)
    if img.size != (side, side):
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
        img = square
    return img


def levels(alpha):
    """Remap alpha so stroke cores reach full opacity instead of partial grey."""
    span = LEVELS_HI - LEVELS_LO
    return alpha.point(lambda v: 0 if v <= LEVELS_LO
                       else (255 if v >= LEVELS_HI
                             else int(round((v - LEVELS_LO) * 255.0 / span))))


def frame(full, colour, size, passthrough, supplied):
    """One frame of the icon.

    Two very different sources pass through here. The shipped fallback marks are
    flat single-colour glyphs, so they get recoloured and a levels step. Supplied
    artwork may be full-colour with its own background, so it is resized as-is
    and none of its pixels are rewritten.
    """
    if passthrough:
        # Only used for the shipped 32px fallback at 32px, so that frame stays
        # byte-identical to the artwork that already ships.
        return full.copy()

    if supplied:
        # Keep the artwork's own colours, but still crisp the alpha so the thinner
        # strokes do not wash out at 16px. Only the alpha channel is touched.
        small = full.resize((size, size), Image.LANCZOS)
        red, green, blue, alpha = small.split()
        return Image.merge("RGBA", (red, green, blue, levels(alpha)))

    # Scaling the whole canvas, not the ink, keeps whatever margin the artwork
    # was drawn with at every size.
    small = levels(full.getchannel("A").resize((size, size), Image.LANCZOS))

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    solid = Image.new("RGBA", (size, size), colour + (255,))
    return Image.composite(solid, img, small)


def write_ico(path, frames):
    """Minimal ICO writer: 32bpp DIB frames plus a zeroed AND mask.

    Written by hand rather than via Pillow so every frame keeps its own treatment
    instead of being resampled from the largest one.
    """
    images, entries = [], []
    offset = 6 + 16 * len(frames)

    for img in frames:
        w, h = img.size
        px = img.load()

        # XOR bitmap: BGRA, bottom-up.
        xor = bytearray()
        for y in range(h - 1, -1, -1):
            for x in range(w):
                r, g, b, a = px[x, y]
                xor += bytes((b, g, r, a))

        # AND mask: 1bpp, rows padded to 4 bytes, bottom-up. All zero because
        # the alpha channel carries the transparency.
        row_bytes = ((w + 31) // 32) * 4
        and_mask = bytes(row_bytes * h)

        header = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, len(xor), 0, 0, 0, 0)
        payload = header + bytes(xor) + and_mask
        images.append(payload)
        entries.append(struct.pack(
            "<BBBBHHII",
            w if w < 256 else 0, h if h < 256 else 0, 0, 0, 1, 32,
            len(payload), offset,
        ))
        offset += len(payload)

    data = struct.pack("<HHH", 0, 1, len(frames)) + b"".join(entries) + b"".join(images)
    path.write_bytes(data)


def sheet(frames, path, scale=8, bg=(238, 241, 244, 255)):
    """Magnified contact sheet so the small frames can actually be judged."""
    pad = 6
    w = sum(f.width * scale + pad for f in frames) + pad
    h = max(f.height for f in frames) * scale + 2 * pad
    out = Image.new("RGBA", (w, h), bg)
    x = pad
    for f in frames:
        big = f.resize((f.width * scale, f.height * scale), Image.NEAREST)
        out.alpha_composite(big, (x, pad))
        x += big.width + pad
    out.convert("RGB").save(path)


def ascii_map(img):
    a = img.getchannel("A")
    ramp = " .:-=+*#%@"
    for y in range(a.height):
        print("".join(ramp[min(9, int(a.getpixel((x, y)) / 25.6))] for x in range(a.width)))


def ink(img):
    return sum(1 for p in img.get_flattened_data() if p[3] > 200)


def main():
    all_frames = {}
    meta = {}

    for state in ("on", "off"):
        path, supplied = resolve_source(state)
        full = load_source(path)
        inkbox = full.getchannel("A").getbbox()
        origin = "supplied" if supplied else "shipped fallback"
        print(f"{state:>3}: {path.name} ({origin})  canvas {full.width}x{full.height}"
              f"  ink {inkbox[2] - inkbox[0]}x{inkbox[3] - inkbox[1]}")

        sizes = list(BASE_SIZES)
        if max(full.size) >= 48:
            sizes.append(48)

        # A supplied tile is opaque down to the pixel, so the smallest frame is
        # the one that decides whether the design survives in the tray.
        coverage = sum(1 for p in full.get_flattened_data() if p[3] > 200) / (full.width * full.height)
        print(f"      canvas coverage {100 * coverage:.1f}% opaque"
              + ("  (opaque background)" if coverage > 0.9 else ""))

        all_frames[state] = [
            frame(full, COLOURS[state], s,
                  passthrough=(not supplied) and (s == full.width),
                  supplied=supplied)
            for s in sizes
        ]
        meta[state] = (path, supplied, sizes)

    write_ico(OUT / "vittix_on.ico", all_frames["on"])
    write_ico(OUT / "vittix_off.ico", all_frames["off"])

    preview = ROOT / "ui-ux-proposal"
    preview.mkdir(exist_ok=True)
    light, dark = (238, 241, 244, 255), (32, 36, 42, 255)
    sheet(all_frames["on"], preview / "V1 Tray icon - enabled.png", bg=light)
    sheet(all_frames["off"], preview / "V1 Tray icon - disabled.png", bg=light)
    sheet(all_frames["on"], preview / "V1 Tray icon - enabled on dark taskbar.png", bg=dark)
    sheet(all_frames["off"], preview / "V1 Tray icon - disabled on dark taskbar.png", bg=dark)

    for state in ("on", "off"):
        path = OUT / f"vittix_{state}.ico"
        print(f"{path.name}: {len(all_frames[state])} frames {meta[state][2]}, "
              f"{path.stat().st_size} bytes")

    print()
    for state in ("on", "off"):
        print(f"  {state:>3} ink by size: " + ", ".join(
            f"{f.width}px={ink(f)}" for f in all_frames[state]))

    # Only meaningful while the shipped 32px icons are still the source, but it
    # catches an accidental shift in the artwork either way.
    for state in ("on", "off"):
        path, supplied, sizes = meta[state]
        if supplied or 32 not in sizes:
            continue
        original = Image.open(path).ico.getimage((32, 32)).convert("RGBA")
        f32 = all_frames[state][sizes.index(32)]
        print(f"  {state:>3} 32px frame identical to the shipped icon: "
              f"{original.tobytes() == f32.tobytes()}")

    print()
    print("enabled smallest frame")
    ascii_map(all_frames["on"][0])
    print()
    print("disabled smallest frame")
    ascii_map(all_frames["off"][0])


if __name__ == "__main__":
    main()
