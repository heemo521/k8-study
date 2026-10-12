"""Generates the app icons (original artwork: two stacked flashcards with "K8").

Deliberately not the Kubernetes logo, to respect the trademark.
Usage: python3 tool/make_icons.py  (needs Pillow)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BG = (47, 111, 222)        # #2F6FDE, the app's seed colour
CARD_BACK = (166, 196, 245)
CARD_FRONT = (255, 255, 255)
INK = (24, 52, 110)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
WEB = Path(__file__).resolve().parent.parent / "web"


def draw(size: int, maskable: bool) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if maskable:
        d.rectangle([0, 0, size, size], fill=BG)   # full bleed
        scale = 0.62                                # inside the 80% safe zone
    else:
        d.rounded_rectangle([0, 0, size - 1, size - 1], radius=size * 0.22, fill=BG)
        scale = 0.74
    w = size * scale
    cw, ch = w * 0.78, w * 0.58
    x0 = (size - cw) / 2
    y0 = (size - ch) / 2
    off = w * 0.09
    r = w * 0.07
    d.rounded_rectangle([x0 + off, y0 - off, x0 + off + cw, y0 - off + ch],
                        radius=r, fill=CARD_BACK)
    d.rounded_rectangle([x0 - off * 0.4, y0 + off * 0.4,
                         x0 - off * 0.4 + cw, y0 + off * 0.4 + ch],
                        radius=r, fill=CARD_FRONT)
    font = ImageFont.truetype(FONT, int(ch * 0.55))
    text = "K8"
    box = d.textbbox((0, 0), text, font=font)
    tx = x0 - off * 0.4 + (cw - (box[2] - box[0])) / 2 - box[0]
    ty = y0 + off * 0.4 + (ch - (box[3] - box[1])) / 2 - box[1]
    d.text((tx, ty), text, font=font, fill=INK)
    return img


def main() -> None:
    for size in (192, 512):
        draw(size, False).save(WEB / "icons" / f"Icon-{size}.png")
        draw(size, True).save(WEB / "icons" / f"Icon-maskable-{size}.png")
    draw(32, False).save(WEB / "favicon.png")
    draw(180, True).convert("RGB").save(WEB / "icons" / "apple-touch-icon.png")


if __name__ == "__main__":
    main()
