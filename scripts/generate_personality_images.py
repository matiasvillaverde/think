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
import time
import subprocess
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


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
    "Unified style, 2026-premium, slightly artistic icon illustration. "
    "Soft painterly shading, subtle texture, clean silhouette, centered subject. "
    "Muted gradient background. No text, no watermark, no logo text, no UI. "
    "Square composition."
)

LOGO_STYLE = (
    "Unified style, 2026-premium logo mark. Minimal emblem, crisp silhouette, subtle texture. "
    "Centered subject. Muted gradient background. No text, no watermark. Square composition."
)


ROLE_OVERRIDES: dict[str, str] = {
    "girlfriend-icon": (
        "Blonde girlfriend assistant avatar. Glamorous but tasteful, stylish, attractive, confident, kind. "
        "Fashion-editorial portrait vibe. No sexual content, no cleavage, no lingerie."
    ),
    "friend-icon": "Buddy assistant avatar. Warm, approachable, calm, loyal.",
    "work-coach-icon": "Work coach assistant avatar. Focus, momentum, clarity.",
    "coach-icon": "Life coach assistant avatar. Encouraging, confident, uplifting.",
    "psychologist-icon": "Psychologist assistant avatar. Gentle, trustworthy, thoughtful.",
    "teacher-icon": "Teacher assistant avatar. Curious, patient, smart.",
    "nutritionist-icon": "Nutritionist assistant avatar. Healthy, fresh, balanced.",
    "butler-icon": "Butler assistant avatar. Discreet, elegant, professional.",
    "mother-icon": (
        "Motherly support assistant avatar. Warm, grounding, caring, elegant and attractive. "
        "Tasteful portrait, cozy premium styling. No sexual content."
    ),
    "father-icon": "Fatherly support assistant avatar. Steady, protective, practical.",
    "writing-coach-icon": "Writing coach assistant avatar. Creative, articulate, sharp.",
    "translator-icon": "Translator assistant avatar. Global, precise, friendly.",
    "terminal-icon": "Developer assistant avatar. Focused, technical, calm.",
    "code-review-icon": "Code reviewer assistant avatar. Precise, pragmatic, sharp.",
    "security-icon": "Security specialist assistant avatar. Trustworthy, vigilant, calm.",
    "legal-icon": "Legal assistant avatar. Professional, balanced, clear.",
    "finance-icon": "Finance assistant avatar. Confident, organized, steady.",
    "travel-icon": "Travel planner assistant avatar. Adventurous, prepared, upbeat.",
    "math-icon": "Math tutor assistant avatar. Clear, precise, patient.",
    "history-icon": "History storyteller assistant avatar. Curious, wise, warm.",
    "psychology-icon": "Psychology guide assistant avatar. Empathetic, thoughtful, grounded.",
    "relationship-icon": "Relationship guide assistant avatar. Warm, empathetic, supportive.",
    "wellness-icon": "Wellness assistant avatar. Calm, healthy, balanced.",
    "motivation-icon": "Motivation coach assistant avatar. Energetic, encouraging, optimistic.",
    "gen-z-icon": "Gen Z friend assistant avatar. Modern, witty, friendly.",
    "social-icon": "Social media assistant avatar. Trend-aware, confident, playful.",
    "seo-icon": "SEO assistant avatar. Strategic, analytical, focused.",
    "debate-icon": "Debate coach assistant avatar. Confident, sharp, fair.",
    "interview-icon": "Interview coach assistant avatar. Calm, encouraging, professional.",
    "screenplay-icon": "Screenplay coach assistant avatar. Cinematic, creative, polished.",
    "story-icon": "Storyteller assistant avatar. Imaginative, warm, whimsical.",
    "philosophy-icon": "Philosophy guide assistant avatar. Minimal, contemplative, wise.",
    "adventure-icon": "Adventure buddy assistant avatar. Bold, curious, upbeat.",
    "nutrition-icon": "Nutrition guide assistant avatar. Fresh, clean, balanced.",
    "think": "Think assistant avatar. Minimal friendly ghost + sparkles, premium, calm.",
}


MODEL_LOGOS: dict[str, str] = {
    "openai": "Abstract swirl emblem, clean and premium, subtle monochrome gradient, no text.",
    "openrouter": "Abstract network ring emblem, modern and premium, no text.",
    "anthropic": "Abstract geometric 'A' inspired mark, minimal and premium, no text.",
    "microsoft": "Four-square geometric emblem, modern color blocks, no text.",
    "meta": "Interlaced loop emblem, cool gradient, minimal, no text.",
    "gemini": "Twin-star / diamond emblem, subtle glow, minimal, no text.",
    "mistral": "Wind swirl emblem, warm red-orange palette, minimal, no text.",
    "gemma": "Faceted gem emblem, cool blue palette, minimal, no text.",
    "qwen": "Circular wave emblem, teal/indigo palette, minimal, no text.",
    "deepseek": "Deep ocean eye emblem, dark teal palette, minimal, no text.",
    "smol": "Tiny robot/cube emblem, playful but premium, no text.",
}


OPENCLAW_OVERRIDES: dict[str, str] = {
    "openclaw-ghost": (
        "OpenClaw ghost mark. Friendly ghost emblem with subtle blush, glowing edges, "
        "minimal, premium. No text."
    ),
    "openclaw-hero": (
        "OpenClaw hero illustration: friendly ghost and claw motif, minimal, premium, "
        "slightly artistic. No text."
    ),
    "openclaw-claw": (
        "OpenClaw logo mark: a cute stylized lobster claw emblem, bright warm red palette, "
        "minimal, premium, slightly artistic. Soft glowing edges, crisp silhouette. No text."
    ),
}


SPECIAL_ASSETS: dict[str, str] = {
    "placeholderImageGeneration": (
        "Image generation placeholder. Abstract dreamy gradient with soft shapes and sparkles. "
        "Premium, minimal. No text."
    ),
}


PERSON_VARIANTS: dict[str, str] = {
    "Person1": "Smiling person avatar, warm and friendly, subtle blush.",
    "Person2": "Smiling person avatar, confident and upbeat, subtle blush.",
    "Person3": "Smiling person avatar, calm and thoughtful, subtle blush.",
    "Person4": "Smiling person avatar, playful and kind, subtle blush.",
    "Person5": "Smiling person avatar, professional and warm, subtle blush.",
    "Person6": "Smiling person avatar, creative and curious, subtle blush.",
    "Person7": "Smiling person avatar, relaxed and supportive, subtle blush.",
    "Person8": "Smiling person avatar, bold and friendly, subtle blush.",
}


def discover_imagesets() -> list[str]:
    return sorted([p.stem for p in ASSETS_ROOT.glob("*.imageset") if p.is_dir()])


def prompt_for_imageset(imageset: str) -> str:
    if imageset in OPENCLAW_OVERRIDES:
        return f"{OPENCLAW_OVERRIDES[imageset]} {STYLE}"

    if imageset in SPECIAL_ASSETS:
        return f"{SPECIAL_ASSETS[imageset]} {STYLE}"

    if imageset in MODEL_LOGOS:
        return f"{MODEL_LOGOS[imageset]} {LOGO_STYLE}"

    if imageset in PERSON_VARIANTS:
        return f"{PERSON_VARIANTS[imageset]} {STYLE}"

    if imageset in ROLE_OVERRIDES:
        return f"{ROLE_OVERRIDES[imageset]} {STYLE}"

    if imageset.endswith("-icon"):
        base = imageset.removesuffix("-icon").replace("-", " ")
        return f"{base.title()} assistant avatar. {STYLE}"

    # Fallback: generic premium icon for any other imageset.
    name = imageset.replace("-", " ")
    return f"Minimal premium illustration representing: {name}. {STYLE}"


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
    last_err: Exception | None = None
    for attempt in range(1, 4):
        try:
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
        except Exception as e:
            last_err = e
            if attempt < 3:
                backoff = 2**attempt
                print(f"fal.ai request failed (attempt {attempt}/3), retrying in {backoff}s...", file=sys.stderr)
                time.sleep(backoff)
            else:
                break

    raise RuntimeError(f"fal.ai request failed after retries: {last_err!r}")


def write_imageset_png(imageset: str, png_bytes: bytes) -> Path:
    out_dir = ASSETS_ROOT / f"{imageset}.imageset"
    out_dir.mkdir(parents=True, exist_ok=True)

    # Reset imageset to a single universal PNG to avoid having to manage 1x/2x/3x variants.
    for child in out_dir.iterdir():
        if child.name == "Contents.json":
            continue
        if child.is_file():
            child.unlink()

    out_path = out_dir / "image.png"
    out_path.write_bytes(png_bytes)

    contents = {
        "images": [{"filename": "image.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    (out_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")
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
    parser.add_argument(
        "--list",
        action="store_true",
        help="List imageset names discovered in the asset catalog.",
    )
    args = parser.parse_args(argv)

    all_imagesets = discover_imagesets()
    if args.list:
        for name in all_imagesets:
            print(name)
        return 0

    only = {s.strip() for s in args.only.split(",") if s.strip()}
    target_imagesets: Iterable[str]
    if only:
        target_imagesets = [n for n in all_imagesets if n in only]
        missing = sorted(only.difference(set(all_imagesets)))
        if missing:
            raise RuntimeError(f"Unknown imagesets: {', '.join(missing)}")
    else:
        target_imagesets = all_imagesets

    api_key = get_fal_key(args.infisical_project_id, args.infisical_env)

    for imageset in target_imagesets:
        prompt = prompt_for_imageset(imageset)
        print(f"Generating {imageset}...", file=sys.stderr, flush=True)
        png = fal_generate_png_bytes(api_key, prompt)
        out = write_imageset_png(imageset, png)
        print(f"Wrote {imageset} -> {out.relative_to(REPO_ROOT)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
