#!/usr/bin/env python3
"""Generate metadata JSON files for installer artifacts."""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
import re
from pathlib import Path
from typing import Dict, List


def read_version(pubspec_path: Path) -> str:
    pattern = re.compile(r"^version:\s*(.+)$")
    with pubspec_path.open(encoding="utf-8") as handle:
        for raw_line in handle:
            match = pattern.match(raw_line.strip())
            if match:
                return match.group(1)
    raise RuntimeError(f"Unable to determine version from {pubspec_path}")


def sha256sum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8192), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extension_for(filename: str) -> str:
    lowered = filename.lower()
    if lowered.endswith(".tar.gz"):
        return "tar.gz"
    if "." not in filename:
        return ""
    return filename.rsplit(".", 1)[-1].lower()


def linux_arch_label(identifier: str) -> str:
    return {
        "x64": "x86_64",
    }.get(identifier, identifier)


def android_arch_label(identifier: str) -> str:
    mapping = {
        "arm64-v8a": "ARM64-v8a",
        "armeabi-v7a": "ARMv7",
        "x86_64": "x86_64",
    }
    return mapping.get(identifier, identifier)


def build_metadata(
    rel_path: Path,
    *,
    installers_dir: Path,
    version: str,
    base_url: str,
    timestamp: str,
) -> Dict[str, object]:
    platform_dir = rel_path.parts[0]
    file_name = rel_path.name
    platform_names = {
        "android": "Android",
        "ios": "iOS",
        "linux": "Linux",
        "macos": "macOS",
        "windows": "Windows",
    }
    platform = platform_names.get(platform_dir, platform_dir.capitalize())
    extension = extension_for(file_name)
    file_stem = file_name
    if extension == "tar.gz":
        file_stem = file_name[: -len(".tar.gz")]
    elif "." in file_name:
        file_stem = file_name[: file_name.rfind(".")]

    full_path = installers_dir / rel_path

    metadata: Dict[str, object] = {
        "name": f"Scriptagher for {platform}",
        "platform": platform,
        "version": version,
        "file_name": file_name,
        "file_size": full_path.stat().st_size,
        "sha256": sha256sum(full_path),
        "download_url": f"{base_url}/{rel_path.as_posix()}",
        "format": extension.upper(),
        "last_updated": timestamp,
    }

    if platform_dir == "android":
        variant = "Debug"
        abi_part = file_stem
        if abi_part.startswith("scriptagher-"):
            abi_part = abi_part[len("scriptagher-") :]
        if abi_part.endswith("-debug"):
            abi_part = abi_part[: -len("-debug")]
        metadata["architecture"] = android_arch_label(abi_part)
        metadata["build_variant"] = variant
        metadata["name"] = (
            f"Scriptagher for {platform} ({metadata['architecture']} · {variant} Build)"
        )
    elif platform_dir == "linux":
        parts = file_stem.split("-")
        arch_identifier = parts[-1] if parts else "x86_64"
        architecture = linux_arch_label(arch_identifier)
        metadata["architecture"] = architecture
        metadata["build_variant"] = "Release"
        metadata["name"] = (
            f"Scriptagher for {platform} ({architecture} · Release Build)"
        )
    elif platform_dir == "windows":
        metadata["architecture"] = "x86_64"
        metadata["build_variant"] = "Release"
        metadata["distribution"] = "Installer"
        metadata["name"] = "Scriptagher for Windows (64-bit Installer)"
    elif platform_dir == "macos":
        metadata["build_variant"] = "Release"
        metadata["distribution"] = "Disk Image"
        metadata["name"] = "Scriptagher for macOS (Release Build)"
    elif platform_dir == "ios":
        metadata["build_variant"] = "Release"
        metadata["distribution"] = "IPA Package"
        metadata["name"] = "Scriptagher for iOS (Release Build)"

    return metadata


def generate_metadata(
    installers_dir: Path,
    *,
    version: str,
    base_url: str,
    timestamp: str,
    summary_name: str,
) -> List[Dict[str, object]]:
    artifacts: List[Dict[str, object]] = []
    for root, _, files in os.walk(installers_dir):
        for file_name in files:
            if file_name.startswith("."):
                continue
            if file_name.endswith(".json"):
                continue
            rel_path = Path(root, file_name)
            if rel_path.name == ".nojekyll":
                continue
            rel_rel_path = rel_path.relative_to(installers_dir)
            metadata = build_metadata(
                rel_rel_path,
                installers_dir=installers_dir,
                version=version,
                base_url=base_url,
                timestamp=timestamp,
            )
            artifacts.append(metadata)
            target_json = rel_path.with_suffix("")
            if file_name.lower().endswith(".tar.gz"):
                target_json = rel_path.parent / file_name[: -len(".tar.gz")]
            json_path = target_json.with_suffix(".json")
            rel_path.parent.mkdir(parents=True, exist_ok=True)
            with json_path.open("w", encoding="utf-8") as handle:
                json.dump(metadata, handle, indent=2, ensure_ascii=False)
                handle.write("\n")
    artifacts.sort(key=lambda item: item["download_url"])
    summary_path = installers_dir / summary_name
    with summary_path.open("w", encoding="utf-8") as handle:
        json.dump({"generated_at": timestamp, "installers": artifacts}, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    return artifacts


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--installers-dir",
        default="installers",
        type=Path,
        help="Directory containing installer artifacts (default: installers)",
    )
    parser.add_argument(
        "--pubspec",
        default=Path("pubspec.yaml"),
        type=Path,
        help="Path to pubspec.yaml (default: pubspec.yaml)",
    )
    parser.add_argument(
        "--repository",
        default=os.environ.get("GITHUB_REPOSITORY"),
        help="owner/repo name to build download URLs (default: $GITHUB_REPOSITORY)",
    )
    parser.add_argument(
        "--summary-name",
        default="metadata.json",
        help="File name for the installers summary JSON (default: metadata.json)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    installers_dir = args.installers_dir.resolve()
    if not installers_dir.exists():
        raise SystemExit(f"Installers directory {installers_dir} does not exist")

    repository = args.repository or "scriptagher/scriptagher"
    if "/" in repository:
        owner, repo_name = repository.split("/", 1)
    else:
        owner = repository
        repo_name = repository
    base_url = f"https://{owner}.github.io/{repo_name}/installers"

    version = read_version(args.pubspec.resolve())
    now = _dt.datetime.now(tz=_dt.timezone.utc).replace(microsecond=0)
    timestamp = now.isoformat().replace("+00:00", "Z")

    generate_metadata(
        installers_dir,
        version=version,
        base_url=base_url,
        timestamp=timestamp,
        summary_name=args.summary_name,
    )


if __name__ == "__main__":
    main()
