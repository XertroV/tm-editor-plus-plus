#!/usr/bin/env python3
"""Autonomous LM bake loop: hide@100 / progress100 / crash recovery.

Later (not this session): long soak N_ITERS>=12, random Fast/Default/High + TOD.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

CALL = Path("/home/xertrov/src/openplanet/my-plugins/tm-control-mcp/tools/call.py")
OPLOG = Path(
    "/home/xertrov/.local/share/Steam/steamapps/compatdata/2225070/"
    "pfx/drive_c/users/steamuser/OpenplanetNext/Openplanet.log"
)
CRASH_GLOBS = [
    Path.home() / "tm-docs",
    Path.home() / "tm-docs" / "LogCrash",
]
MAP_PATH = "Campaign-Summer2026-02.Map.Gbx"
LAUNCH = "tm-launch-direct"
TODS = [0.10, 0.33, 0.55, 0.77, 0.95]
QUALITIES = ("Fast", "Default", "High")
N_ITERS = 12
POLL_S = 8
BAKE_MAX_S = 600
RECOVER_MAX_S = 240
SHOT_DIR = Path("/home/xertrov/src/openplanet/my-plugins/tm-editor-plus-plus/research/lm-preview-shots")
SHOT_MILESTONES = (0.05, 0.25, 0.50, 0.75, 0.90)


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def newest_crash() -> tuple[float, str]:
    newest = (0.0, "")
    for folder in CRASH_GLOBS:
        if not folder.is_dir():
            continue
        for p in folder.iterdir():
            name = p.name
            if not (name.startswith("LogCrash") or name.startswith("Crash_")):
                continue
            if not name.endswith(".txt"):
                continue
            try:
                m = p.stat().st_mtime
            except OSError:
                continue
            if m > newest[0]:
                newest = (m, str(p))
    return newest


def call(tool: str, payload: dict | None = None, timeout: int = 40) -> dict:
    cmd = ["python3", str(CALL), "--timeout", str(timeout), tool, json.dumps(payload or {})]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 10)
    except subprocess.TimeoutExpired:
        return {"_transport": "timeout", "ok": False}
    raw = (proc.stdout or "").strip()
    # call.py may prefix a human line before JSON
    js = raw
    if "\n{" in raw:
        js = raw[raw.index("\n{") + 1 :]
    elif not raw.startswith("{") and "{" in raw:
        js = raw[raw.index("{") :]
    try:
        data = json.loads(js)
    except json.JSONDecodeError:
        err = (proc.stderr or raw or "")[-400:]
        return {"_transport": "bad_json", "ok": False, "stderr": err, "rc": proc.returncode}
    return data


def tool_ok(resp: dict) -> bool:
    if not resp or resp.get("_transport"):
        return False
    result = ((resp.get("data") or {}).get("result") or {})
    return bool(result.get("success"))


def tool_out(resp: dict) -> dict:
    return ((resp.get("data") or {}).get("result") or {}).get("output") or {}


def game_missing(resp: dict) -> bool:
    if resp.get("_transport") in ("timeout", "bad_json"):
        text = (resp.get("stderr") or "") + json.dumps(resp)
        return "Trackmania" in text or "no game" in text.lower() or "refused" in text.lower()
    err = str(resp.get("error") or "") + str(((resp.get("data") or {}).get("result") or {}).get("error") or "")
    code = str(((resp.get("data") or {}).get("result") or {}).get("code") or "")
    blob = (err + " " + code).lower()
    return any(s in blob for s in ("no_game", "missing game", "refused", "not running", "connection refused"))


def lm_state() -> tuple[str, dict]:
    r = call("GetLightmapComputeState")
    if game_missing(r):
        return "crash", r
    if not tool_ok(r):
        # GetReadiness as fallback
        g = call("GetReadiness")
        if game_missing(g):
            return "crash", g
        return "err", r
    return "ok", tool_out(r)


def take_lm_shot(iter_n: int, p: float) -> None:
    SHOT_DIR.mkdir(parents=True, exist_ok=True)
    r = call(
        "TakeScreenshot",
        {"hideOverlay": False, "currentView": True, "waitMs": 8000},
        timeout=20,
    )
    out = tool_out(r) if tool_ok(r) else {}
    src = out.get("fullName") or out.get("linuxPath") or ""
    dest = ""
    if src:
        pth = Path(src)
        if not pth.is_file():
            # Proton path: C:\users\steamuser\Documents\Trackmania\ScreenShots\...
            name = pth.name
            cand = Path.home() / (
                ".local/share/Steam/steamapps/compatdata/2225070/pfx/"
                "drive_c/users/steamuser/Documents/Trackmania/ScreenShots"
            ) / name
            if cand.is_file():
                pth = cand
        if pth.is_file():
            dest_path = SHOT_DIR / f"iter{iter_n}_p{int(p * 100):02d}_{pth.name}"
            dest_path.write_bytes(pth.read_bytes())
            dest = str(dest_path)
    log(f"  shot p={p:.2f} ok={tool_ok(r)} dest={dest or src or '?'}")


def wait_bake_done(already: bool = False, iter_n: int = 0) -> str:
    t0 = time.time()
    saw = already
    last_p = -1.0
    next_shot_i = 0
    while time.time() - t0 < BAKE_MAX_S:
        kind, st = lm_state()
        if kind == "crash":
            return "crash"
        if kind != "ok":
            log(f"  lm_state err={st}")
            time.sleep(POLL_S)
            continue
        baking = bool(st.get("calculatingShadows") or st.get("waitLooksLikeLm"))
        p = float(st.get("waitProgress") or 0)
        if baking:
            saw = True
            if abs(p - last_p) >= 0.05:
                log(f"  baking p={p:.3f} text={str(st.get('waitText') or '').strip()!r}")
                last_p = p
            while next_shot_i < len(SHOT_MILESTONES) and p >= SHOT_MILESTONES[next_shot_i]:
                take_lm_shot(iter_n, p)
                next_shot_i += 1
        elif saw:
            log(f"  bake clear after {time.time() - t0:.0f}s")
            return "ok"
        elif time.time() - t0 > 25:
            log("  bake never started")
            return "never_started"
        time.sleep(POLL_S)
    return "timeout"


def recover() -> bool:
    log("RECOVER: tm-launch-direct --wait")
    try:
        subprocess.run([LAUNCH, "--wait"], timeout=RECOVER_MAX_S, check=False)
    except subprocess.TimeoutExpired:
        log("RECOVER: launch timed out")
        return False
    t0 = time.time()
    while time.time() - t0 < RECOVER_MAX_S:
        r = call("GetReadiness", timeout=20)
        if tool_ok(r):
            break
        time.sleep(4)
    else:
        log("RECOVER: MCP never came up")
        return False
    r = call("OpenMapInEditor", {"path": MAP_PATH}, timeout=60)
    log(f"RECOVER: OpenMapInEditor ok={tool_ok(r)}")
    t1 = time.time()
    while time.time() - t1 < 120:
        r = call("GetReadiness")
        if tool_ok(r):
            out = tool_out(r)
            mode = out.get("mode")
            name = ((out.get("map") or {}).get("name") or "")
            if mode == "MapEditor" and "Summer 2026" in name:
                log(f"RECOVER: ready {mode} {name}")
                return True
        time.sleep(4)
    log("RECOVER: map not ready")
    return False


def grep_spike(since_bytes: int) -> dict:
    if not OPLOG.is_file():
        return {"missing": True}
    data = OPLOG.read_bytes()[since_bytes:]
    text = data.decode("utf-8", "replace")
    keys = (
        "hide@99",
        "hide@97",
        "hideUnsafe",
        "hook armed",
        "hook disarmed",
        "progress100",
        "progress=1.00",
        "dialogGone",
        "newBake",
        "autoBind",
        "SetBitmap",
        "EppLm_",
        "bound ",
        "ENTER",
        "LEAVE",
    )
    hits = {k: text.count(k) for k in keys}
    last_lines = [ln for ln in text.splitlines() if "LMPreviewSpike" in ln][-12:]
    return {"hits": hits, "last": last_lines, "bytes": len(data)}


def main() -> int:
    crash0_m, crash0_p = newest_crash()
    log(f"baseline crash {crash0_p or '(none)'} mtime={crash0_m}")
    kind, st = lm_state()
    if kind == "crash":
        if not recover():
            return 2
        kind, st = lm_state()
    already = bool(st.get("calculatingShadows") or st.get("waitLooksLikeLm")) if kind == "ok" else False
    log(f"start already_baking={already} st={st if kind == 'ok' else kind}")

    results = []
    i = 0
    tod_ix = 0
    while i < N_ITERS:
        i += 1
        marker = OPLOG.stat().st_size if OPLOG.is_file() else 0
        tod = TODS[tod_ix % len(TODS)]
        tod_ix += 1
        quality = QUALITIES[(i + int(time.time())) % len(QUALITIES)]
        log(f"=== iter {i}/{N_ITERS} tod={tod} quality={quality} already={already} ===")
        joining = already
        if not joining:
            r = call("SetMoodTimeOfDay", {"timeOfDay01": tod})
            log(f"  SetMoodTimeOfDay ok={tool_ok(r)} out={tool_out(r)}")
            r = call("ComputeShadows", {"quality": quality, "bustCache": True})
            log(f"  ComputeShadows ok={tool_ok(r)} out={tool_out(r)}")
        already = False
        status = wait_bake_done(already=joining, iter_n=i)
        crash_m, crash_p = newest_crash()
        new_crash = crash_m > crash0_m + 0.5
        spike = grep_spike(marker)
        row = {
            "iter": i,
            "tod": tod,
            "status": status,
            "new_crash": new_crash,
            "crash_path": crash_p if new_crash else "",
            "hits": spike.get("hits"),
            "last": spike.get("last"),
        }
        results.append(row)
        log(f"  RESULT {json.dumps({k: row[k] for k in ('iter', 'status', 'new_crash', 'hits')})}")
        for ln in spike.get("last") or []:
            log(f"    {ln[-220:]}")
        if status == "crash" or new_crash:
            log(f"  CRASH file={crash_p}")
            if not recover():
                break
            crash0_m, crash0_p = newest_crash()
            continue
        if status == "never_started":
            log("  retry with next TOD")
            continue
        time.sleep(3)

    out_path = Path("/home/xertrov/src/openplanet/my-plugins/tm-editor-plus-plus/research/lm-bake-loop-last.json")
    out_path.write_text(json.dumps(results, indent=2))
    log(f"wrote {out_path}")
    ok = sum(1 for r in results if r["status"] == "ok" and not r["new_crash"])
    hide99 = sum(1 for r in results if (r.get("hits") or {}).get("hide@99", 0) > 0)
    p100 = sum(1 for r in results if (r.get("hits") or {}).get("progress100", 0) > 0)
    log(f"SUMMARY ok={ok}/{len(results)} hide@99={hide99} progress100={p100}")
    return 0 if ok > 0 and all(not r["new_crash"] for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
