#!/usr/bin/env python3
"""Convert a flat chroma-key equipment render into a clean RGBA PNG.

The imagegen workflow intentionally uses a solid key background.  This small
post-process keeps a hard matte (so pastel interiors are not eaten) and
replaces key-coloured anti-aliased edge pixels with nearby artwork colours.
"""

from __future__ import annotations

import argparse
from statistics import median
from pathlib import Path

from PIL import Image


def sample_border_key(image: Image.Image) -> tuple[int, int, int]:
    pixels = image.load()
    width, height = image.size
    band = max(1, min(width, height, 6))
    samples: list[tuple[int, int, int]] = []
    for x in range(0, width, max(1, min(width, height) // 256)):
        for y in range(band):
            samples.append(pixels[x, y][:3])
            samples.append(pixels[x, height - 1 - y][:3])
    for y in range(0, height, max(1, min(width, height) // 256)):
        for x in range(band):
            samples.append(pixels[x, y][:3])
            samples.append(pixels[width - 1 - x, y][:3])
    return tuple(int(round(median(channel))) for channel in zip(*samples))  # type: ignore[return-value]


def color_distance(rgb: tuple[int, int, int], key: tuple[int, int, int]) -> int:
    return max(abs(rgb[index] - key[index]) for index in range(3))


def key_dominance(rgb: tuple[int, int, int], key: tuple[int, int, int]) -> int:
    key_channel = max(range(3), key=lambda index: key[index])
    other_channels = [rgb[index] for index in range(3) if index != key_channel]
    return rgb[key_channel] - max(other_channels)


def looks_like_spill(rgb: tuple[int, int, int], key: tuple[int, int, int], threshold: int) -> bool:
    key_channel = max(range(3), key=lambda index: key[index])
    return rgb[key_channel] >= 150 and key_dominance(rgb, key) >= threshold


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Clean chroma-key edges on a generated item PNG.")
    parser.add_argument("--input", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--tolerance", type=int, default=28)
    parser.add_argument("--spill-threshold", type=int, default=55)
    parser.add_argument("--radius", type=int, default=3)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    out_path = Path(args.out)
    with Image.open(args.input) as source:
        source = source.convert("RGBA")
        width, height = source.size
        source_pixels = source.load()
        key = sample_border_key(source)
        alpha = [[0 if color_distance(source_pixels[x, y][:3], key) <= args.tolerance else 255 for x in range(width)] for y in range(height)]
        output = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        output_pixels = output.load()

        for y in range(height):
            for x in range(width):
                if alpha[y][x] == 0:
                    continue
                rgb = source_pixels[x, y][:3]
                if looks_like_spill(rgb, key, args.spill_threshold):
                    nearby: list[tuple[int, int, int]] = []
                    for distance in range(1, args.radius + 1):
                        for offset_y in range(-distance, distance + 1):
                            for offset_x in range(-distance, distance + 1):
                                if max(abs(offset_x), abs(offset_y)) != distance:
                                    continue
                                neighbor_x = x + offset_x
                                neighbor_y = y + offset_y
                                if not (0 <= neighbor_x < width and 0 <= neighbor_y < height):
                                    continue
                                if alpha[neighbor_y][neighbor_x] == 0:
                                    continue
                                neighbor_rgb = source_pixels[neighbor_x, neighbor_y][:3]
                                if not looks_like_spill(neighbor_rgb, key, args.spill_threshold):
                                    nearby.append(neighbor_rgb)
                        if nearby:
                            break
                    if nearby:
                        rgb = tuple(int(round(sum(color[index] for color in nearby) / len(nearby))) for index in range(3))  # type: ignore[assignment]
                    else:
                        key_channel = max(range(3), key=lambda index: key[index])
                        rgb_list = list(rgb)
                        rgb_list[key_channel] = min(rgb_list[key_channel], max(rgb_list[index] for index in range(3) if index != key_channel) + 8)
                        rgb = tuple(rgb_list)  # type: ignore[assignment]
                output_pixels[x, y] = (*rgb, 255)

        out_path.parent.mkdir(parents=True, exist_ok=True)
        output.save(out_path, format="PNG")
        print(f"Wrote {out_path}")
        print(f"Key color: #{key[0]:02x}{key[1]:02x}{key[2]:02x}")


if __name__ == "__main__":
    main()
