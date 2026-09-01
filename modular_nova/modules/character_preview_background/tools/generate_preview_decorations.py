"""Generate exact-size transparent Augments preview-decoration DMIs.

Run from the repository root with:
    tools/bootstrap/python modular_nova/modules/character_preview_background/tools/generate_preview_decorations.py

The three equal-size states are selected by the active Augments tab. Their
coordinates intentionally target broad regions rather than a specific humanoid
silhouette so rotated, taur, oversized, and nonhuman bodies remain plausible.
"""

from pathlib import Path
import sys

from PIL import Image, ImageDraw


REPOSITORY_ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPOSITORY_ROOT))

from tools.dmi import Dmi  # noqa: E402


OUTPUT_DIRECTORY = Path(__file__).resolve().parents[1] / "icons"
SIZES = (32, 64, 96)
STATES = (
    "augmentation_markings",
    "augmentation_body_parts",
    "augmentation_implants",
)
AUGMENTATION_FRAME = (240, 68, 89, 255)
AUGMENTATION_READOUT = (0, 229, 212, 255)
AUGMENTATION_LEADER = (82, 118, 121, 220)

PIXEL_FONT = {
    " ": ("000", "000", "000", "000", "000"),
    "A": ("010", "101", "111", "101", "101"),
    "B": ("110", "101", "110", "101", "110"),
    "C": ("111", "100", "100", "100", "111"),
    "D": ("110", "101", "101", "101", "110"),
    "E": ("111", "100", "110", "100", "111"),
    "F": ("111", "100", "110", "100", "100"),
    "G": ("011", "100", "101", "101", "011"),
    "H": ("101", "101", "111", "101", "101"),
    "I": ("111", "010", "010", "010", "111"),
    "L": ("100", "100", "100", "100", "111"),
    "M": ("101", "111", "111", "101", "101"),
    "N": ("101", "111", "111", "111", "101"),
    "O": ("111", "101", "101", "101", "111"),
    "P": ("110", "101", "110", "100", "100"),
    "R": ("110", "101", "110", "101", "101"),
    "S": ("011", "100", "010", "001", "110"),
    "T": ("111", "010", "010", "010", "010"),
    "U": ("101", "101", "101", "101", "111"),
    "Y": ("101", "101", "010", "010", "010"),
}

# label, side, label-lane, target-x, target-y
FULL_LAYOUTS = {
    "augmentation_markings": (
        ("HEAD", "left", 0.08, 0.50, 0.22),
        ("CHEST", "right", 0.10, 0.50, 0.45),
        ("LEFT ARM", "left", 0.31, 0.36, 0.43),
        ("RIGHT ARM", "right", 0.31, 0.64, 0.43),
        ("LEFT HAND", "left", 0.51, 0.28, 0.55),
        ("RIGHT HAND", "right", 0.51, 0.72, 0.55),
        ("LEFT LEG", "left", 0.79, 0.43, 0.76),
        ("RIGHT LEG", "right", 0.79, 0.57, 0.76),
    ),
    "augmentation_body_parts": (
        ("HEAD", "left", 0.08, 0.50, 0.22),
        ("CORE", "right", 0.12, 0.50, 0.46),
        ("LEFT ARM", "left", 0.31, 0.36, 0.43),
        ("RIGHT ARM", "right", 0.31, 0.64, 0.43),
        ("LEFT HAND", "left", 0.51, 0.28, 0.55),
        ("RIGHT HAND", "right", 0.51, 0.72, 0.55),
        ("LEFT LEG", "left", 0.76, 0.43, 0.76),
        ("RIGHT LEG", "right", 0.76, 0.57, 0.76),
    ),
    "augmentation_implants": (
        ("EYES", "left", 0.07, 0.50, 0.27),
        ("BRAIN", "right", 0.07, 0.50, 0.20),
        ("MOUTH", "left", 0.27, 0.50, 0.31),
        ("EARS", "right", 0.27, 0.50, 0.27),
        ("CHEST", "left", 0.52, 0.50, 0.44),
        ("ABDOMEN", "right", 0.72, 0.50, 0.57),
    ),
}

# At 64px the full bilateral labels collide across the middle of the atlas.
# Shorten only their directional prefixes while keeping the anatomical names
# explicit; the 96px state retains the full wording.
MEDIUM_LAYOUTS = {
    "augmentation_markings": (
        ("HEAD", "left", 0.08, 0.50, 0.22),
        ("CHEST", "right", 0.10, 0.50, 0.45),
        ("L ARM", "left", 0.30, 0.36, 0.42),
        ("R ARM", "right", 0.30, 0.64, 0.42),
        ("L HAND", "left", 0.48, 0.28, 0.55),
        ("R HAND", "right", 0.48, 0.72, 0.55),
        ("L LEG", "left", 0.72, 0.43, 0.76),
        ("R LEG", "right", 0.72, 0.57, 0.76),
    ),
    "augmentation_body_parts": (
        ("HEAD", "left", 0.08, 0.50, 0.22),
        ("CORE", "right", 0.10, 0.50, 0.46),
        ("L ARM", "left", 0.30, 0.36, 0.42),
        ("R ARM", "right", 0.30, 0.64, 0.42),
        ("L HAND", "left", 0.48, 0.28, 0.55),
        ("R HAND", "right", 0.48, 0.72, 0.55),
        ("L LEG", "left", 0.72, 0.43, 0.76),
        ("R LEG", "right", 0.72, 0.57, 0.76),
    ),
    "augmentation_implants": FULL_LAYOUTS["augmentation_implants"],
}

# A 32px canvas is enlarged substantially in Preferences. Distinct semantic
# codes remain legible there; shrinking all eight full labels does not.
COMPACT_LAYOUTS = {
    "augmentation_markings": (
        ("H", "left", 0.08, 0.50, 0.22),
        ("C", "right", 0.10, 0.50, 0.45),
        ("A", "left", 0.39, 0.35, 0.44),
        ("A", "right", 0.39, 0.65, 0.44),
        ("HN", "left", 0.56, 0.31, 0.55),
        ("HN", "right", 0.56, 0.66, 0.55),
        ("L", "left", 0.79, 0.43, 0.76),
        ("L", "right", 0.79, 0.57, 0.76),
    ),
    "augmentation_body_parts": (
        ("H", "left", 0.08, 0.50, 0.22),
        ("CR", "right", 0.10, 0.50, 0.46),
        ("A", "left", 0.39, 0.35, 0.44),
        ("A", "right", 0.39, 0.65, 0.44),
        ("HN", "left", 0.56, 0.31, 0.55),
        ("HN", "right", 0.56, 0.66, 0.55),
        ("L", "left", 0.76, 0.43, 0.76),
        ("L", "right", 0.76, 0.57, 0.76),
    ),
    "augmentation_implants": (
        ("EYE", "left", 0.07, 0.50, 0.27),
        ("BR", "right", 0.07, 0.50, 0.20),
        ("MTH", "left", 0.30, 0.50, 0.31),
        ("EAR", "right", 0.30, 0.53, 0.27),
        ("CH", "left", 0.52, 0.47, 0.43),
        ("AB", "right", 0.73, 0.54, 0.58),
    ),
}


def _draw_corner_brackets(draw, size, color, *, inset, arm, width):
    low = inset
    high = size - inset - 1
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
        draw.line(points, fill=color, width=width)


def _text_width(text: str) -> int:
    return max(0, len(text) * 4 - 1)


def _draw_pixel_text(draw, text: str, x: int, y: int) -> None:
    for index, character in enumerate(text):
        try:
            glyph = PIXEL_FONT[character]
        except KeyError as error:
            raise ValueError(f"Missing pixel-font glyph for {character!r}") from error
        for row, pixels in enumerate(glyph):
            for column, pixel in enumerate(pixels):
                if pixel == "1":
                    draw.point(
                        (x + index * 4 + column, y + row),
                        fill=AUGMENTATION_READOUT,
                    )


def _draw_target(draw, x: int, y: int, side: str) -> None:
    draw.point((x, y), fill=AUGMENTATION_READOUT)
    draw.point((x, y - 1), fill=AUGMENTATION_FRAME)
    draw.point((x, y + 1), fill=AUGMENTATION_FRAME)
    draw.point((x - 1 if side == "left" else x + 1, y), fill=AUGMENTATION_FRAME)


def _label_bounds(size: int, label: str, side: str, lane: float):
    label_width = _text_width(label)
    label_y = max(1, min(size - 6, round(size * lane) - 2))
    label_x = 2 if side == "left" else size - label_width - 2
    return (label_x, label_y, label_x + label_width - 1, label_y + 4)


def _validate_layout(size: int, state: str, layout) -> None:
    label_bounds = []
    targets = []
    for label, side, lane, target_x_ratio, target_y_ratio in layout:
        bounds = _label_bounds(size, label, side, lane)
        if bounds[0] < 0 or bounds[1] < 0 or bounds[2] >= size or bounds[3] >= size:
            raise ValueError(f"{size}px {state} label {label!r} leaves the canvas")
        label_bounds.append((label, bounds))
        targets.append(
            (
                label,
                side,
                round(size * target_x_ratio),
                round(size * target_y_ratio),
            )
        )

    for index, (label, bounds) in enumerate(label_bounds):
        for other_label, other_bounds in label_bounds[index + 1 :]:
            overlaps = not (
                bounds[2] < other_bounds[0]
                or other_bounds[2] < bounds[0]
                or bounds[3] < other_bounds[1]
                or other_bounds[3] < bounds[1]
            )
            if overlaps:
                raise ValueError(
                    f"{size}px {state} labels {label!r} and {other_label!r} overlap"
                )

    for target_label, target_side, target_x, target_y in targets:
        target_pixels = (
            (target_x, target_y),
            (target_x, target_y - 1),
            (target_x, target_y + 1),
            (target_x - 1 if target_side == "left" else target_x + 1, target_y),
        )
        for label, bounds in label_bounds:
            if any(
                bounds[0] <= pixel_x <= bounds[2]
                and bounds[1] <= pixel_y <= bounds[3]
                for pixel_x, pixel_y in target_pixels
            ):
                raise ValueError(
                    f"{size}px {state} target {target_label!r} overlaps label {label!r}"
                )


def _draw_callout(
    draw,
    size: int,
    label: str,
    side: str,
    lane: float,
    target_x_ratio: float,
    target_y_ratio: float,
) -> None:
    label_width = _text_width(label)
    label_y = max(1, min(size - 6, round(size * lane) - 2))
    target_x = round(size * target_x_ratio)
    target_y = round(size * target_y_ratio)
    label_x = 2 if side == "left" else size - label_width - 2
    start_x = label_x + label_width + 1 if side == "left" else label_x - 2
    start_y = label_y + 2
    elbow_x = (
        max(start_x + 1, round(size * 0.22))
        if side == "left"
        else min(start_x - 1, round(size * 0.78))
    )

    _draw_pixel_text(draw, label, label_x, label_y)
    draw.line((start_x, start_y, elbow_x, start_y), fill=AUGMENTATION_LEADER)
    draw.line((elbow_x, start_y, target_x, target_y), fill=AUGMENTATION_LEADER)
    _draw_target(draw, target_x, target_y, side)


def _draw_state(size: int, state: str) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    inset = 1
    arm = max(3, round(size * 0.09))
    _draw_corner_brackets(
        draw, size, AUGMENTATION_FRAME, inset=inset, arm=arm, width=1
    )
    if size == 32:
        layout = COMPACT_LAYOUTS[state]
    elif size == 64:
        layout = MEDIUM_LAYOUTS[state]
    else:
        layout = FULL_LAYOUTS[state]
    _validate_layout(size, state, layout)
    for callout in layout:
        _draw_callout(draw, size, *callout)
    return image


def generate() -> None:
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        dmi = Dmi(size, size)
        for state in STATES:
            dmi.state(state).frame(_draw_state(size, state))
        dmi.to_file(OUTPUT_DIRECTORY / f"preview_decoration_{size}x{size}.dmi")


if __name__ == "__main__":
    generate()
