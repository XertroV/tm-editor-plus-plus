#!/usr/bin/env python3
"""Print the tail of Openplanet.log and the newest Trackmania crash logs.

Defaults:
  Openplanet.log  ~/OpenplanetNext/Openplanet.log
  TM docs         ~/tm-docs  (Proton Documents/Trackmania)

Usage:
  tools/tm_logs.py
  tools/tm_logs.py --lines 100 --crashes 5
"""

from __future__ import annotations

import argparse
import os
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


DEFAULT_OP_LOG = Path.home() / "OpenplanetNext" / "Openplanet.log"
DEFAULT_TM_DOCS = Path.home() / "tm-docs"
ROOT_CRASH_GLOBS = ("LogCrash_*.txt", "Crash_*.txt")


@dataclass(frozen=True)
class FileInfo:
    path: Path
    mtime: float
    size: int

    @property
    def name(self) -> str:
        return self.path.name


def tail_lines(path: Path, n: int) -> list[str] | None:
    if n < 0:
        raise ValueError("n must be >= 0")
    if not path.is_file():
        return None
    text = path.read_text(errors="replace")
    lines = text.splitlines()
    if n == 0:
        return []
    return lines[-n:]


def newest_files(folder: Path, n: int, patterns: tuple[str, ...] | None = None) -> list[FileInfo]:
    if n <= 0 or not folder.is_dir():
        return []
    found: list[Path] = []
    if patterns:
        for pat in patterns:
            found.extend(folder.glob(pat))
    else:
        found.extend(p for p in folder.iterdir() if p.is_file())
    infos = [
        FileInfo(path=p, mtime=p.stat().st_mtime, size=p.stat().st_size)
        for p in found
        if p.is_file()
    ]
    infos.sort(key=lambda item: item.mtime, reverse=True)
    return infos[:n]


def _fmt_time(ts: float) -> str:
    return datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")


def _fmt_file_row(info: FileInfo) -> str:
    return f"  {_fmt_time(info.mtime)}  {info.size:>8}  {info.path}"


def format_report(
    op_log: Path,
    tm_docs: Path,
    lines: int = 80,
    crashes: int = 5,
) -> str:
    out: list[str] = []
    out.append("=== Openplanet.log ===")
    out.append(f"path: {op_log}")
    if op_log.is_file():
        st = op_log.stat()
        out.append(f"mtime: {_fmt_time(st.st_mtime)}  size: {st.st_size}")
        tail = tail_lines(op_log, lines) or []
        out.append(f"--- last {len(tail)} / requested {lines} lines ---")
        out.extend(tail)
    else:
        out.append("MISSING")

    crash_dir = tm_docs / "LogCrash"
    out.append("")
    out.append("=== LogCrash ===")
    out.append(f"tm-docs: {tm_docs}")
    if crash_dir.is_dir():
        out.append(f"LogCrash dir: EXISTS  {crash_dir}")
        newest = newest_files(crash_dir, crashes)
        if newest:
            out.append(f"newest {len(newest)}:")
            out.extend(_fmt_file_row(info) for info in newest)
        else:
            out.append("dir is empty")
    else:
        out.append(f"LogCrash dir: MISSING  {crash_dir}")

    root = newest_files(tm_docs, crashes, ROOT_CRASH_GLOBS) if tm_docs.is_dir() else []
    out.append("")
    out.append("=== tm-docs root crash files ===")
    if root:
        out.append(f"newest {len(root)} LogCrash_*.txt / Crash_*.txt:")
        out.extend(_fmt_file_row(info) for info in root)
    else:
        out.append("none")
    return "\n".join(out) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Tail Openplanet.log and list the newest Trackmania LogCrash files."
    )
    parser.add_argument(
        "--log",
        type=Path,
        default=Path(os.environ.get("OP_LOG", DEFAULT_OP_LOG)),
        help=f"Openplanet.log path (default: {DEFAULT_OP_LOG})",
    )
    parser.add_argument(
        "--tm-docs",
        type=Path,
        default=Path(os.environ.get("TM_DOCS", DEFAULT_TM_DOCS)),
        help=f"Proton Documents/Trackmania path (default: {DEFAULT_TM_DOCS})",
    )
    parser.add_argument(
        "--lines",
        "-n",
        type=int,
        default=80,
        help="How many Openplanet.log lines to print (default: 80).",
    )
    parser.add_argument(
        "--crashes",
        type=int,
        default=5,
        help="How many newest crash files to list (default: 5).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    print(
        format_report(
            args.log.expanduser(),
            args.tm_docs.expanduser(),
            lines=args.lines,
            crashes=args.crashes,
        ),
        end="",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
