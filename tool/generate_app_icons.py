#!/usr/bin/env python3
"""Generate raster app icons from the shared Scriptagher SVG logo."""
from __future__ import annotations

import json
import shutil
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SVG_SOURCE = ROOT / "assets" / "icons" / "scriptagher_mini_droid.svg"
OUTPUT_DIR = ROOT / "assets" / "icons" / "generated"
WEB_ICON_DIR = ROOT / "web" / "icons"
ANDROID_RES_DIR = ROOT / "android" / "app" / "src" / "main" / "res"
WINDOWS_ICON_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
MACOS_APP_ICONSET = (
    ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
)
PWA_ICON_SIZES = {192: "icon-192.png", 512: "icon-512.png"}

PNG_SIZES = [
    16,
    24,
    32,
    48,
    64,
    72,
    96,
    128,
    144,
    152,
    167,
    180,
    192,
    256,
    432,
    512,
    1024,
]
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]

ANDROID_MIPMAP_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}



def ensure_output_dir() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    WEB_ICON_DIR.mkdir(parents=True, exist_ok=True)


def ensure_png_size(size: int, rendered: dict[int, Path]) -> Path:
    if size not in rendered:
        rendered[size] = render_png(size)
    path = rendered[size]
    if not path.exists():
        rendered[size] = render_png(size)
    return rendered[size]


def render_png(size: int) -> Path:
    target = OUTPUT_DIR / f"scriptagher_mini_droid_{size}.png"
    cairosvg.svg2png(
        url=str(SVG_SOURCE),
        write_to=str(target),
        output_width=size,
        output_height=size,
    )
    return target


def render_png_variants() -> dict[int, Path]:
    rendered: dict[int, Path] = {}
    for size in PNG_SIZES:
        rendered[size] = render_png(size)
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


def update_windows_icon(ico_path: Path) -> list[Path]:
    if not WINDOWS_ICON_PATH.parent.exists():
        return []
    shutil.copyfile(ico_path, WINDOWS_ICON_PATH)
    return [WINDOWS_ICON_PATH]


def update_macos_icons(rendered: dict[int, Path]) -> list[Path]:
    if not MACOS_APP_ICONSET.exists():
        return []

    contents_path = MACOS_APP_ICONSET / "Contents.json"
    if not contents_path.exists():
        return []

    with contents_path.open("r", encoding="utf8") as fp:
        contents = json.load(fp)

    updated: list[Path] = []
    images = contents.get("images", [])
    for image in images:
        filename = image.get("filename")
        size = image.get("size")
        scale = image.get("scale")
        if not filename or not size or not scale:
            continue

        try:
            base_size = float(size.split("x")[0])
            scale_factor = float(scale.replace("x", ""))
        except ValueError:
            continue

        pixel_size = int(round(base_size * scale_factor))
        source = ensure_png_size(pixel_size, rendered)
        target = MACOS_APP_ICONSET / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        updated.append(target)

    return updated


def update_android_icons(rendered: dict[int, Path]) -> list[Path]:
    if not ANDROID_RES_DIR.exists():
        return []

    updated: list[Path] = []
    for folder, size in ANDROID_MIPMAP_SIZES.items():
        folder_path = ANDROID_RES_DIR / folder
        if not folder_path.exists():
            continue
        source = ensure_png_size(size, rendered)
        for filename in ("ic_launcher.png", "ic_launcher_round.png"):
            target = folder_path / filename
            shutil.copyfile(source, target)
            updated.append(target)

    updated.extend(_rewrite_android_adaptive_icons())

    return updated


def _rewrite_android_adaptive_icons() -> list[Path]:
    targets = []
    anydpi = ANDROID_RES_DIR / "mipmap-anydpi-v26"
    if not anydpi.exists():
        return targets

    replacements = {
        "ic_launcher.xml": "@mipmap/ic_launcher",
        "ic_launcher_round.xml": "@mipmap/ic_launcher_round",
    }

    for filename, resource in replacements.items():
        xml_path = anydpi / filename
        if not xml_path.exists():
            continue
        text = xml_path.read_text(encoding="utf8")
        new_text = text.replace("@drawable/ic_launcher_foreground", resource)
        if new_text != text:
            xml_path.write_text(new_text, encoding="utf8")
            targets.append(xml_path)

    return targets


def main() -> None:
    ensure_output_dir()
    rendered = render_png_variants()
    ico_path = render_ico()
    pwa_paths = sync_pwa_icons()
    platform_paths = []
    platform_paths.extend(update_windows_icon(ico_path))
    platform_paths.extend(update_macos_icons(rendered))
    platform_paths.extend(update_android_icons(rendered))
    print("Generated icons:")
    for path in list(rendered.values()) + [ico_path] + pwa_paths + platform_paths:
        rel = path.relative_to(ROOT)
        print(f" - {rel} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
