"""Build Android icon/splash PNGs and two original notification chimes.

Run from anywhere: python -m pip install pillow && python mobile/tools/generate_brand_assets.py
The generated Android resources are checked into the repository; Flutter builds do
not need Pillow or this script at runtime.
"""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

MOBILE = Path(__file__).resolve().parents[1]
RES = MOBILE / "android/app/src/main/res"
BRAND = MOBILE / "branding"
TEAL = (20, 107, 103)


def save_icon() -> None:
    source = Image.open(BRAND / "studia_icon_master.png").convert("RGB")
    # Isolate the light book and sun from the dark generated background. Cropping
    # the outer edges also removes the white corners of the source image.
    red = source.getchannel("R")
    alpha = red.point(lambda v: max(0, min(255, (v - 85) * 255 // 100)))
    crop = Image.new("L", source.size)
    ImageDraw.Draw(crop).rectangle((140, 170, 880, 845), fill=255)
    alpha = ImageChops.multiply(alpha, crop)
    foreground = source.convert("RGBA")
    foreground.putalpha(alpha)
    legacy = Image.new("RGBA", source.size, (*TEAL, 255))
    legacy.alpha_composite(foreground)

    for folder, pixels in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                           "xxhdpi": 144, "xxxhdpi": 192}.items():
        dest = RES / f"mipmap-{folder}" / "ic_launcher.png"
        dest.parent.mkdir(parents=True, exist_ok=True)
        legacy.resize((pixels, pixels), Image.Resampling.LANCZOS).save(dest, optimize=True)

    dest = RES / "drawable-nodpi"
    dest.mkdir(parents=True, exist_ok=True)
    foreground.resize((432, 432), Image.Resampling.LANCZOS).save(
        dest / "ic_launcher_foreground.png", optimize=True)

    # Android 13 themed icon: monochrome mask, independently tintable by Android.
    mono = Image.new("RGBA", source.size, (255, 255, 255, 0))
    mono.putalpha(alpha)
    mono.resize((432, 432), Image.Resampling.LANCZOS).save(
        dest / "ic_launcher_monochrome.png", optimize=True)


def save_splash() -> None:
    source = Image.open(BRAND / "studia_splash_master.png").convert("RGBA")
    # The Android launch screen must adapt to many aspect ratios. Its centered
    # emblem is taken from the portrait design; the native theme fills the rest.
    emblem = source.crop((148, 452, 620, 924))
    circle = Image.new("L", emblem.size)
    ImageDraw.Draw(circle).ellipse((4, 4, 468, 468), fill=255)
    circle = circle.filter(ImageFilter.GaussianBlur(0.7))
    emblem.putalpha(circle)
    centered = Image.new("RGBA", (288, 288), (0, 0, 0, 0))
    emblem = emblem.resize((224, 224), Image.Resampling.LANCZOS)
    centered.alpha_composite(emblem, (32, 32))
    dest = RES / "drawable"
    dest.mkdir(parents=True, exist_ok=True)
    centered.save(dest / "studia_splash_mark.png", optimize=True)


def chime(name: str, notes: list[tuple[float, float]]) -> None:
    rate = 44100
    duration = max(start + 0.49 for start, _ in notes) + 0.04
    samples = []
    for i in range(int(duration * rate)):
        time = i / rate
        value = 0.0
        for start, hz in notes:
            t = time - start
            if not 0 <= t < 0.49:
                continue
            envelope = min(1.0, t / 0.018) * (1.0 - t / 0.49) ** 1.8
            value += envelope * (math.sin(2 * math.pi * hz * t)
                                 + 0.20 * math.sin(2 * math.pi * hz * 2 * t)
                                 + 0.07 * math.sin(2 * math.pi * hz * 3 * t))
        samples.append(int(max(-1, min(1, value * 0.23)) * 32767))
    output = RES / "raw" / f"studia_{name}.wav"
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(rate)
        audio.writeframes(struct.pack(f"<{len(samples)}h", *samples))


if __name__ == "__main__":
    save_icon()
    save_splash()
    # Different signatures: two bright ascending notes for classes, three
    # softer notes for revision. Both are locally synthesized, not stock sounds.
    chime("course", [(0.0, 659.25), (0.24, 987.77)])
    chime("revision", [(0.0, 523.25), (0.20, 659.25), (0.40, 783.99)])
    print("Studia Android icon, splash, and notification resources generated.")
