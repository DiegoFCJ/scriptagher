#!/usr/bin/env python3
"""Generate raster app icons from the shared Scriptagher SVG logo."""
from __future__ import annotations

import shutil
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SVG_SOURCE = ROOT / "assets" / "icons" / "scriptagher_mini_droid.svg"
OUTPUT_DIR = ROOT / "assets" / "icons" / "generated"
WEB_ICON_DIR = ROOT / "web" / "icons"
PWA_ICON_SIZES = {192: "icon-192.png", 512: "icon-512.png"}

PNG_SIZES = [16, 32, 48, 64, 72, 96, 128, 144, 152, 167, 180, 192, 256, 512, 1024]
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def ensure_output_dir() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    WEB_ICON_DIR.mkdir(parents=True, exist_ok=True)


def render_png(size: int) -> Path:
    target = OUTPUT_DIR / f"scriptagher_mini_droid_{size}.png"
    cairosvg.svg2png(
        url=str(SVG_SOURCE),
        write_to=str(target),
        output_width=size,
        output_height=size,
    )
    return target


def render_png_variants() -> list[Path]:
    rendered: list[Path] = []
    for size in PNG_SIZES:
        rendered.append(render_png(size))
    return rendered


def sync_pwa_icons() -> list[Path]:
    copied: list[Path] = []
    for size, filename in PWA_ICON_SIZES.items():
        source = OUTPUT_DIR / f"scriptagher_mini_droid_{size}.png"
        if not source.exists():
            source = render_png(size)
        target = WEB_ICON_DIR / filename
        shutil.copyfile(source, target)
        copied.append(target)
    return copied


def render_ico() -> Path:
    ico_path = OUTPUT_DIR / "scriptagher_mini_droid.ico"
    images = []
    for size in ICO_SIZES:
        png_path = OUTPUT_DIR / f"scriptagher_mini_droid_{size}.png"
        if not png_path.exists():
            png_path = render_png(size)
        images.append(Image.open(png_path).convert("RGBA"))
    base_image = images[0]
    base_image.save(ico_path, format="ICO", sizes=[(size, size) for size in ICO_SIZES])
    return ico_path


def main() -> None:
    ensure_output_dir()
    rendered = render_png_variants()
    ico_path = render_ico()
    pwa_paths = sync_pwa_icons()
    all_paths = rendered + [ico_path] + pwa_paths
    print("Generated icons:")
    for path in all_paths:
        rel = path.relative_to(ROOT)
        print(f" - {rel} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
