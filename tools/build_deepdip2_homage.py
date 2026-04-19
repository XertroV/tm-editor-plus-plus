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


def lateral(yaw_deg: float) -> tuple[float, float]:
    angle = math.radians(yaw_deg + 90.0)
    return math.cos(angle), math.sin(angle)


def add_route_deck(blocks: list[Block], group: str, block: str, x: float, y: float, z: float, yaw: float, pitch: float, width: int = 2) -> None:
    lx, lz = lateral(yaw)
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
        yaw = angle_deg + 92.0
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

        add_route_deck(blocks, "route", block, x, y, z, yaw, pitch, 2)
        route_points.append((x, y, z, yaw))

        if i % 5 == 0:
            floor = i // 5 + 1
            lx, lz = lateral(yaw)
            items.append(Item("floor-markers", "LightCube4m" if floor % 2 else "LightCube2m", round3(x - lx * 38.0), round3(y + 8.0), round3(z - lz * 38.0), yaw=round3(yaw)))

    # Ice slide visual: an obvious 360 swirl next to the route's ice section.
    ice_x, ice_y, ice_z, _ = route_points[16]
    for j in range(9):
        deg = j * 40.0
        angle = math.radians(deg)
        r = 34.0 + j * 5.5
        blocks.append(Block("ice-swirl", "RoadTechPenaltyIce", round3(ice_x + math.cos(angle) * r), round3(ice_y + 7.0), round3(ice_z + math.sin(angle) * r), -3.0, round3(deg + 90.0), round3(j * 4.0)))

    # Upper dirt wallride: readable vertical slabs beside the late route.
    dirt_x, dirt_y, dirt_z, dirt_yaw = route_points[66]
    lx, lz = lateral(dirt_yaw)
    for j in range(8):
        blocks.append(Block("dirt-wallride", "RoadTechPenaltyDirt", round3(dirt_x + lx * 62.0), round3(dirt_y + j * 10.0), round3(dirt_z + lz * 62.0 + j * 8.0), 0.0, round3(dirt_yaw), 82.0))

    # Finish-over-chasm motif: dark panels under the final approach.
    finish_x, finish_y, finish_z, finish_yaw = route_points[-1]
    for j, offset in enumerate([-58.0, -28.0, 4.0, 36.0, 68.0]):
        lx, lz = lateral(finish_yaw)
        blocks.append(Block("finish-chasm", "TechnicsScreen1x1Straight", round3(finish_x + lx * offset), round3(finish_y - 22.0 - (j % 2) * 4.0), round3(finish_z + lz * offset), -32.0, round3(finish_yaw + 180.0 + j * 7.0), round3(-18.0 + j * 9.0)))
    items.append(Item("finish-crown", "LightCube8m", round3(finish_x), round3(finish_y + 16.0), round3(finish_z), yaw=round3(finish_yaw)))

    # Sparse billboard/floor identity panels, deliberately not too many.
    for idx in [8, 24, 40, 56, 72]:
        x, y, z, yaw = route_points[idx]
        lx, lz = lateral(yaw)
        blocks.append(Block("floor-screens", "TechnicsScreen2x1StraightSmall", round3(x + lx * 74.0), round3(y + 10.0), round3(z + lz * 74.0), -8.0, round3(yaw + 180.0), 0.0))

    return blocks, items


def call_tool(tool: str, payload: dict) -> dict:
    proc = subprocess.run(
        ["python3", str(CALL_PY), tool, json.dumps(payload, separators=(",", ":"))],
        cwd=MCP_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=30,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"{tool} failed: {proc.stdout.strip()} {proc.stderr.strip()}")
    response = json.loads(proc.stdout)
    if not response.get("ok"):
        raise RuntimeError(f"{tool} returned error: {response}")
    return response["data"]["result"]["output"]


def add_block(name: str, block: Block) -> None:
    payload = asdict(block)
    payload.pop("group")
    payload["name"] = name
    call_tool("AddBlockToNamedMacroblock", payload)


def add_item(name: str, item: Item) -> None:
    payload = asdict(item)
    payload.pop("group")
    payload["name"] = name
    call_tool("AddItemToNamedMacroblock", payload)


def compact_counts(blocks: list[Block], items: list[Item]) -> dict:
    groups: dict[str, dict[str, int]] = {}
    for block in blocks:
        groups.setdefault(block.group, {"blocks": 0, "items": 0})["blocks"] += 1
    for item in items:
        groups.setdefault(item.group, {"blocks": 0, "items": 0})["items"] += 1
    return groups


def execute(blocks: list[Block], items: list[Item], save: bool) -> dict:
    route_name = "dd2-v2-route"
    deco_name = "dd2-v2-deco"

    call_tool("CreateNamedMacroblock", {"name": route_name, "replace": True})
    call_tool("CreateNamedMacroblock", {"name": deco_name, "replace": True})

    for block in blocks:
        add_block(route_name if block.group == "route" else deco_name, block)
    for item in items:
        add_item(deco_name, item)

    route_result = call_tool("PlaceNamedMacroblock", {"name": route_name})
    deco_result = call_tool("PlaceNamedMacroblock", {"name": deco_name})
    output = {
        "routePlaced": route_result.get("placed"),
        "decoPlaced": deco_result.get("placed"),
        "routeBlocks": [route_result.get("mapPre", {}).get("nbBlocks"), route_result.get("mapPost", {}).get("nbBlocks")],
        "routeItems": [route_result.get("mapPre", {}).get("nbItems"), route_result.get("mapPost", {}).get("nbItems")],
        "decoBlocks": [deco_result.get("mapPre", {}).get("nbBlocks"), deco_result.get("mapPost", {}).get("nbBlocks")],
        "decoItems": [deco_result.get("mapPre", {}).get("nbItems"), deco_result.get("mapPost", {}).get("nbItems")],
    }
    if save:
        output["save"] = call_tool("SaveMapAs", {"name": "codex-deepdip2-v2-20260420", "folder": "MCP", "overwrite": True})
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a drivable-ish Deep Dip 2 homage through tm-control-mcp.")
    parser.add_argument("--execute", action="store_true", help="Place the route and deco macroblocks.")
    parser.add_argument("--save", action="store_true", help="Save the map after placement.")
    parser.add_argument("--samples", type=int, default=5, help="Number of sample placements to include in dry-run output.")
    args = parser.parse_args()

    blocks, items = build_manifest()
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

    result = execute(blocks, items, args.save)
    print(json.dumps({"mode": "execute", "manifest": manifest, "result": result}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
