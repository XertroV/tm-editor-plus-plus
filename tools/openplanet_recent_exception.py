#!/usr/bin/env python3
"""Print the newest Openplanet script exception-ish block from a log file.

Defaults to ~/OpenplanetNext/Openplanet.log.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Dict, List, Sequence


DEFAULT_LOG = Path.home() / "OpenplanetNext" / "Openplanet.log"
BLOCK_MARKERS = (
    "last script exception repeated",
    "script exception",
    "[error]",
    "exception:",
    "traceback",
)
FIELD_ALIASES = {
    "engine": 0,
    "runtime": 0,
    "subsystem": 0,
    "level": 1,
    "severity": 1,
    "time": 2,
    "timestamp": 2,
    "source": 3,
    "plugin": 3,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Show the most recent Openplanet script exception block."
    )
    parser.add_argument(
        "--log",
        type=Path,
        default=DEFAULT_LOG,
        help=f"Openplanet.log path (default: {DEFAULT_LOG})",
    )
    parser.add_argument(
        "-c",
        "--context",
        type=int,
        default=6,
        help="Number of surrounding lines to print around each match.",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=1,
        help="Number of matching blocks to print, starting from the newest.",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Print every matching block found when scanning backward.",
    )
    parser.add_argument(
        "--include-repeats",
        action="store_true",
        help="Treat 'Last script exception repeated' notices as matches instead of skipping to the real exception.",
    )
    parser.add_argument(
        "--engine",
        action="append",
        default=[],
        metavar="VALUE",
        help="Case-insensitive match against the first bracket field.",
    )
    parser.add_argument(
        "--level",
        action="append",
        default=[],
        metavar="VALUE",
        help="Case-insensitive match against the second bracket field.",
    )
    parser.add_argument(
        "--source",
        "--plugin",
        dest="source",
        action="append",
        default=[],
        metavar="VALUE",
        help="Case-insensitive match against later bracket fields, such as source or plugin.",
    )
    parser.add_argument(
        "--field",
        action="append",
        default=[],
        metavar="NAME=VALUE",
        help=(
            "Case-insensitive substring match against a parsed bracket field. "
            "Names include engine/runtime, level, time/timestamp, source/plugin, "
            "or a zero-based bracket index such as 3=Editor. Repeatable."
        ),
    )
    parser.add_argument(
        "--contains",
        "--message",
        dest="contains",
        action="append",
        default=[],
        metavar="TEXT",
        help="Case-insensitive substring match against the full log line.",
    )
    return parser.parse_args()


def normalized(value: str) -> str:
    return value.strip().casefold()


def leading_bracket_fields(line: str) -> List[str]:
    match = re.match(r"^\s*((?:\[[^\]]*\]\s*)+)", line)
    if not match:
        return []
    return [chunk[1:-1].strip() for chunk in re.findall(r"\[[^\]]*\]", match.group(1))]


def text_matches(value: str, pattern: str) -> bool:
    return normalized(pattern) in normalized(value)


def matches_field_values(values: Sequence[str], candidate: str | None) -> bool:
    if not values:
        return True
    if candidate is None:
        return False
    return any(text_matches(candidate, value) for value in values)


def matches_source(values: Sequence[str], fields: Sequence[str]) -> bool:
    if not values:
        return True
    candidates = list(fields[3:]) or list(fields[2:]) or list(fields[1:])
    return any(text_matches(candidate, value) for candidate in candidates for value in values)


def parse_field_filter(raw: str) -> tuple[int, str]:
    if "=" not in raw:
        raise SystemExit(f"--field must be NAME=VALUE, got: {raw}")
    name, value = raw.split("=", 1)
    name = normalized(name)
    if not name:
        raise SystemExit(f"--field name is empty: {raw}")
    if value == "":
        raise SystemExit(f"--field value is empty: {raw}")
    if name.isdigit():
        return int(name), value
    if name not in FIELD_ALIASES:
        known = ", ".join(sorted(FIELD_ALIASES))
        raise SystemExit(f"unknown --field name '{name}'. Use an index or one of: {known}")
    return FIELD_ALIASES[name], value


def parse_field_filters(raw_filters: Sequence[str]) -> Dict[int, List[str]]:
    filters: Dict[int, List[str]] = {}
    for raw in raw_filters:
        index, value = parse_field_filter(raw)
        filters.setdefault(index, []).append(value)
    return filters


def matches_named_fields(fields: Sequence[str], filters: Dict[int, Sequence[str]]) -> bool:
    for index, values in filters.items():
        if index >= len(fields):
            return False
        if not matches_field_values(values, fields[index]):
            return False
    return True


def matches_contains(line: str, values: Sequence[str]) -> bool:
    return all(text_matches(line, value) for value in values)


def is_candidate_line(line: str) -> bool:
    lower = line.casefold()
    return any(marker in lower for marker in BLOCK_MARKERS)


def is_repeat_notice(line: str) -> bool:
    return "last script exception repeated" in line.casefold()


def field_value(line: str, index: int) -> str | None:
    fields = leading_bracket_fields(line)
    if len(fields) <= index:
        return None
    return normalized(fields[index])


def is_error_line(line: str) -> bool:
    return field_value(line, 1) == "error"


def same_source_line(left: str, right: str) -> bool:
    left_fields = leading_bracket_fields(left)
    right_fields = leading_bracket_fields(right)
    return normalized(" ".join(left_fields[2:])) == normalized(" ".join(right_fields[2:]))


def rewind_error_block(lines: Sequence[str], idx: int) -> int:
    if not is_error_line(lines[idx]):
        return idx
    while idx > 0 and is_error_line(lines[idx - 1]) and same_source_line(lines[idx], lines[idx - 1]):
        idx -= 1
    return idx


def line_matches_filters(
    line: str,
    engine: Sequence[str],
    level: Sequence[str],
    source: Sequence[str],
    field_filters: Dict[int, Sequence[str]],
    contains: Sequence[str],
) -> bool:
    fields = leading_bracket_fields(line)
    if not fields:
        return False
    return (
        matches_field_values(engine, fields[0] if len(fields) > 0 else None)
        and matches_field_values(level, fields[1] if len(fields) > 1 else None)
        and matches_source(source, fields)
        and matches_named_fields(fields, field_filters)
        and matches_contains(line, contains)
    )


def looks_like_new_log_entry(line: str) -> bool:
    return bool(leading_bracket_fields(line))


def expand_block(lines: Sequence[str], idx: int, context: int) -> tuple[int, int]:
    start = max(0, idx - context)
    end = min(len(lines), idx + context + 1)

    while end < len(lines) and is_error_line(lines[idx]) and is_error_line(lines[end]) and same_source_line(lines[idx], lines[end]):
        end += 1

    while end < len(lines):
        next_line = lines[end]
        if looks_like_new_log_entry(next_line):
            break
        if next_line.strip() == "":
            end += 1
            continue
        end += 1
    return start, end


def find_blocks(lines: Sequence[str], args: argparse.Namespace) -> List[tuple[int, int, int]]:
    blocks: List[tuple[int, int, int]] = []
    idx = len(lines) - 1
    max_matches = len(lines) if args.all else max(1, args.count)
    field_filters = parse_field_filters(args.field)

    while idx >= 0 and len(blocks) < max_matches:
        found = None
        for current in range(idx, -1, -1):
            line = lines[current]
            if not is_candidate_line(line):
                continue
            if is_repeat_notice(line) and not args.include_repeats:
                continue
            if not line_matches_filters(
                line,
                args.engine,
                args.level,
                args.source,
                field_filters,
                args.contains,
            ):
                continue
            found = current
            break
        if found is None:
            break
        found = rewind_error_block(lines, found)
        start, end = expand_block(lines, found, max(0, args.context))
        blocks.append((found, start, end))
        idx = start - 1
    return blocks


def format_block(lines: Sequence[str], block: tuple[int, int, int], index: int, total: int) -> str:
    found, start, end = block
    header = f"===== match {index}/{total} at line {found + 1} ====="
    body = "\n".join(f"{line}" for line in lines[start:end])
    return f"{header}\n{body}"


def main() -> int:
    args = parse_args()
    log_path = args.log.expanduser()
    if not log_path.exists():
        raise SystemExit(f"log file not found: {log_path}")

    lines = log_path.read_text(errors="replace").splitlines()
    blocks = find_blocks(lines, args)

    if not blocks:
        print("No matching script exception block found.")
        return 1

    total = len(blocks)
    for index, block in enumerate(blocks, start=1):
        if index > 1:
            print()
        print(format_block(lines, block, index, total))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
