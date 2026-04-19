#!/usr/bin/env python3
import argparse
import json
import math
import subprocess
import sys
from dataclasses import dataclass, asdict
from pathlib import Path


MCP_ROOT = Path.home() / "src/openplanet/my-plugins/tm-control-mcp"
CALL_PY = MCP_ROOT / "tools/call.py"


@dataclass
class Block:
    group: str
    blockName: str
    x: float
    y: float
    z: float
    pitch: float = 0.0
    yaw: float = 0.0
    roll: float = 0.0


@dataclass
class Item:
    group: str
    itemPath: str
    x: float
    y: float
    z: float
    pitch: float = 0.0
    yaw: float = 0.0
    roll: float = 0.0


def round3(value: float) -> float:
    return round(value, 3)


def unit_from_degrees(deg: float) -> tuple[float, float]:
    angle = math.radians(deg)
    return math.cos(angle), math.sin(angle)


def add_route_deck(blocks: list[Block], group: str, block: str, x: float, y: float, z: float, yaw: float, radial_deg: float, pitch: float, width: int = 2) -> None:
    lx, lz = unit_from_degrees(radial_deg)
    offsets = [-15.0, 15.0] if width == 2 else [-28.0, 0.0, 28.0]
    for offset in offsets:
        blocks.append(Block(group, block, round3(x + lx * offset), round3(y), round3(z + lz * offset), round3(pitch), round3(yaw), 0.0))


def build_manifest() -> tuple[list[Block], list[Item]]:
    blocks: list[Block] = []
    items: list[Item] = []

    cx, cz = 760.0, 760.0
    radius = 235.0
    segments = 80
    start_y = 28.0
    rise = 2.55
    start_angle = -150.0
    step = 8.0

    route_points: list[tuple[float, float, float, float]] = []
    for i in range(segments):
        angle_deg = start_angle + i * step
        angle = math.radians(angle_deg)
        x = cx + math.cos(angle) * radius
        z = cz + math.sin(angle) * radius
        y = start_y + i * rise
        # Use the circle tangent for block yaw, and the radius for lane offsets.
        yaw = angle_deg + 2.0
        radial_deg = angle_deg
        pitch = 4.5 if i < segments - 1 else 0.0

        if i == 0:
            block = "RoadTechSlopeStart2x1"
        elif i == segments - 1:
            block = "RoadTechFinish"
        elif i in {16, 32, 48, 64}:
            block = "RoadTechCheckpoint"
        elif 10 <= i <= 22:
            block = "RoadTechPenaltyIce"
        elif 42 <= i <= 48:
            block = "PlatformPlasticDiag1"
        else:
            block = "RoadTechStraight"

        add_route_deck(blocks, "route", block, x, y, z, yaw, radial_deg, pitch, 2)
        route_points.append((x, y, z, yaw, radial_deg))

        if i % 5 == 0:
            floor = i // 5 + 1
            lx, lz = unit_from_degrees(radial_deg)
            items.append(Item("floor-markers", "LightCube4m" if floor % 2 else "LightCube2m", round3(x - lx * 38.0), round3(y + 8.0), round3(z - lz * 38.0), yaw=round3(yaw)))

    # Ice slide visual: an obvious 360 swirl next to the route's ice section.
    ice_x, ice_y, ice_z, _, _ = route_points[16]
    for j in range(9):
        deg = j * 40.0
        angle = math.radians(deg)
        r = 34.0 + j * 5.5
        blocks.append(Block("ice-swirl", "RoadTechPenaltyIce", round3(ice_x + math.cos(angle) * r), round3(ice_y + 7.0), round3(ice_z + math.sin(angle) * r), -3.0, round3(deg + 90.0), round3(j * 4.0)))

    # Upper dirt wallride: readable vertical slabs beside the late route.
    # Keep the whole run below the 256m editor height cap for 48x40x48 maps.
    dirt_x, dirt_y, dirt_z, dirt_yaw, dirt_radial = route_points[66]
    lx, lz = unit_from_degrees(dirt_radial)
    for j in range(8):
        blocks.append(Block("dirt-wallride", "RoadTechPenaltyDirt", round3(dirt_x + lx * 62.0), round3(dirt_y + j * 6.0), round3(dirt_z + lz * 62.0 + j * 7.0), 0.0, round3(dirt_yaw), 68.0))

    # Finish-over-chasm motif: dark panels under the final approach.
    finish_x, finish_y, finish_z, finish_yaw, finish_radial = route_points[-1]
    for j, offset in enumerate([-58.0, -28.0, 4.0, 36.0, 68.0]):
        lx, lz = unit_from_degrees(finish_radial)
        blocks.append(Block("finish-chasm", "TechnicsScreen1x1Straight", round3(finish_x + lx * offset), round3(finish_y - 24.0), round3(finish_z + lz * offset), 0.0, round3(finish_yaw + 180.0), 0.0))
    items.append(Item("finish-crown", "LightCube8m", round3(finish_x), round3(finish_y + 16.0), round3(finish_z), yaw=round3(finish_yaw)))

    # Sparse billboard/floor identity panels, deliberately not too many.
    for idx in [8, 24, 40, 56, 72]:
        x, y, z, yaw, radial_deg = route_points[idx]
        lx, lz = unit_from_degrees(radial_deg)
        blocks.append(Block("floor-screens", "TechnicsScreen2x1StraightSmall", round3(x + lx * 74.0), round3(y + 10.0), round3(z + lz * 74.0), 0.0, round3(yaw + 180.0), 0.0))

    return blocks, items


def call_tool(tool: str, payload: dict, socket_timeout: float) -> dict:
    proc = subprocess.run(
        ["python3", str(CALL_PY), "--timeout", str(socket_timeout), tool, json.dumps(payload, separators=(",", ":"))],
        cwd=MCP_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=socket_timeout + 5.0,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"{tool} failed: {proc.stdout.strip()} {proc.stderr.strip()}")
    response = json.loads(proc.stdout)
    if not response.get("ok"):
        raise RuntimeError(f"{tool} returned error: {response}")
    return response["data"]["result"]["output"]


def block_payload(block: Block) -> dict:
    payload = asdict(block)
    payload.pop("group")
    return payload


def item_payload(item: Item) -> dict:
    payload = asdict(item)
    payload.pop("group")
    return payload


def chunked(entries: list, chunk_size: int) -> list[list]:
    return [entries[i : i + chunk_size] for i in range(0, len(entries), chunk_size)]


def compact_counts(blocks: list[Block], items: list[Item]) -> dict:
    groups: dict[str, dict[str, int]] = {}
    for block in blocks:
        groups.setdefault(block.group, {"blocks": 0, "items": 0})["blocks"] += 1
    for item in items:
        groups.setdefault(item.group, {"blocks": 0, "items": 0})["items"] += 1
    return groups


def build_and_place(name: str, group: str, entries: list, socket_timeout: float) -> dict:
    call_tool("CreateNamedMacroblock", {"name": name, "replace": True}, socket_timeout)
    blocks = [block_payload(entry) for entry in entries if isinstance(entry, Block)]
    items = [item_payload(entry) for entry in entries if isinstance(entry, Item)]
    if blocks:
        call_tool("AddBlocksToNamedMacroblock", {"name": name, "blocks": blocks, "create": False}, socket_timeout)
    if items:
        call_tool("AddItemsToNamedMacroblock", {"name": name, "items": items, "create": False}, socket_timeout)
    result = call_tool("PlaceNamedMacroblock", {"name": name}, socket_timeout)
    result["name"] = name
    result["group"] = group
    result["requestedBlocks"] = len(blocks)
    result["requestedItems"] = len(items)
    return result


def execute(blocks: list[Block], items: list[Item], save: bool, chunk_size: int, socket_timeout: float, route_only: bool, deco_only: bool) -> dict:
    route_blocks = [block for block in blocks if block.group == "route"]
    deco_groups: dict[str, list] = {}
    for block in blocks:
        if block.group != "route":
            deco_groups.setdefault(block.group, []).append(block)
    for item in items:
        deco_groups.setdefault(item.group, []).append(item)

    route_results = []
    if not deco_only:
        for ix, block_chunk in enumerate(chunked(route_blocks, chunk_size)):
            route_results.append(build_and_place(f"dd2-v2-route-{ix:02d}", "route", block_chunk, socket_timeout))

    deco_results = []
    if not route_only:
        for group, entries in deco_groups.items():
            for ix, deco_chunk in enumerate(chunked(entries, chunk_size)):
                deco_results.append(build_and_place(f"dd2-v2-deco-{group}-{ix:02d}", group, deco_chunk, socket_timeout))

    results = route_results + deco_results
    if not results:
        raise RuntimeError("Nothing was selected for execution")

    first_result = results[0]
    last_result = results[-1]
    output = {
        "routeChunks": len(route_results),
        "decoChunks": len(deco_results),
        "allPlaced": all(result.get("placed") for result in results),
        "blocks": [first_result.get("mapPre", {}).get("nbBlocks"), last_result.get("mapPost", {}).get("nbBlocks")],
        "items": [first_result.get("mapPre", {}).get("nbItems"), last_result.get("mapPost", {}).get("nbItems")],
        "chunkResults": [
            {
                "name": result.get("name"),
                "group": result.get("group"),
                "placed": result.get("placed"),
                "requestedBlocks": result.get("requestedBlocks"),
                "requestedItems": result.get("requestedItems"),
                "blocks": [result.get("mapPre", {}).get("nbBlocks"), result.get("mapPost", {}).get("nbBlocks")],
                "items": [result.get("mapPre", {}).get("nbItems"), result.get("mapPost", {}).get("nbItems")],
            }
            for result in results
        ],
    }
    if save:
        output["save"] = call_tool("SaveMapAs", {"name": "codex-deepdip2-v2-20260420", "folder": "MCP", "overwrite": True}, socket_timeout)
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a drivable-ish Deep Dip 2 homage through tm-control-mcp.")
    parser.add_argument("--execute", action="store_true", help="Place the route and deco macroblocks.")
    parser.add_argument("--save", action="store_true", help="Save the map after placement.")
    parser.add_argument("--chunk-size", type=int, default=999, help="Macroblock placement chunk size; pass a smaller value only when isolating failures.")
    parser.add_argument("--timeout", type=float, default=20.0, help="Socket timeout for long macroblock placements.")
    parser.add_argument("--route-only", action="store_true", help="Place only the route chunks.")
    parser.add_argument("--deco-only", action="store_true", help="Place only the decoration chunks.")
    parser.add_argument("--no-specials", action="store_true", help="Convert route surface/start/checkpoint/finish blocks to RoadTechStraight for isolation.")
    parser.add_argument("--samples", type=int, default=5, help="Number of sample placements to include in dry-run output.")
    args = parser.parse_args()

    blocks, items = build_manifest()
    if args.no_specials:
        for block in blocks:
            if block.group == "route":
                block.blockName = "RoadTechStraight"
    manifest = {
        "blocks": len(blocks),
        "items": len(items),
        "groups": compact_counts(blocks, items),
        "sampleBlocks": [asdict(block) for block in blocks[: args.samples]],
        "sampleItems": [asdict(item) for item in items[: args.samples]],
    }
    if not args.execute:
        print(json.dumps({"mode": "dry-run", "manifest": manifest}, separators=(",", ":")))
        return 0

    result = execute(blocks, items, args.save, max(1, args.chunk_size), args.timeout, args.route_only, args.deco_only)
    print(json.dumps({"mode": "execute", "manifest": manifest, "result": result}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
