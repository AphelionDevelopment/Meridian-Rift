"""Generate exact-size, text-free Augments preview-decoration DMIs.

Run from the repository root with:
    tools/bootstrap/python modular_nova/modules/character_preview_background/tools/generate_preview_decorations.py

The canonical callout schema is shared with TGUI. The native overlay draws only
the segment that must cross the BYOND map surface; labels and controls remain in
normal browser layout outside the map.
"""

import json
from pathlib import Path
import sys

from PIL import Image, ImageDraw


REPOSITORY_ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPOSITORY_ROOT))

from tools.dmi import Dmi, EAST, NORTH, SOUTH, WEST  # noqa: E402


OUTPUT_DIRECTORY = Path(__file__).resolve().parents[1] / "icons"
CALLOUT_SCHEMA_PATH = (
    REPOSITORY_ROOT
    / "tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences"
    / "augmentation-preview-callouts.json"
)
SIZES = (32, 64, 96)
STATES = (
    "augmentation_markings",
    "augmentation_body_parts",
    "augmentation_implants",
)
VALID_SIDES = frozenset(("top", "right", "bottom", "left"))
BYOND_CARDINAL_DIRECTIONS = (SOUTH, NORTH, EAST, WEST)
SELECTED_STATE_SEPARATOR = "--"
SIDE_VIEW_DEPTH_SCALE = 0.3
AUGMENTATION_FRAME = (240, 68, 89, 255)
AUGMENTATION_READOUT = (0, 229, 212, 255)
AUGMENTATION_LEADER = (0, 176, 165, 235)


def _percentage(value, context: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{context} must be a number")
    if not 0 <= value <= 100:
        raise ValueError(f"{context} must be between 0 and 100")
    return float(value)


def _load_callout_schema():
    schema = json.loads(CALLOUT_SCHEMA_PATH.read_text(encoding="utf-8"))
    if not isinstance(schema, dict):
        raise ValueError("Callout schema root must be an object")

    modes = schema.get("modes")
    profiles = schema.get("profiles")
    if not isinstance(modes, dict) or set(modes) != set(STATES):
        raise ValueError("Callout schema modes must match the DMI states exactly")
    if not isinstance(profiles, dict) or not profiles:
        raise ValueError("Callout schema must define at least one profile")

    for mode, profile_name in modes.items():
        if profile_name not in profiles:
            raise ValueError(f"{mode} references missing profile {profile_name!r}")

    for profile_name, callouts in profiles.items():
        if not isinstance(callouts, list) or not callouts:
            raise ValueError(f"Profile {profile_name!r} must contain callouts")
        regions = set()
        for index, callout in enumerate(callouts):
            context = f"profiles.{profile_name}[{index}]"
            if not isinstance(callout, dict):
                raise ValueError(f"{context} must be an object")
            if set(callout) != {"region", "side", "edge", "target"}:
                raise ValueError(f"{context} has unexpected fields")

            region = callout["region"]
            if not isinstance(region, str) or not region:
                raise ValueError(f"{context}.region must be a non-empty string")
            if region in regions:
                raise ValueError(
                    f"Profile {profile_name!r} repeats region {region!r}"
                )
            regions.add(region)

            if callout["side"] not in VALID_SIDES:
                raise ValueError(f"{context}.side is invalid")
            _percentage(callout["edge"], f"{context}.edge")

            target = callout["target"]
            if not isinstance(target, dict) or set(target) != {"x", "y"}:
                raise ValueError(f"{context}.target must contain x and y")
            _percentage(target["x"], f"{context}.target.x")
            _percentage(target["y"], f"{context}.target.y")

    return modes, profiles


def _pixel(size: int, percentage: float) -> int:
    return max(0, min(size - 1, round((size - 1) * percentage / 100)))


def _draw_corner_brackets(draw, size: int, state: str) -> None:
    inset = 1
    low = inset
    high = size - inset - 1
    arm = max(2, round(size * 0.08))
    color = (
        AUGMENTATION_READOUT
        if state == "augmentation_implants"
        else AUGMENTATION_FRAME
    )

    for points in (
        (low, low, low + arm, low),
        (low, low, low, low + arm),
        (high - arm, low, high, low),
        (high, low, high, low + arm),
        (low, high - arm, low, high),
        (low, high, low + arm, high),
        (high, high - arm, high, high),
        (high - arm, high, high, high),
    ):
        draw.line(points, fill=color, width=1)


def _directional_target(target, direction: int):
    x = target["x"]
    y = target["y"]
    if direction == NORTH:
        x = 100 - x
    elif direction == EAST:
        x = 50 + (x - 50) * SIDE_VIEW_DEPTH_SCALE
    elif direction == WEST:
        x = 50 - (x - 50) * SIDE_VIEW_DEPTH_SCALE
    return x, y


def _callout_points(size: int, callout, direction: int):
    side = callout["side"]
    edge = _pixel(size, callout["edge"])
    target_x, target_y = _directional_target(callout["target"], direction)
    target = (
        _pixel(size, target_x),
        _pixel(size, target_y),
    )
    inset = max(3, round(size * 0.12))
    high = size - 1

    if side == "top":
        return (edge, 0), (edge, inset), target
    if side == "right":
        return (high, edge), (high - inset, edge), target
    if side == "bottom":
        return (edge, high), (edge, high - inset), target
    return (0, edge), (inset, edge), target


def _draw_target(draw, point, state: str) -> None:
    x, y = point
    if state == "augmentation_markings":
        draw.point((x, y), fill=AUGMENTATION_READOUT)
        draw.point((x - 1, y), fill=AUGMENTATION_FRAME)
        draw.point((x + 1, y), fill=AUGMENTATION_FRAME)
        return

    if state == "augmentation_body_parts":
        draw.rectangle((x - 1, y - 1, x + 1, y + 1), outline=AUGMENTATION_FRAME)
        draw.point((x, y), fill=AUGMENTATION_READOUT)
        return

    draw.point((x, y), fill=AUGMENTATION_READOUT)
    for node in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
        draw.point(node, fill=AUGMENTATION_FRAME)


def _draw_callout(draw, size: int, state: str, callout, direction: int) -> None:
    edge, elbow, target = _callout_points(size, callout, direction)
    draw.line((*edge, *elbow), fill=AUGMENTATION_READOUT, width=1)
    draw.line((*elbow, *target), fill=AUGMENTATION_LEADER, width=1)
    draw.point(edge, fill=AUGMENTATION_READOUT)
    _draw_target(draw, target, state)


def _draw_state(size: int, state: str, callout, direction: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_corner_brackets(draw, size, state)
    if callout is not None:
        _draw_callout(draw, size, state, callout, direction)
    return image


def generate() -> None:
    modes, profiles = _load_callout_schema()
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        dmi = Dmi(size, size)
        for mode in STATES:
            base_state = dmi.state(mode, dirs=4)
            for direction in BYOND_CARDINAL_DIRECTIONS:
                base_state.frame(_draw_state(size, mode, None, direction))

            for callout in profiles[modes[mode]]:
                selected_state = dmi.state(
                    f"{mode}{SELECTED_STATE_SEPARATOR}{callout['region']}",
                    dirs=4,
                )
                for direction in BYOND_CARDINAL_DIRECTIONS:
                    selected_state.frame(
                        _draw_state(size, mode, callout, direction)
                    )
        dmi.to_file(OUTPUT_DIRECTORY / f"preview_decoration_{size}x{size}.dmi")


if __name__ == "__main__":
    generate()
