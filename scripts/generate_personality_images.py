#!/usr/bin/env python3
"""
Generate personality + OpenClaw UI images using fal.ai (nano-banana-pro) and write them
into the UIComponents asset catalog.

This script intentionally never prints secrets.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
ASSETS_ROOT = (
    REPO_ROOT
    / "UIComponents"
    / "Sources"
    / "UIComponents"
    / "Resources"
    / "Assets.xcassets"
)


@dataclass(frozen=True)
class AssetJob:
    imageset: str
    prompt: str


STYLE = (
    "Unified style, slightly artistic, premium icon illustration. "
    "Soft painterly shading, subtle texture, clean silhouette, centered subject. "
    "Muted gradient background. No text, no watermark, no logo text, no UI. "
    "Square composition."
)


JOBS: list[AssetJob] = [
    AssetJob(
        imageset="friend-icon",
        prompt=f"Supportive friend assistant avatar. Warm, approachable, calm. {STYLE}",
    ),
    AssetJob(
        imageset="work-coach-icon",
        prompt=f"Work coach assistant avatar. Focus, momentum, clarity. {STYLE}",
    ),
    AssetJob(
        imageset="coach-icon",
        prompt=f"Life coach assistant avatar. Encouraging, confident, uplifting. {STYLE}",
    ),
    AssetJob(
        imageset="psychologist-icon",
        prompt=f"Psychologist assistant avatar. Gentle, trustworthy, thoughtful. {STYLE}",
    ),
    AssetJob(
        imageset="teacher-icon",
        prompt=f"Teacher assistant avatar. Curious, patient, smart. {STYLE}",
    ),
    AssetJob(
        imageset="nutritionist-icon",
        prompt=f"Nutritionist assistant avatar. Healthy, fresh, balanced. {STYLE}",
    ),
    AssetJob(
        imageset="butler-icon",
        prompt=f"Butler assistant avatar. Discreet, elegant, professional. {STYLE}",
    ),
    AssetJob(
        imageset="mother-icon",
        prompt=f"Motherly support assistant avatar. Warm, grounding, caring. {STYLE}",
    ),
    AssetJob(
        imageset="father-icon",
        prompt=f"Fatherly support assistant avatar. Steady, protective, practical. {STYLE}",
    ),
    AssetJob(
        imageset="openclaw-hero",
        prompt=(
            "OpenClaw ghost mark. A friendly ghost emblem with subtle blush, "
            "glowing edges, minimal, premium, slightly artistic. "
            "Muted gradient background. No text. Square."
        ),
    ),
]


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def get_fal_key(project_id: str, env: str) -> str:
    # Prefer explicit env var for CI / manual usage.
    direct = os.environ.get("FAL_API_KEY", "").strip()
    if direct:
        return direct

    # Fallback to Infisical, using a project id.
    p = _run(
        [
            "infisical",
            "secrets",
            "get",
            "FAL_API_KEY",
            "--projectId",
            project_id,
            "--env",
            env,
            "--plain",
        ]
    )
    if p.returncode != 0:
        raise RuntimeError(
            "Failed to read FAL_API_KEY from Infisical. "
            "Set FAL_API_KEY in env or pass a valid --infisical-project-id."
        )
    key = p.stdout.strip()
    if not key:
        raise RuntimeError(
            "Infisical returned an empty FAL_API_KEY. "
            "Set FAL_API_KEY in env or verify the secret exists."
        )
    return key


def fal_generate_png_bytes(api_key: str, prompt: str) -> bytes:
    url = "https://fal.run/fal-ai/nano-banana-pro"
    body = {
        "prompt": prompt,
        "image_size": "square_hd",
        "num_images": 1,
        "output_format": "png",
    }
    req = urllib.request.Request(
        url,
        method="POST",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            # fal.ai uses "Key" auth for server-side calls.
            "Authorization": f"Key {api_key}",
        },
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        payload = json.loads(resp.read().decode("utf-8"))

    images = payload.get("images") or []
    if not images or not isinstance(images, list):
        raise RuntimeError(f"Unexpected fal.ai response (no images): {payload.keys()}")

    first: Any = images[0]
    if not isinstance(first, dict) or "url" not in first:
        raise RuntimeError("Unexpected fal.ai response image schema.")

    image_url = first["url"]
    with urllib.request.urlopen(image_url, timeout=300) as img_resp:
        return img_resp.read()


def write_imageset_png(imageset: str, png_bytes: bytes) -> Path:
    out_dir = ASSETS_ROOT / f"{imageset}.imageset"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "image.png"
    out_path.write_bytes(png_bytes)
    return out_path


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--infisical-project-id",
        default=os.environ.get("INFISICAL_PROJECT_ID", "b123c134-981e-4ba5-ad4b-ab1e54259452"),
    )
    parser.add_argument(
        "--infisical-env",
        default=os.environ.get("INFISICAL_ENV", "prod"),
    )
    parser.add_argument("--only", default="", help="Comma-separated imageset names to generate.")
    args = parser.parse_args(argv)

    only = {s.strip() for s in args.only.split(",") if s.strip()}
    jobs = [j for j in JOBS if not only or j.imageset in only]

    api_key = get_fal_key(args.infisical_project_id, args.infisical_env)

    for job in jobs:
        png = fal_generate_png_bytes(api_key, job.prompt)
        out = write_imageset_png(job.imageset, png)
        print(f"Wrote {job.imageset} -> {out.relative_to(REPO_ROOT)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

