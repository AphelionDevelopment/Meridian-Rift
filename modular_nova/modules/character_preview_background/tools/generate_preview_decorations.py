"""Generate exact-size transparent MeridianOS preview-decoration DMIs.

Run from the repository root with:
    tools/bootstrap/python modular_nova/modules/character_preview_background/tools/generate_preview_decorations.py
"""

from pathlib import Path
import sys

from PIL import Image, ImageDraw


REPOSITORY_ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPOSITORY_ROOT))

from tools.dmi import Dmi  # noqa: E402


OUTPUT_DIRECTORY = Path(__file__).resolve().parents[1] / "icons"
SIZES = (32, 64, 96)
STANDARD_PRIMARY = (88, 209, 201, 218)
STANDARD_SECONDARY = (159, 178, 188, 190)
AUGMENTATION_FRAME = (240, 68, 89, 224)
AUGMENTATION_READOUT = (0, 229, 212, 232)

PIXEL_FONT = {
    "C": ("111", "100", "100", "100", "111"),
    "E": ("111", "100", "110", "100", "111"),
    "L": ("100", "100", "100", "100", "111"),
    "O": ("111", "101", "101", "101", "111"),
    "P": ("110", "101", "110", "100", "100"),
    "R": ("110", "101", "110", "101", "101"),
    "U": ("101", "101", "101", "101", "111"),
    "W": ("101", "101", "101", "111", "101"),
}


def _line_width(size: int) -> int:
    return 1 if size < 96 else 2


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


def _draw_standard(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    width = _line_width(size)
    inset = max(1, size // 32)
    arm = max(3, size // 8)
    center = size // 2
    _draw_corner_brackets(
        draw, size, STANDARD_PRIMARY, inset=inset, arm=arm, width=width
    )

    tick = max(2, size // 16)
    for points in (
        (center, inset, center, inset + tick),
        (center, size - inset - tick - 1, center, size - inset - 1),
        (inset, center, inset + tick, center),
        (size - inset - tick - 1, center, size - inset - 1, center),
    ):
        draw.line(points, fill=STANDARD_SECONDARY, width=width)

    leader = max(5, size // 5)
    upper_y = size // 3
    lower_y = (size * 2) // 3
    draw.line((0, upper_y, leader, upper_y), fill=STANDARD_SECONDARY, width=width)
    draw.rectangle(
        (leader, upper_y - width, leader + width, upper_y + width),
        fill=STANDARD_PRIMARY,
    )
    draw.line(
        (size - leader - 1, lower_y, size - 1, lower_y),
        fill=STANDARD_SECONDARY,
        width=width,
    )
    draw.rectangle(
        (size - leader - width - 1, lower_y - width, size - leader - 1, lower_y + width),
        fill=STANDARD_PRIMARY,
    )

    gap = max(2, size // 24)
    mark = max(2, size // 18)
    for points in (
        (center, center - gap - mark, center, center - gap),
        (center, center + gap, center, center + gap + mark),
        (center - gap - mark, center, center - gap, center),
        (center + gap, center, center + gap + mark, center),
    ):
        draw.line(points, fill=STANDARD_PRIMARY, width=width)
    draw.point((center, center), fill=STANDARD_SECONDARY)
    return image


def _draw_pixel_text(draw, text, x, y, color, *, scale):
    cursor = x
    for character in text:
        for row, pixels in enumerate(PIXEL_FONT[character]):
            for column, pixel in enumerate(pixels):
                if pixel == "1":
                    draw.rectangle(
                        (
                            cursor + column * scale,
                            y + row * scale,
                            cursor + (column + 1) * scale - 1,
                            y + (row + 1) * scale - 1,
                        ),
                        fill=color,
                    )
        cursor += 4 * scale


def _draw_augmentation(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    width = _line_width(size)
    inset = max(1, size // 32)
    arm = max(4, size // 7)
    center = size // 2
    _draw_corner_brackets(
        draw, size, AUGMENTATION_FRAME, inset=inset, arm=arm, width=width
    )

    cut = max(3, size // 12)
    draw.line(
        (inset + arm, inset, inset + arm + cut, inset + cut),
        fill=AUGMENTATION_FRAME,
        width=width,
    )
    draw.line(
        (size - inset - arm - cut - 1, size - inset - cut - 1,
         size - inset - arm - 1, size - inset - 1),
        fill=AUGMENTATION_FRAME,
        width=width,
    )

    dash = max(2, size // 16)
    axis_y = inset + 2
    while axis_y < size - inset - 1:
        draw.line(
            (center, axis_y, center, min(axis_y + dash - 1, size - inset - 1)),
            fill=AUGMENTATION_READOUT,
            width=width,
        )
        axis_y += dash * 2

    socket = max(1, size // 32)
    leader = max(4, size // 7)
    for index, zone_y in enumerate((size // 5, size // 2, (size * 4) // 5)):
        color = AUGMENTATION_READOUT if index == 1 else AUGMENTATION_FRAME
        draw.rectangle(
            (inset, zone_y - socket, inset + socket * 2, zone_y + socket),
            outline=color,
            width=width,
        )
        draw.rectangle(
            (size - inset - socket * 2 - 1, zone_y - socket,
             size - inset - 1, zone_y + socket),
            outline=color,
            width=width,
        )
        draw.line(
            (inset + socket * 2 + 1, zone_y, leader, zone_y),
            fill=color,
            width=width,
        )
        draw.line(
            (size - leader - 1, zone_y, size - inset - socket * 2 - 2, zone_y),
            fill=color,
            width=width,
        )

    scale = 1 if size < 96 else 2
    labels = (
        ("UPPER", 2),
        ("CORE", center - 5 * scale - max(2, size // 32)),
        ("LOWER", size - 5 * scale - 2),
    )
    for label, label_y in labels:
        label_width = (len(label) * 4 - 1) * scale
        label_x = max(inset + 3, center - label_width // 2)
        _draw_pixel_text(
            draw, label, label_x, label_y, AUGMENTATION_READOUT, scale=scale
        )

    radius = max(2, size // 24)
    draw.rectangle(
        (center - radius, center - radius, center + radius, center + radius),
        outline=AUGMENTATION_FRAME,
        width=width,
    )
    draw.point((center, center), fill=AUGMENTATION_READOUT)
    return image


def generate() -> None:
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        dmi = Dmi(size, size)
        dmi.state("standard").frame(_draw_standard(size))
        dmi.state("augmentation").frame(_draw_augmentation(size))
        dmi.to_file(OUTPUT_DIRECTORY / f"preview_decoration_{size}x{size}.dmi")


if __name__ == "__main__":
    generate()
