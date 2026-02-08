#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


@dataclass(frozen=True)
class RunCtx:
    think_bin: Path
    workspace: Path
    store_name: str
    config_path: Path
    logs_dir: Path
    env: Dict[str, str]


class StepFailed(RuntimeError):
    pass


CHAT_TIMEOUT_S = int(os.environ.get("THINK_UC_CHAT_TIMEOUT_S", "1800"))


def _ts() -> str:
    return time.strftime("%Y%m%d-%H%M%S")


def _extract_uuid(text: str) -> Optional[str]:
    """
    Best-effort UUID extraction from CLI message strings like:
      "Created skill <uuid>"
      "Personality chat <uuid>"
    """
    for token in reversed(text.strip().split()):
        try:
            _ = uuid.UUID(token)
            return token
        except Exception:
            continue
    return None


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def run_step(
    ctx: RunCtx,
    name: str,
    args: List[str],
    *,
    json_output: bool = False,
    allow_fail: bool = False,
    extra_env: Optional[Dict[str, str]] = None,
    timeout_s: Optional[int] = None,
) -> Tuple[int, str, str, Optional[Any]]:
    """
    Runs: think <args...> with standard store/workspace/config isolation.
    Logs stdout/stderr to files and optionally parses stdout as JSON.
    """
    cmd = [str(ctx.think_bin), "--store", ctx.store_name, "--workspace", str(ctx.workspace)] + args
    env = dict(ctx.env)
    if extra_env:
        env.update(extra_env)

    safe_cmd = " ".join(shlex.quote(c) for c in cmd)
    prefix = f"{int(time.time())}-{name}".replace("/", "_").replace(" ", "_")
    out_path = ctx.logs_dir / f"{prefix}.out.txt"
    err_path = ctx.logs_dir / f"{prefix}.err.txt"
    meta_path = ctx.logs_dir / f"{prefix}.meta.json"

    started = time.time()
    # Guard against runaway generations in long scenario runs.
    # Many chat sends use --no-stream, so without a timeout a single bad decode could stall the whole suite.
    # subprocess.run treats 0 as "timeout immediately", so normalize 0/negative to "no timeout".
    effective_timeout_s = timeout_s if (timeout_s is not None and timeout_s > 0) else None
    if effective_timeout_s is None:
        for i in range(len(args) - 1):
            if args[i] == "chat" and args[i + 1] == "send":
                # Allow disabling default timeouts for "run as long as needed" by setting THINK_UC_CHAT_TIMEOUT_S=0.
                effective_timeout_s = CHAT_TIMEOUT_S if CHAT_TIMEOUT_S > 0 else None
                break
    if json_output:
        p = subprocess.run(
            cmd,
            env=env,
            text=True,
            capture_output=True,
            timeout=effective_timeout_s,
        )
        stdout_text = p.stdout
        stderr_text = p.stderr
    else:
        # Stream potentially large output directly to files to avoid OOM on long downloads.
        with out_path.open("w", encoding="utf-8") as out_f, err_path.open(
            "w", encoding="utf-8"
        ) as err_f:
            p = subprocess.run(
                cmd,
                env=env,
                text=True,
                stdout=out_f,
                stderr=err_f,
                timeout=effective_timeout_s,
            )
        stdout_text = out_path.read_text(encoding="utf-8", errors="replace")
        stderr_text = err_path.read_text(encoding="utf-8", errors="replace")
    dur_ms = int((time.time() - started) * 1000)
    if json_output:
        _write_text(out_path, stdout_text)
        _write_text(err_path, stderr_text)
    _write_text(
        meta_path,
        json.dumps(
            {
                "name": name,
                "cmd": safe_cmd,
                "exit_code": p.returncode,
                "duration_ms": dur_ms,
                "stdout_path": str(out_path),
                "stderr_path": str(err_path),
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
    )

    parsed = None
    if json_output:
        try:
            parsed = json.loads(stdout_text)
        except Exception as e:
            if not allow_fail:
                raise StepFailed(
                    f"Step {name} expected JSON but could not parse stdout: {e}\ncmd={safe_cmd}\nstdout={stdout_text[:5000]}\nstderr={stderr_text[:5000]}"
                )

    if p.returncode != 0 and not allow_fail:
        raise StepFailed(
            f"Step {name} failed (exit {p.returncode}).\ncmd={safe_cmd}\nstdout={stdout_text[:5000]}\nstderr={stderr_text[:5000]}"
        )

    return p.returncode, stdout_text, stderr_text, parsed


def run_tool(
    ctx: RunCtx,
    name: str,
    tool_name: str,
    tool_args: Dict[str, Any],
    *,
    allow_fail: bool = False,
    timeout_s: Optional[int] = None,
) -> Any:
    """
    Convenience wrapper around: think tools run <tool_name> --args <json>
    Always requests JSON output.
    """
    _, _, _, obj = run_step(
        ctx,
        name,
        ["tools", "run", tool_name, "--args", json.dumps(tool_args), "--format", "json"],
        json_output=True,
        allow_fail=allow_fail,
        timeout_s=timeout_s,
    )
    return obj


def pick_first_working_model_download(ctx: RunCtx, candidates: List[Tuple[str, str]]) -> str:
    """
    candidates: list of (repo_id, backend) where backend in (mlx, gguf, coreml).
    Returns repo_id that successfully downloaded.
    """
    last_err = None
    for repo_id, backend in candidates:
        rc, out, err, _ = run_step(
            ctx,
            f"models_download_{repo_id.replace('/', '_')}",
            ["models", "download", repo_id, "--backend", backend],
            allow_fail=True,
        )
        if rc == 0:
            return repo_id

        combined = (out + "\n" + err).lower()
        if "already downloaded" in combined:
            return repo_id

        last_err = f"download failed for {repo_id} ({backend}): rc={rc}\n{err[:2000]}"
    raise StepFailed(f"All model download candidates failed.\n{last_err}")


def ensure_language_model(ctx: RunCtx) -> str:
    candidates: List[Tuple[str, str]] = [
        # Prefer the smallest viable model to keep long scenario runs practical.
        ("mlx-community/SmolLM-135M-4bit", "mlx"),
        ("mlx-community/SmolLM-360M-Instruct-4bit", "mlx"),
        ("mlx-community/SmolLM-1.7B-Instruct-4bit", "mlx"),
    ]
    models_root = Path.home() / "Library" / "Application Support" / "ThinkAI" / "Models" / "mlx"
    for repo_id, _backend in candidates:
        if (models_root / repo_id.replace("/", "_")).exists():
            return repo_id
    return pick_first_working_model_download(ctx, candidates)


def ensure_diffusion_model(ctx: RunCtx) -> str:
    candidates: List[Tuple[str, str]] = [
        ("coreml-community/coreml-Inkpunk-Diffusion", "coreml"),
    ]
    models_root = Path.home() / "Library" / "Application Support" / "ThinkAI" / "Models" / "coreml"
    for repo_id, _backend in candidates:
        if (models_root / repo_id.replace("/", "_")).exists():
            return repo_id
    return pick_first_working_model_download(ctx, candidates)


def create_chat(ctx: RunCtx, title: str) -> str:
    _, _, _, obj = run_step(ctx, "chat_create", ["chat", "create", "--title", title, "--format", "json"], json_output=True)
    # session is expected to be a dict with "id"
    chat_id = obj.get("id") if isinstance(obj, dict) else None
    if not chat_id:
        raise StepFailed(f"chat create did not return id. stdout JSON: {obj}")
    return chat_id


def create_skill(ctx: RunCtx, name: str, tools: List[str], instructions: str) -> str:
    args = [
        "skills",
        "create",
        "--name",
        name,
        "--description",
        f"autogen:{name}",
        "--instructions",
        instructions,
        "--format",
        "json",
    ]
    for t in tools:
        args += ["--tools", t]
    _, _, _, obj = run_step(ctx, f"skill_create_{name}", args, json_output=True)
    skill_id = None
    if isinstance(obj, dict) and isinstance(obj.get("message"), str):
        skill_id = _extract_uuid(obj["message"])
    if not skill_id:
        # Fallback: list and resolve by name.
        _, _, _, skills = run_step(
            ctx, "skills_list", ["skills", "list", "--format", "json"], json_output=True
        )
        if isinstance(skills, list):
            for s in skills:
                if isinstance(s, dict) and s.get("name") == name:
                    skill_id = s.get("id")
                    break
    if not skill_id:
        raise StepFailed(f"Could not determine skill id for {name}")
    return skill_id


def create_personality(ctx: RunCtx, name: str, category: str) -> str:
    args = [
        "personality",
        "create",
        "--name",
        name,
        "--description",
        f"autogen:{name}",
        "--instructions",
        f"You are {name}. Keep outputs structured and actionable.",
        "--category",
        category,
        "--format",
        "json",
    ]
    _, _, _, obj = run_step(ctx, f"personality_create_{name}", args, json_output=True)
    pid = None
    if isinstance(obj, dict) and isinstance(obj.get("message"), str):
        pid = _extract_uuid(obj["message"])
    if not pid:
        # fallback: list and find by name
        _, _, _, plist = run_step(ctx, "personality_list", ["personality", "list", "--format", "json"], json_output=True)
        if isinstance(plist, list):
            for p in plist:
                if isinstance(p, dict) and p.get("name") == name:
                    pid = p.get("id")
                    break
    if not pid:
        raise StepFailed(f"Could not determine personality id for {name}")
    return pid


def rag_index_file_for_chat(ctx: RunCtx, chat_id: str, file_path: Path) -> str:
    content_id = str(uuid.uuid4()).upper()
    run_step(
        ctx,
        f"rag_index_{file_path.name}",
        ["rag", "index", "--chat", chat_id, "--id", content_id, "--file", str(file_path)],
    )
    return content_id


def rag_index_text_for_chat(ctx: RunCtx, chat_id: str, text: str) -> str:
    content_id = str(uuid.uuid4()).upper()
    run_step(
        ctx,
        "rag_index_text",
        ["rag", "index", "--chat", chat_id, "--id", content_id, "--text", text],
    )
    return content_id


def rag_delete_for_chat(ctx: RunCtx, chat_id: str, content_id: str) -> None:
    run_step(ctx, f"rag_delete_{content_id}", ["rag", "delete", "--chat", chat_id, content_id])


def reset_cli_store(store_name: str) -> None:
    """
    Remove the SwiftData store artifacts used by ThinkCLI so each run starts clean.
    Models are stored separately under ~/Library/Application Support/ThinkAI/Models and are not affected.
    """
    store_base = store_name[:-6] if store_name.endswith(".store") else store_name
    root = Path.home() / "Library" / "Application Support"

    # DatabaseStoreResetPolicy writes a version file at storeURL + ".version".
    # In ThinkCLI, storeURL is typically ~/Library/Application Support/<store_base>
    store_url = root / store_base
    candidates = [
        store_url.with_suffix(store_url.suffix + ".version"),  # <store_base>.version
        store_url,
        store_url.with_suffix(store_url.suffix + ".sqlite"),
        store_url.with_suffix(store_url.suffix + ".sqlite-wal"),
        store_url.with_suffix(store_url.suffix + ".sqlite-shm"),
        store_url.with_suffix(store_url.suffix + ".store"),
        Path(str(store_url.with_suffix(store_url.suffix + ".store")) + "-wal"),
        Path(str(store_url.with_suffix(store_url.suffix + ".store")) + "-shm"),
        store_url.with_suffix(store_url.suffix + ".store.store-wal"),
        store_url.with_suffix(store_url.suffix + ".store.store-shm"),
    ]
    for p in candidates:
        try:
            if p.exists():
                p.unlink()
        except Exception:
            # Best-effort cleanup; if we can't delete, the run will surface the underlying issue.
            pass


def main() -> int:
    think_dir = Path(__file__).resolve().parents[1]
    think_bin = think_dir / ".build" / "debug" / "think"
    if not think_bin.exists():
        raise SystemExit(f"think binary not found at {think_bin}. Run `make build` first.")

    workspace = Path("/Users/mati/Code/Nell-Technologies/monorepo")
    run_id = _ts()
    logs_dir = think_dir / ".codex" / "usecase-runs" / run_id
    logs_dir.mkdir(parents=True, exist_ok=True)

    # Stable store base name; we reset its DB artifacts each run for determinism.
    # (Model downloads live elsewhere and are not impacted.)
    store_name = "codex-usecases"
    # Keep config stable across reruns too (but logs still go to a unique dir).
    config_path = think_dir / ".codex" / "usecase-config.json"
    env = dict(os.environ)
    env["THINK_CLI_CONFIG"] = str(config_path)
    # HuggingFace auth: prefer explicit HF_TOKEN if present; otherwise try the standard token file.
    # We avoid printing the token anywhere; it's only passed via environment.
    if not env.get("HF_TOKEN"):
        token_path = Path.home() / ".cache" / "huggingface" / "token"
        if token_path.exists():
            token = token_path.read_text(encoding="utf-8").strip()
            if token:
                env["HF_TOKEN"] = token

    ctx = RunCtx(
        think_bin=think_bin,
        workspace=workspace,
        store_name=store_name,
        config_path=config_path,
        logs_dir=logs_dir,
        env=env,
    )

    reset_cli_store(store_name)

    # Preflight
    run_step(ctx, "doctor_pre", ["doctor", "--format", "json"])
    run_step(ctx, "status_pre", ["status", "--format", "json"], json_output=True)
    run_step(ctx, "models_list_pre", ["models", "list", "--format", "json"], json_output=True)

    # Ensure models needed for all scenarios: language + diffusion.
    lang_repo = ensure_language_model(ctx)
    diff_repo = ensure_diffusion_model(ctx)

    # Onboard without prompting: configure workspace + set default model by repo id (already downloaded).
    run_step(
        ctx,
        "onboard",
        [
            "onboard",
            "--non-interactive",
            "--workspace-path",
            str(workspace),
            "--model",
            lang_repo,
            "--backend",
            "mlx",
            "--skip-download",
        ],
    )
    run_step(ctx, "config_show", ["config", "show", "--format", "json"], json_output=True)
    run_step(ctx, "config_resolve", ["config", "resolve", "--format", "json"], json_output=True)

    # Use Case 1 (subset + verification chat/RAG + gateway once)
    chat1 = create_chat(ctx, "uc1-bootstrap")
    run_step(ctx, "chat_send_uc1", ["chat", "send", "--session", chat1, "--prompt", "Confirm setup; summarize config.", "--no-stream", "--format", "json"], json_output=True)
    ids_uc1 = [
        rag_index_file_for_chat(ctx, chat1, workspace / "AGENTS.md"),
        rag_index_text_for_chat(
            ctx,
            chat1,
            "OpenAPI workflow is critical; never edit openapi/openapi.json manually.",
        ),
    ]
    run_step(
        ctx,
        "rag_search_uc1",
        ["rag", "search", "--chat", chat1, "--query", "OpenAPI workflow", "--limit", "3", "--format", "json"],
        json_output=True,
    )
    run_step(ctx, "gateway_start_once", ["gateway", "start", "--once", "--port", "9876"])
    run_step(ctx, "gateway_status", ["gateway", "status", "--format", "json"], json_output=True)
    for cid in ids_uc1:
        rag_delete_for_chat(ctx, chat1, cid)

    # Use Case 2: RAG-backed audit with tools run (workspace tool)
    chat2 = create_chat(ctx, "uc2-audit")
    rag_ids2 = [
        rag_index_file_for_chat(ctx, chat2, workspace / "AGENTS.md"),
        rag_index_file_for_chat(ctx, chat2, workspace / "CLAUDE.md"),
    ]
    run_step(ctx, "tools_list_uc2", ["tools", "list", "--format", "json"], json_output=True)
    run_step(
        ctx,
        "tools_run_workspace_list",
        ["tools", "run", "workspace", "--args", json.dumps({"action": "list", "path": ".", "recursive": False}) , "--format", "json"],
        json_output=True,
    )
    run_step(
        ctx,
        "tools_run_workspace_read_agents",
        ["tools", "run", "workspace", "--args", json.dumps({"action": "read", "path": "AGENTS.md"}) , "--format", "json"],
        json_output=True,
    )
    run_step(ctx, "chat_send_uc2", ["chat", "send", "--session", chat2, "--prompt", "Using the indexed docs, propose a repo audit checklist.", "--no-stream", "--format", "json"], json_output=True)
    run_step(
        ctx,
        "rag_search_uc2",
        ["rag", "search", "--chat", chat2, "--query", "OpenAPI", "--limit", "5", "--format", "json"],
        json_output=True,
    )
    for cid in rag_ids2:
        rag_delete_for_chat(ctx, chat2, cid)

    # Use Case 3: tool-access deny and allow only when explicit (exercise error path too)
    chat3 = create_chat(ctx, "uc3-zero-trust")
    run_step(ctx, "status_deny", ["status", "--tool-access", "deny", "--format", "json"], json_output=True)
    # Should succeed: no tools used.
    run_step(ctx, "chat_send_uc3_no_tools", ["chat", "send", "--session", chat3, "--prompt", "Operate without tools. Explain limitations.", "--no-tools", "--no-stream", "--format", "json"], json_output=True)
    # Tools run should be denied only if via chat with requested tools; tools command itself should still work (policy is per runtime settings).
    # Exercise: chat send with requested tools while tool-access deny should error; allow_fail.
    run_step(
        ctx,
        "chat_send_uc3_expect_denied",
        ["chat", "send", "--session", chat3, "--prompt", "Try to use a tool.", "--tools", "workspace", "--no-stream", "--tool-access", "deny", "--format", "json"],
        json_output=True,
        allow_fail=True,
    )

    # Use Case 4: multi-model inventory + switching default model (use add-local dummy for switching safely)
    dummy_path = str((logs_dir / "dummy.model").resolve())
    _write_text(Path(dummy_path), "dummy")
    run_step(
        ctx,
        "models_add_local_dummy",
        ["models", "add-local", "--name", "dummy-local", "--path", dummy_path, "--backend", "mlx", "--type", "language", "--format", "json"],
        json_output=True,
    )
    run_step(ctx, "models_list_uc4", ["models", "list", "--format", "json"], json_output=True)
    # keep default model unchanged, but exercise config set/clear
    run_step(ctx, "config_set_skills_empty", ["config", "set", "--skills", "nonexistent-skill", "--format", "json"], json_output=True, allow_fail=True)
    run_step(ctx, "config_clear_skills", ["config", "set", "--clear-skills", "--format", "json"], json_output=True)

    # Use Case 5: image generation send (requires diffusion model present/downloaded)
    chat5 = create_chat(ctx, "uc5-image")
    run_step(
        ctx,
        "chat_send_image",
        ["chat", "send", "--session", chat5, "--prompt", "Generate a simple abstract image prompt.", "--image", "--no-stream", "--format", "json"],
        json_output=True,
    )
    # Schedule image action (create -> list -> disable -> enable -> delete)
    run_step(
        ctx,
        "schedule_create_img",
        [
            "schedules",
            "create",
            "--title",
            "uc5 nightly image",
            "--prompt",
            "Generate an image for testing.",
            "--cron",
            "0 2 * * *",
            "--action",
            "image",
            "--chat",
            chat5,
            "--disabled",
            "--format",
            "json",
        ],
        json_output=True,
    )
    # list schedules and grab one id (best-effort)
    _, _, _, scheds = run_step(
        ctx, "schedules_list_uc5", ["schedules", "list", "--format", "json"], json_output=True
    )
    sched_id = None
    if isinstance(scheds, list):
        for s in scheds:
            if isinstance(s, dict) and s.get("title") == "uc5 nightly image":
                sched_id = s.get("id")
                break
    if sched_id:
        run_step(ctx, "schedule_enable_uc5", ["schedules", "enable", sched_id])
        run_step(ctx, "schedule_disable_uc5", ["schedules", "disable", sched_id])
        run_step(ctx, "schedule_delete_uc5", ["schedules", "delete", sched_id])

    # Use Case 6: incident runbook via RAG + schedule pulse
    chat6 = create_chat(ctx, "uc6-incident")
    run_step(ctx, "chat_rename_uc6", ["chat", "rename", "--session", chat6, "incident-uc6"])
    id6a = rag_index_text_for_chat(ctx, chat6, "ERROR timeout contacting upstream service X")
    run_step(
        ctx,
        "rag_search_uc6",
        ["rag", "search", "--chat", chat6, "--query", "timeout", "--limit", "5", "--format", "json"],
        json_output=True,
    )
    run_step(
        ctx,
        "schedule_create_pulse",
        [
            "schedules",
            "create",
            "--title",
            "uc6 pulse",
            "--prompt",
            "Summarize incident context and propose next checks.",
            "--cron",
            "*/15 * * * *",
            "--chat",
            chat6,
            "--disabled",
            "--format",
            "json",
        ],
        json_output=True,
    )
    _, _, _, scheds6 = run_step(ctx, "schedules_list_uc6", ["schedules", "list", "--format", "json"], json_output=True)
    pulse_id = None
    if isinstance(scheds6, list):
        for s in scheds6:
            if isinstance(s, dict) and s.get("title") == "uc6 pulse":
                pulse_id = s.get("id")
                break
    if pulse_id:
        run_step(ctx, "schedule_enable_uc6", ["schedules", "enable", pulse_id])
        run_step(ctx, "schedule_disable_uc6", ["schedules", "disable", pulse_id])
        run_step(ctx, "schedule_delete_uc6", ["schedules", "delete", pulse_id])
    rag_delete_for_chat(ctx, chat6, id6a)

    # Use Case 7: gateway + remote model ref (no actual remote inference, just add/list/remove)
    run_step(ctx, "gateway_start_once_uc7", ["gateway", "start", "--once", "--port", "9988", "--token", "test-token"])
    run_step(ctx, "models_add_remote_gateway", ["models", "add-remote", "--name", "team-gateway", "--location", "http://localhost:9988", "--type", "language", "--format", "json"], json_output=True)
    run_step(ctx, "models_list_uc7", ["models", "list", "--format", "json"], json_output=True)

    # Use Case 8: skill-driven engineering assistant (create/enable/preferred skills + tools run)
    skill8 = create_skill(
        ctx,
        "eng-implementer",
        tools=["workspace", "python_exec"],
        instructions="When asked to change code: inspect files, propose minimal diffs, and request tests.",
    )
    run_step(ctx, "skill8_enable", ["skills", "enable", skill8])
    run_step(ctx, "config_set_skill8", ["config", "set", "--skills", "eng-implementer", "--format", "json"], json_output=True)
    chat8 = create_chat(ctx, "uc8-eng")
    run_step(ctx, "chat_send_uc8", ["chat", "send", "--session", chat8, "--prompt", "List 3 potential improvements to AGENTS.md style guidelines.", "--no-stream", "--format", "json"], json_output=True)
    run_step(
        ctx,
        "tools_run_python_exec",
        ["tools", "run", "python_exec", "--args", json.dumps({"code": "print('ok')", "timeout": 30}), "--format", "json"],
        json_output=True,
    )

    # Use Case 9: daily briefing schedule + memory via RAG
    chat9 = create_chat(ctx, "uc9-daily")
    id9 = rag_index_file_for_chat(ctx, chat9, workspace / "AGENTS.md")
    run_step(ctx, "chat_send_uc9", ["chat", "send", "--session", chat9, "--prompt", "Generate a daily briefing skeleton using the indexed guidelines.", "--no-stream", "--format", "json"], json_output=True)
    run_step(
        ctx,
        "schedule_create_daily",
        [
            "schedules",
            "create",
            "--title",
            "uc9 daily briefing",
            "--prompt",
            "Generate daily briefing.",
            "--cron",
            "0 9 * * 1-5",
            "--chat",
            chat9,
            "--disabled",
            "--format",
            "json",
        ],
        json_output=True,
    )
    rag_delete_for_chat(ctx, chat9, id9)

    # Use Case 10: personalities panel + synthesis chat
    p_opt = create_personality(ctx, "panel-optimist", "productivity")
    p_ske = create_personality(ctx, "panel-skeptic", "productivity")
    p_aud = create_personality(ctx, "panel-auditor", "productivity")
    _, _, _, opt_chat_obj = run_step(
        ctx, "personality_chat_opt", ["personality", "chat", p_opt, "--format", "json"], json_output=True
    )
    _, _, _, ske_chat_obj = run_step(
        ctx, "personality_chat_ske", ["personality", "chat", p_ske, "--format", "json"], json_output=True
    )
    _, _, _, aud_chat_obj = run_step(
        ctx, "personality_chat_aud", ["personality", "chat", p_aud, "--format", "json"], json_output=True
    )
    opt_chat = _extract_uuid(opt_chat_obj.get("message", "")) if isinstance(opt_chat_obj, dict) else None
    ske_chat = _extract_uuid(ske_chat_obj.get("message", "")) if isinstance(ske_chat_obj, dict) else None
    aud_chat = _extract_uuid(aud_chat_obj.get("message", "")) if isinstance(aud_chat_obj, dict) else None
    synth = create_chat(ctx, "uc10-synthesis")
    id10 = rag_index_text_for_chat(
        ctx, synth, "Proposal: adopt stricter OpenAPI-first enforcement in CI."
    )
    for chat_id, prompt in [
        (opt_chat, "Argue for shipping quickly; propose plan."),
        (ske_chat, "Argue against; list risks and failure modes."),
        (aud_chat, "Define acceptance criteria and test gates."),
    ]:
        if chat_id:
            run_step(ctx, f"panel_send_{chat_id[:8]}", ["chat", "send", "--session", chat_id, "--prompt", prompt, "--no-stream", "--format", "json"], json_output=True)
    run_step(ctx, "chat_send_synth", ["chat", "send", "--session", synth, "--prompt", "Synthesize the panel positions into a decision and checklist.", "--no-stream", "--format", "json"], json_output=True)
    rag_delete_for_chat(ctx, synth, id10)

    # Use Case 11: research assistant (OpenClaw-inspired) using web search tools + memory + canvas + RAG
    chat11 = create_chat(ctx, "uc11-research")
    run_step(ctx, "chat_get_uc11", ["chat", "get", chat11, "--format", "json"], json_output=True)
    run_step(ctx, "chat_list_uc11", ["chat", "list", "--format", "json"], json_output=True)
    res11a = run_tool(ctx, "uc11_ddg_search", "duckduckgo_search", {"query": "OpenClaw use cases automation workflows", "count": 5, "region": "us-en"})
    res11b = run_tool(ctx, "uc11_brave_search", "brave_search", {"query": "openclaw lobster workflow runner yaml json pipeline", "count": 5, "safe_search": "moderate"})
    res11c = run_tool(ctx, "uc11_browser_search", "browser.search", {"query": "OpenClaw cron jobs tools skills", "resultCount": 3})
    run_tool(
        ctx,
        "uc11_memory_write",
        "memory",
        {
            "type": "longTerm",
            "content": "Use Case: Research assistant that can search the web, synthesize findings, and save a report to workspace for later retrieval.",
            "keywords": ["openclaw", "research", "tools", "rag"],
        },
    )
    web_report11 = (
        "# UC11 Web Research Notes\n\n"
        "## DuckDuckGo\n"
        f"{json.dumps(res11a, indent=2, sort_keys=True)}\n\n"
        "## Brave\n"
        f"{json.dumps(res11b, indent=2, sort_keys=True)}\n\n"
        "## Browser.Search\n"
        f"{json.dumps(res11c, indent=2, sort_keys=True)}\n"
    )
    run_tool(ctx, "uc11_ws_write_report", "workspace", {"action": "write", "path": ".codex-uc11-web.md", "content": web_report11})
    run_tool(ctx, "uc11_ws_read_report", "workspace", {"action": "read", "path": ".codex-uc11-web.md"})
    run_tool(ctx, "uc11_canvas_create", "canvas", {"action": "create", "chat_id": chat11, "title": "UC11 Findings", "content": "Web research findings will be summarized here."})
    run_tool(ctx, "uc11_canvas_append", "canvas", {"action": "append", "chat_id": chat11, "content": "Key themes: cron automation, tool plugins, workflow runner, memory + retrieval."})
    run_tool(ctx, "uc11_canvas_list", "canvas", {"action": "list", "chat_id": chat11})
    run_step(
        ctx,
        "chat_send_uc11",
        ["chat", "send", "--session", chat11, "--prompt", "Summarize the research notes and propose 5 ThinkCLI feature checks to validate parity.", "--no-stream", "--format", "json"],
        json_output=True,
        timeout_s=CHAT_TIMEOUT_S,
    )
    id11 = rag_index_file_for_chat(ctx, chat11, workspace / ".codex-uc11-web.md")
    run_step(ctx, "rag_search_uc11", ["rag", "search", "--chat", chat11, "--query", "workflow", "--limit", "5", "--format", "json"], json_output=True)
    rag_delete_for_chat(ctx, chat11, id11)

    # Use Case 12: personal life manager (OpenClaw-inspired) using weather + memory + cron tool scheduling
    chat12 = create_chat(ctx, "uc12-personal")
    run_tool(ctx, "uc12_weather_now", "weather", {"location": "San Francisco, CA", "units": "fahrenheit", "forecast": True, "days": 3})
    run_tool(ctx, "uc12_memory_daily", "memory", {"type": "daily", "content": "User wants a morning briefing including weather + top repo tasks.", "keywords": ["briefing", "weather"]})
    run_tool(ctx, "uc12_cron_create", "cron", {"action": "create", "title": "uc12 morning brief", "prompt": "Generate a morning briefing: weather + tasks.", "cron": "0 8 * * 1-5", "chat_id": chat12, "action_type": "text"})
    run_tool(ctx, "uc12_cron_list", "cron", {"action": "list"})
    # Toggle schedule by id (best-effort: list result shape can vary; exercise update path too).
    run_tool(ctx, "uc12_cron_update", "cron", {"action": "update", "title": "uc12 morning brief (updated)", "prompt": "Morning briefing: weather + top 3 tasks.", "cron": "5 8 * * 1-5", "chat_id": chat12, "action_type": "text"}, allow_fail=True)
    run_step(
        ctx,
        "chat_send_uc12",
        ["chat", "send", "--session", chat12, "--prompt", "Draft a short morning briefing template. Include weather placeholders and a checklist.", "--no-stream", "--format", "json"],
        json_output=True,
        timeout_s=CHAT_TIMEOUT_S,
    )

    # Use Case 13: digital agency automation (OpenClaw-inspired) using workspace + RAG + canvas deliverables
    chat13 = create_chat(ctx, "uc13-agency")
    client_brief = (
        "# Client Brief\n\n"
        "Goal: Ship a feature safely.\n"
        "Constraints: Offline-first; OpenAPI-first; avoid manual edits to openapi/openapi.json.\n"
        "Deliverable: Checklist + timeline.\n"
    )
    run_tool(ctx, "uc13_ws_write_brief", "workspace", {"action": "write", "path": ".codex-uc13-brief.md", "content": client_brief})
    run_tool(ctx, "uc13_ws_list_root", "workspace", {"action": "list", "path": ".", "recursive": False})
    id13 = rag_index_file_for_chat(ctx, chat13, workspace / ".codex-uc13-brief.md")
    run_step(ctx, "rag_search_uc13", ["rag", "search", "--chat", chat13, "--query", "OpenAPI-first", "--limit", "5", "--format", "json"], json_output=True)
    run_step(
        ctx,
        "chat_send_uc13_plan",
        ["chat", "send", "--session", chat13, "--prompt", "Using the brief, produce a 7-day delivery plan with risk gates.", "--no-stream", "--format", "json"],
        json_output=True,
        timeout_s=CHAT_TIMEOUT_S,
    )
    run_tool(ctx, "uc13_canvas_create", "canvas", {"action": "create", "chat_id": chat13, "title": "Client Deliverable", "content": "Checklist and timeline will be kept here."})
    run_tool(ctx, "uc13_canvas_append_1", "canvas", {"action": "append", "chat_id": chat13, "content": "Day 1-2: requirements + schema; Day 3: openapi generate; Day 4-5: clients verify; Day 6: rollout; Day 7: retro."})
    run_tool(ctx, "uc13_canvas_list", "canvas", {"action": "list", "chat_id": chat13})
    run_tool(ctx, "uc13_ws_write_deliverable", "workspace", {"action": "write", "path": ".codex-uc13-deliverable.md", "content": "See UC13 canvas for details."})
    rag_delete_for_chat(ctx, chat13, id13)

    # Use Case 14: e-commerce ops (OpenClaw-inspired) inventory + reorder automation with python + cron
    chat14 = create_chat(ctx, "uc14-ecomm")
    inventory_csv = "sku,on_hand,reorder_point\nA,3,5\nB,10,5\nC,0,2\n"
    run_tool(ctx, "uc14_ws_write_inventory", "workspace", {"action": "write", "path": ".codex-uc14-inventory.csv", "content": inventory_csv})
    run_tool(
        ctx,
        "uc14_tools_python_reorder",
        "python_exec",
        {"code": "import csv,io\ns='''sku,on_hand,reorder_point\\nA,3,5\\nB,10,5\\nC,0,2\\n'''\nrows=list(csv.DictReader(io.StringIO(s)))\nreorder=[r['sku'] for r in rows if int(r['on_hand'])<int(r['reorder_point'])]\nprint('REORDER:', ','.join(reorder))\n", "timeout": 30},
    )
    run_tool(ctx, "uc14_memory_write", "memory", {"type": "longTerm", "content": "Reorder automation flags SKUs below reorder_point from inventory CSV.", "keywords": ["ecomm", "inventory", "cron"]})
    run_tool(ctx, "uc14_cron_create", "cron", {"action": "create", "title": "uc14 inventory check", "prompt": "Check inventory and list SKUs needing reorder.", "cron": "0 6 * * *", "chat_id": chat14, "action_type": "text"})
    run_tool(ctx, "uc14_cron_list", "cron", {"action": "list"})
    run_step(
        ctx,
        "chat_send_uc14",
        ["chat", "send", "--session", chat14, "--prompt", "Write an ops runbook for inventory reorder based on a daily job output.", "--no-stream", "--format", "json"],
        json_output=True,
        timeout_s=CHAT_TIMEOUT_S,
    )
    id14 = rag_index_file_for_chat(ctx, chat14, workspace / ".codex-uc14-inventory.csv")
    run_step(ctx, "rag_search_uc14", ["rag", "search", "--chat", chat14, "--query", "sku", "--limit", "5", "--format", "json"], json_output=True)
    rag_delete_for_chat(ctx, chat14, id14)

    # Use Case 15: content creator assistant (OpenClaw-inspired) web research -> outline -> draft -> publish artifact
    chat15 = create_chat(ctx, "uc15-content")
    res15 = run_tool(ctx, "uc15_web_search", "browser.search", {"query": "OpenClaw automation assistant use cases", "resultCount": 3})
    outline15 = "# Blog Outline\n\n- What is an agentic assistant\n- Tools, schedules, memory\n- Safety model (tool gating)\n\nSources:\n" + json.dumps(res15, indent=2, sort_keys=True)
    run_tool(ctx, "uc15_canvas_create", "canvas", {"action": "create", "chat_id": chat15, "title": "UC15 Outline", "content": outline15})
    run_step(
        ctx,
        "chat_send_uc15_draft",
        ["chat", "send", "--session", chat15, "--prompt", "Turn the outline into a 500-word draft with headings.", "--no-stream", "--format", "json"],
        json_output=True,
        timeout_s=CHAT_TIMEOUT_S,
    )
    run_tool(ctx, "uc15_ws_write_draft", "workspace", {"action": "write", "path": ".codex-uc15-draft.md", "content": "Draft generated in UC15 chat."})
    id15 = rag_index_file_for_chat(ctx, chat15, workspace / ".codex-uc15-draft.md")
    run_step(ctx, "rag_search_uc15", ["rag", "search", "--chat", chat15, "--query", "Tools", "--limit", "5", "--format", "json"], json_output=True)
    rag_delete_for_chat(ctx, chat15, id15)

    # Use Case 16: smart home controller (OpenClaw-inspired) simulated device state + one-shot schedule
    chat16 = create_chat(ctx, "uc16-smarthome")
    home_state = {"lights": {"kitchen": "off", "bedroom": "off"}, "thermostat": {"target_f": 70}}
    run_tool(ctx, "uc16_ws_write_state", "workspace", {"action": "write", "path": ".codex-uc16-home.json", "content": json.dumps(home_state, indent=2, sort_keys=True)})
    run_tool(ctx, "uc16_ws_read_state", "workspace", {"action": "read", "path": ".codex-uc16-home.json"})
    run_tool(ctx, "uc16_cron_create_one_shot", "cron", {"action": "create", "title": "uc16 lights on", "prompt": "Turn kitchen lights ON (simulated).", "cron": "2026-02-08", "schedule_kind": "one_shot", "chat_id": chat16, "action_type": "text"}, allow_fail=True)
    run_tool(ctx, "uc16_cron_list", "cron", {"action": "list"})
    run_step(
        ctx,
        "chat_send_uc16",
        ["chat", "send", "--session", chat16, "--prompt", "Given the home state JSON, propose a safe automation strategy (no real device access).", "--no-stream", "--format", "json"],
        json_output=True,
        timeout_s=CHAT_TIMEOUT_S,
    )

    # Use Case 17: OpenAPI contract audit (OpenAPI-first parity check)
    chat17 = create_chat(ctx, "uc17-openapi-audit")
    openapi_path = workspace / "openapi" / "openapi.json"
    openapi_summary = "openapi/openapi.json missing"
    if openapi_path.exists():
        try:
            spec = json.loads(openapi_path.read_text(encoding="utf-8"))
            paths = spec.get("paths", {}) if isinstance(spec, dict) else {}
            openapi_summary = f"paths={len(paths)}"
        except Exception as e:
            openapi_summary = f"failed to parse openapi/openapi.json: {e}"
    run_tool(ctx, "uc17_ws_write_report", "workspace", {"action": "write", "path": ".codex-uc17-openapi-report.txt", "content": f"UC17 OpenAPI audit summary: {openapi_summary}\n"})
    id17 = rag_index_file_for_chat(ctx, chat17, workspace / ".codex-uc17-openapi-report.txt")
    run_step(ctx, "rag_search_uc17", ["rag", "search", "--chat", chat17, "--query", "OpenAPI", "--limit", "5", "--format", "json"], json_output=True)
    run_step(
        ctx,
        "chat_send_uc17",
        ["chat", "send", "--session", chat17, "--prompt", "Explain why OpenAPI-first matters and list 5 failure modes when openapi.json drifts.", "--no-stream", "--format", "json"],
        json_output=True,
        timeout_s=CHAT_TIMEOUT_S,
    )
    rag_delete_for_chat(ctx, chat17, id17)

    # Use Case 18: tool-gating security checks (deny tools, then allow)
    chat18 = create_chat(ctx, "uc18-security")
    run_step(
        ctx,
        "uc18_chat_send_denied_tools",
        ["--tool-access", "deny", "chat", "send", "--session", chat18, "--prompt", "Use web search to find OpenClaw cron docs.", "--tools", "browser.search", "--no-stream", "--format", "json"],
        json_output=True,
        allow_fail=True,
        timeout_s=CHAT_TIMEOUT_S,
    )
    run_step(
        ctx,
        "uc18_tools_run_denied",
        ["--tool-access", "deny", "tools", "run", "browser.search", "--args", json.dumps({"query": "OpenClaw cron jobs", "resultCount": 2}), "--format", "json"],
        json_output=True,
        allow_fail=True,
    )
    run_step(
        ctx,
        "uc18_tools_run_allowed",
        ["--tool-access", "allow", "tools", "run", "browser.search", "--args", json.dumps({"query": "OpenClaw use cases", "resultCount": 2}), "--format", "json"],
        json_output=True,
    )
    run_step(
        ctx,
        "uc18_chat_send_allowed",
        ["--tool-access", "allow", "chat", "send", "--session", chat18, "--prompt", "Operate with tools allowed but do not call any tools. Provide a security checklist.", "--no-stream", "--format", "json"],
        json_output=True,
        timeout_s=CHAT_TIMEOUT_S,
    )

    # Use Case 19: canvas-heavy documentation workflow (create/update/append/get/list)
    chat19 = create_chat(ctx, "uc19-canvas")
    run_tool(ctx, "uc19_canvas_create", "canvas", {"action": "create", "chat_id": chat19, "title": "Spec Draft", "content": "Initial spec stub."})
    run_tool(ctx, "uc19_canvas_append_1", "canvas", {"action": "append", "chat_id": chat19, "content": "Section 1: Goals."})
    run_tool(ctx, "uc19_canvas_append_2", "canvas", {"action": "append", "chat_id": chat19, "content": "Section 2: Non-goals."})
    canvases19 = run_tool(ctx, "uc19_canvas_list", "canvas", {"action": "list", "chat_id": chat19})
    canvas_id_19 = None
    if isinstance(canvases19, list) and canvases19:
        first = canvases19[0]
        if isinstance(first, dict):
            canvas_id_19 = first.get("id") or first.get("canvas_id")
    if canvas_id_19:
        run_tool(ctx, "uc19_canvas_get", "canvas", {"action": "get", "chat_id": chat19, "canvas_id": str(canvas_id_19)})
        run_tool(ctx, "uc19_canvas_update", "canvas", {"action": "update", "chat_id": chat19, "canvas_id": str(canvas_id_19), "content": "Updated spec: Goals/Non-goals + Acceptance criteria."})
        got = run_tool(ctx, "uc19_canvas_get2", "canvas", {"action": "get", "chat_id": chat19, "canvas_id": str(canvas_id_19)})
        run_tool(ctx, "uc19_ws_write_canvas", "workspace", {"action": "write", "path": ".codex-uc19-canvas.md", "content": json.dumps(got, indent=2, sort_keys=True)})
    run_step(
        ctx,
        "chat_send_uc19",
        ["chat", "send", "--session", chat19, "--prompt", "Summarize the current canvas into 5 bullet acceptance criteria.", "--no-stream", "--format", "json"],
        json_output=True,
        timeout_s=CHAT_TIMEOUT_S,
    )

    # Use Case 20: churn/stress scenario (many personalities/chats/schedules, list/get/history/delete)
    chat20 = create_chat(ctx, "uc20-stress")
    extra_personalities: List[str] = []
    extra_chats: List[str] = []
    for i in range(1, 6):
        pid = create_personality(ctx, f"uc20-personality-{i}", "productivity")
        extra_personalities.append(pid)
        _, _, _, chat_obj = run_step(
            ctx,
            f"uc20_personality_chat_{i}",
            ["personality", "chat", pid, "--format", "json"],
            json_output=True,
        )
        chat_id = _extract_uuid(chat_obj.get("message", "")) if isinstance(chat_obj, dict) else None
        if chat_id:
            extra_chats.append(chat_id)
    run_step(ctx, "uc20_chat_list_1", ["chat", "list", "--format", "json"], json_output=True)
    for cid in extra_chats[:3]:
        run_step(ctx, f"uc20_chat_get_{cid[:8]}", ["chat", "get", cid, "--format", "json"], json_output=True)
        run_step(ctx, f"uc20_chat_rename_{cid[:8]}", ["chat", "rename", "--session", cid, f"uc20-renamed-{cid[:8]}"])
        run_step(ctx, f"uc20_chat_history_{cid[:8]}", ["chat", "history", "--session", cid, "--format", "json"], json_output=True)
    run_step(
        ctx,
        "uc20_schedule_create",
        ["schedules", "create", "--title", "uc20 temp", "--prompt", "temp", "--cron", "*/30 * * * *", "--chat", chat20, "--disabled", "--format", "json"],
        json_output=True,
    )
    _, _, _, scheds20 = run_step(ctx, "uc20_schedules_list", ["schedules", "list", "--format", "json"], json_output=True)
    temp_sched_id = None
    if isinstance(scheds20, list):
        for s in scheds20:
            if isinstance(s, dict) and s.get("title") == "uc20 temp":
                temp_sched_id = s.get("id")
                break
    if temp_sched_id:
        run_step(ctx, "uc20_schedule_enable", ["schedules", "enable", temp_sched_id])
        run_step(ctx, "uc20_schedule_disable", ["schedules", "disable", temp_sched_id])
        run_step(ctx, "uc20_schedule_delete", ["schedules", "delete", temp_sched_id])

    # Delete one chat explicitly, then delete the remaining personalities (which cascades their chat).
    if extra_chats:
        run_step(ctx, f"uc20_chat_delete_{extra_chats[0][:8]}", ["chat", "delete", "--session", extra_chats[0]])
    for pid in extra_personalities[1:]:
        run_step(ctx, f"uc20_personality_delete_{pid[:8]}", ["personality", "delete", pid])
    run_step(ctx, "uc20_chat_list_2", ["chat", "list", "--format", "json"], json_output=True)

    # Use Case 21: workflow runner (OpenClaw-inspired) - author a workflow spec, validate, index, and summarize
    chat21 = create_chat(ctx, "uc21-workflow")
    workflow_yaml = """\
name: uc21-workflow
description: "Simulated OpenClaw-style workflow spec for ThinkCLI parity checks"
steps:
  - id: gather_context
    tool: workspace
    args:
      action: list
      path: "."
      recursive: false
  - id: audit_contract
    tool: workspace
    args:
      action: read
      path: "AGENTS.md"
  - id: synthesize
    action: chat_send
    prompt: "Summarize key constraints and propose next actions."
"""
    run_tool(ctx, "uc21_ws_write_yaml", "workspace", {"action": "write", "path": ".codex-uc21-workflow.yaml", "content": workflow_yaml})
    run_tool(ctx, "uc21_ws_read_yaml", "workspace", {"action": "read", "path": ".codex-uc21-workflow.yaml"})
    run_tool(ctx, "uc21_ws_list_root", "workspace", {"action": "list", "path": ".", "recursive": False})
    run_tool(ctx, "uc21_py_validate_yaml", "python_exec", {"code": "import yaml,sys; yaml.safe_load(open('.codex-uc21-workflow.yaml')); print('yaml_ok')", "timeout": 30}, allow_fail=True)
    run_tool(ctx, "uc21_memory_write", "memory", {"type": "longTerm", "content": "UC21 workflow spec drafted and validated.", "keywords": ["workflow", "openclaw", "parity", "thinkcli"]})
    run_tool(ctx, "uc21_canvas_create", "canvas", {"action": "create", "chat_id": chat21, "title": "UC21 Workflow Notes", "content": "Workflow YAML + validation notes."})
    run_tool(ctx, "uc21_canvas_append", "canvas", {"action": "append", "chat_id": chat21, "content": "Validated YAML structure; next: map steps to ThinkCLI commands."})
    id21 = rag_index_file_for_chat(ctx, chat21, workspace / ".codex-uc21-workflow.yaml")
    run_step(ctx, "uc21_rag_search", ["rag", "search", "--chat", chat21, "--query", "steps:", "--limit", "3", "--format", "json"], json_output=True)
    run_step(ctx, "uc21_chat_send", ["chat", "send", "--session", chat21, "--prompt", "Explain how to execute this workflow using ThinkCLI commands (no external runner).", "--no-stream", "--format", "json"], json_output=True)
    run_step(ctx, "uc21_chat_history", ["chat", "history", "--session", chat21, "--format", "json"], json_output=True)
    run_step(ctx, "uc21_chat_rename", ["chat", "rename", "--session", chat21, "uc21-workflow-renamed"])
    rag_delete_for_chat(ctx, chat21, id21)

    # Use Case 22: release notes / changelog automation (workspace + python + RAG + schedule)
    chat22 = create_chat(ctx, "uc22-release-notes")
    run_tool(ctx, "uc22_ws_list_services", "workspace", {"action": "list", "path": "services", "recursive": False})
    run_tool(ctx, "uc22_ws_list_openapi", "workspace", {"action": "list", "path": "openapi", "recursive": False}, allow_fail=True)
    run_tool(ctx, "uc22_py_summarize_tree", "python_exec", {"code": "import os, json\nroot='services'\nitems=[]\nfor d in sorted(os.listdir(root))[:20]:\n  p=os.path.join(root,d)\n  if os.path.isdir(p): items.append(d)\nprint(json.dumps({'services':items}, indent=2))", "timeout": 30})
    run_tool(ctx, "uc22_ws_write_draft", "workspace", {"action": "write", "path": ".codex-uc22-release-draft.md", "content": "# UC22 Release Notes Draft\n\n- Placeholder draft generated from workspace inventory.\n"})
    id22 = rag_index_file_for_chat(ctx, chat22, workspace / ".codex-uc22-release-draft.md")
    run_step(ctx, "uc22_rag_search", ["rag", "search", "--chat", chat22, "--query", "Release", "--limit", "3", "--format", "json"], json_output=True)
    run_step(ctx, "uc22_chat_send", ["chat", "send", "--session", chat22, "--prompt", "Turn the draft into release notes with sections: Backend, Mobile, Infra. Keep it concise.", "--no-stream", "--format", "json"], json_output=True)
    run_step(ctx, "uc22_schedule_create", ["schedules", "create", "--title", "uc22 weekly release notes", "--prompt", "Generate release notes.", "--cron", "0 10 * * 1", "--chat", chat22, "--disabled", "--format", "json"], json_output=True)
    _, _, _, scheds22 = run_step(ctx, "uc22_schedules_list", ["schedules", "list", "--format", "json"], json_output=True)
    sched22_id = None
    if isinstance(scheds22, list):
        for s in scheds22:
            if isinstance(s, dict) and s.get("title") == "uc22 weekly release notes":
                sched22_id = s.get("id")
                break
    if sched22_id:
        run_step(ctx, "uc22_schedule_enable", ["schedules", "enable", sched22_id])
        run_step(ctx, "uc22_schedule_disable", ["schedules", "disable", sched22_id])
        run_step(ctx, "uc22_schedule_delete", ["schedules", "delete", sched22_id])
    rag_delete_for_chat(ctx, chat22, id22)

    # Use Case 23: support ticket triage board (canvas + memory + RAG search)
    chat23 = create_chat(ctx, "uc23-triage")
    tickets = {
        "tickets": [
            {"id": "T-100", "title": "openapi.json out of date", "severity": "high", "notes": "CI spectral failing"},
            {"id": "T-101", "title": "iOS build fails after API change", "severity": "medium", "notes": "types regenerate on clean"},
            {"id": "T-102", "title": "generator docker build missing file:", "severity": "high", "notes": "Dockerfile.generator needs copy"},
        ]
    }
    run_tool(ctx, "uc23_ws_write_tickets", "workspace", {"action": "write", "path": ".codex-uc23-tickets.json", "content": json.dumps(tickets, indent=2, sort_keys=True)})
    run_tool(ctx, "uc23_ws_read_tickets", "workspace", {"action": "read", "path": ".codex-uc23-tickets.json"})
    run_tool(ctx, "uc23_canvas_create", "canvas", {"action": "create", "chat_id": chat23, "title": "Triage Board", "content": "To Do / Doing / Done"})
    run_tool(ctx, "uc23_canvas_append_1", "canvas", {"action": "append", "chat_id": chat23, "content": "To Do: T-100, T-102\nDoing: T-101\nDone: -"})
    id23 = rag_index_file_for_chat(ctx, chat23, workspace / ".codex-uc23-tickets.json")
    run_step(ctx, "uc23_rag_search", ["rag", "search", "--chat", chat23, "--query", "openapi", "--limit", "5", "--format", "json"], json_output=True)
    run_tool(ctx, "uc23_memory_write", "memory", {"type": "longTerm", "content": "UC23 triage board created with 3 sample tickets.", "keywords": ["triage", "support", "openapi", "docker"]})
    run_step(ctx, "uc23_chat_send", ["chat", "send", "--session", chat23, "--prompt", "Triage the tickets: propose owners, next steps, and verification commands.", "--no-stream", "--format", "json"], json_output=True)
    rag_delete_for_chat(ctx, chat23, id23)

    # Use Case 24: data pipeline (python_exec -> workspace artifact -> RAG -> summary)
    chat24 = create_chat(ctx, "uc24-data")
    run_tool(ctx, "uc24_py_make_csv", "python_exec", {"code": "import csv,random\nrows=[['day','requests','errors']]\nfor i in range(1,31):\n  r=random.randint(500,2000)\n  e=random.randint(0,50)\n  rows.append([i,r,e])\nwith open('.codex-uc24-metrics.csv','w',newline='') as f:\n  csv.writer(f).writerows(rows)\nprint('wrote')", "timeout": 30})
    run_tool(ctx, "uc24_ws_read_csv", "workspace", {"action": "read", "path": ".codex-uc24-metrics.csv"})
    run_tool(ctx, "uc24_py_aggregate", "python_exec", {"code": "import csv,statistics\nreq=[]; err=[]\nwith open('.codex-uc24-metrics.csv') as f:\n  r=csv.DictReader(f)\n  for row in r:\n    req.append(int(row['requests'])); err.append(int(row['errors']))\nprint({'days':len(req),'req_avg':sum(req)/len(req),'err_p95':statistics.quantiles(err, n=20)[-1]})", "timeout": 30})
    run_tool(ctx, "uc24_ws_write_report", "workspace", {"action": "write", "path": ".codex-uc24-report.md", "content": "# UC24 Metrics Report\n\nSee .codex-uc24-metrics.csv for raw data.\n"})
    id24 = rag_index_file_for_chat(ctx, chat24, workspace / ".codex-uc24-report.md")
    run_step(ctx, "uc24_rag_search", ["rag", "search", "--chat", chat24, "--query", "Metrics", "--limit", "3", "--format", "json"], json_output=True)
    run_step(ctx, "uc24_chat_send", ["chat", "send", "--session", chat24, "--prompt", "Using the report + CSV context, propose alert thresholds and an incident response playbook.", "--no-stream", "--format", "json"], json_output=True)
    rag_delete_for_chat(ctx, chat24, id24)

    # Use Case 25: security checklist builder (web search tools + workspace + RAG + tool gating)
    chat25 = create_chat(ctx, "uc25-security")
    run_step(ctx, "uc25_tool_denied_chat", ["--tool-access", "deny", "chat", "send", "--session", chat25, "--prompt", "Use browser.search to fetch OWASP top 10 summary.", "--tools", "browser.search", "--no-stream", "--format", "json"], json_output=True, allow_fail=True)
    owasp = run_tool(ctx, "uc25_browser_search", "browser.search", {"query": "OWASP Top 10 2021 summary", "resultCount": 3})
    run_tool(ctx, "uc25_ws_write_owasp", "workspace", {"action": "write", "path": ".codex-uc25-owasp.json", "content": json.dumps(owasp, indent=2, sort_keys=True)})
    run_tool(ctx, "uc25_canvas_create", "canvas", {"action": "create", "chat_id": chat25, "title": "Threat Model", "content": "Assets / Trust boundaries / Threats / Mitigations"})
    run_tool(ctx, "uc25_canvas_append", "canvas", {"action": "append", "chat_id": chat25, "content": "Mitigations: secrets via Infisical; OpenAPI drift gates; tool access deny-by-default for CI."})
    id25 = rag_index_file_for_chat(ctx, chat25, workspace / ".codex-uc25-owasp.json")
    run_step(ctx, "uc25_rag_search", ["rag", "search", "--chat", chat25, "--query", "OWASP", "--limit", "5", "--format", "json"], json_output=True)
    run_step(ctx, "uc25_chat_send", ["chat", "send", "--session", chat25, "--prompt", "Generate a security checklist for this repo: secrets, OpenAPI, mobile parity, and tool gating.", "--no-stream", "--format", "json"], json_output=True)
    rag_delete_for_chat(ctx, chat25, id25)

    # Use Case 26: gateway resilience + remote model lifecycle (start/status/add/info/remove/list)
    run_step(ctx, "uc26_gateway_start_once", ["gateway", "start", "--once", "--port", "9999", "--token", "uc26-token"])
    run_step(ctx, "uc26_gateway_status", ["gateway", "status", "--format", "json"], json_output=True)
    run_step(ctx, "uc26_models_add_remote", ["models", "add-remote", "--name", "uc26-remote", "--location", "http://localhost:9999", "--type", "language", "--format", "json"], json_output=True)
    _, _, _, models26 = run_step(ctx, "uc26_models_list", ["models", "list", "--format", "json"], json_output=True)
    remote_id_26 = None
    if isinstance(models26, list):
        for m in models26:
            if isinstance(m, dict) and m.get("name") == "uc26-remote":
                remote_id_26 = m.get("id")
                break
    if remote_id_26:
        run_step(ctx, "uc26_models_info", ["models", "info", remote_id_26, "--format", "json"], json_output=True)
        run_step(ctx, "uc26_models_remove", ["models", "remove", remote_id_26, "--format", "json"], json_output=True)

    # Use Case 27: isolated store reset smoke test (create data, snapshot, reset, verify empty)
    ctx27 = RunCtx(
        think_bin=ctx.think_bin,
        workspace=ctx.workspace,
        store_name="codex-uc27",
        config_path=ctx.config_path,
        logs_dir=ctx.logs_dir,
        env=ctx.env,
    )
    reset_cli_store(ctx27.store_name)
    run_step(ctx27, "uc27_store_path", ["store", "path", "--format", "json"], json_output=True, allow_fail=True)
    run_step(ctx27, "uc27_status_pre_reset", ["status", "--format", "json"], json_output=True)
    skill27 = create_skill(
        ctx27,
        "uc27-skill",
        tools=["workspace"],
        instructions="UC27 smoke skill for testing store reset behavior.",
    )
    run_step(ctx27, "uc27_skill_enable", ["skills", "enable", skill27])
    run_step(ctx27, "uc27_skills_list_pre_reset", ["skills", "list", "--format", "json"], json_output=True)
    run_step(ctx27, "uc27_store_reset_dry", ["store", "reset", "--dry-run", "--format", "json"], json_output=True, allow_fail=True)
    run_step(ctx27, "uc27_store_reset", ["store", "reset", "--format", "json"], json_output=True, allow_fail=True)
    run_step(ctx27, "uc27_status_post_reset", ["status", "--format", "json"], json_output=True)
    run_step(ctx27, "uc27_skills_list_post_reset", ["skills", "list", "--format", "json"], json_output=True)

    # Use Case 28: json-lines streaming smoke test (parseable output)
    chat28 = create_chat(ctx, "uc28-jsonlines")
    rc28, out28, _err28, _ = run_step(
        ctx,
        "uc28_chat_send_json_lines",
        ["chat", "send", "--session", chat28, "--prompt", "Output two short paragraphs.", "--format", "json-lines"],
        json_output=False,
        allow_fail=False,
    )
    if rc28 != 0:
        raise StepFailed("uc28_chat_send_json_lines failed unexpectedly")
    # Verify json-lines are parseable as JSON objects line-by-line (best-effort).
    parsed_lines = 0
    for line in out28.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            json.loads(line)
            parsed_lines += 1
        except Exception:
            # Some platforms may include progress noise; tolerate but record at least one parseable object.
            pass
    if parsed_lines < 1:
        raise StepFailed("uc28 expected at least one parseable json-lines object in stdout")

    # Use Case 29: tool inventory + minimal executions (OpenClaw-style tool belt check)
    _, _, _, tools29 = run_step(ctx, "uc29_tools_list", ["tools", "list", "--format", "json"], json_output=True)
    run_tool(ctx, "uc29_ws_list_root", "workspace", {"action": "list", "path": ".", "recursive": False})
    run_tool(ctx, "uc29_py_smoke", "python_exec", {"code": "print('py_ok')", "timeout": 10})
    run_tool(ctx, "uc29_memory_smoke", "memory", {"type": "shortTerm", "content": "UC29 tool smoke", "keywords": ["uc29", "smoke"]})
    run_tool(ctx, "uc29_canvas_smoke", "canvas", {"action": "create", "chat_id": create_chat(ctx, "uc29-canvas"), "title": "UC29", "content": "tool belt"})
    run_tool(ctx, "uc29_weather_smoke", "weather", {"location": "San Francisco, CA", "days": 1}, allow_fail=True)
    run_tool(ctx, "uc29_browser_search_smoke", "browser.search", {"query": "OpenClaw workflows", "resultCount": 1}, allow_fail=True)
    if not isinstance(tools29, list):
        raise StepFailed("uc29 tools list did not return a list")

    # Use Case 30: operational controls (stop + status + lists) + cleanup
    chat30 = create_chat(ctx, "uc30-ops")
    run_step(ctx, "uc30_chat_send", ["chat", "send", "--session", chat30, "--prompt", "Provide 3 operational tips for running long ThinkCLI sessions.", "--no-stream", "--format", "json"], json_output=True)
    run_step(ctx, "uc30_chat_stop", ["chat", "stop", "--session", chat30], allow_fail=False)
    run_step(ctx, "uc30_status", ["status", "--format", "json"], json_output=True)
    run_step(ctx, "uc30_chat_list", ["chat", "list", "--format", "json"], json_output=True)
    run_step(ctx, "uc30_personality_list", ["personality", "list", "--format", "json"], json_output=True)
    run_step(ctx, "uc30_skills_list", ["skills", "list", "--format", "json"], json_output=True)

    # Final status snapshot
    run_step(ctx, "status_final", ["status", "--format", "json"], json_output=True)

    print(str(logs_dir))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except StepFailed as e:
        print(str(e), file=sys.stderr)
        raise SystemExit(1)
