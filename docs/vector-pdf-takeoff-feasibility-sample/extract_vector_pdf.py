#!/usr/bin/env python3
"""Extract auditable vector primitives from a PDF into CSV, GeoJSON, and SVG."""

from __future__ import annotations

import argparse
import csv
import html
import json
import math
from pathlib import Path
from typing import Iterable

import fitz


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(b[0] - a[0], b[1] - a[1])


def cubic_point(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    p3: tuple[float, float],
    t: float,
) -> tuple[float, float]:
    u = 1.0 - t
    return (
        u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
        u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1],
    )


def polyline_length(points: Iterable[tuple[float, float]]) -> float:
    values = list(points)
    return sum(distance(a, b) for a, b in zip(values, values[1:]))


def point(value: object) -> tuple[float, float]:
    return (float(value.x), float(value.y))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_pdf", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--mm-per-point", type=float, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.mm_per_point <= 0:
        raise SystemExit("--mm-per-point must be positive")

    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    document = fitz.open(args.input_pdf)
    rows: list[dict[str, object]] = []
    features: list[dict[str, object]] = []
    svg_pages: list[str] = []
    warnings: list[str] = []
    primitive_id = 0

    for page_index, page in enumerate(document):
        page_text = page.get_text("text").upper()
        if "NOT TO SCALE" in page_text or " NTS" in page_text:
            warnings.append(f"page {page_index + 1}: NTS marker detected; calibrated measurement blocked")

        page_width = float(page.rect.width)
        page_height = float(page.rect.height)
        svg_parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {page_width:.3f} {page_height:.3f}">',
            '<rect width="100%" height="100%" fill="white"/>',
        ]

        for drawing in page.get_drawings():
            stroke_width = float(drawing.get("width") or 0.0)
            stroke_color = drawing.get("color") or (0.1, 0.1, 0.1)
            red, green, blue = [max(0, min(255, round(float(channel) * 255))) for channel in stroke_color]
            svg_color = f"rgb({red},{green},{blue})"

            for item in drawing.get("items", []):
                kind = item[0]
                paths: list[tuple[str, list[tuple[float, float]]]] = []
                if kind == "l":
                    paths.append(("line", [point(item[1]), point(item[2])]))
                elif kind == "re":
                    rect = item[1]
                    paths.append(
                        (
                            "rectangle",
                            [
                                (float(rect.x0), float(rect.y0)),
                                (float(rect.x1), float(rect.y0)),
                                (float(rect.x1), float(rect.y1)),
                                (float(rect.x0), float(rect.y1)),
                                (float(rect.x0), float(rect.y0)),
                            ],
                        )
                    )
                elif kind == "c":
                    controls = [point(value) for value in item[1:5]]
                    paths.append(
                        (
                            "cubic_bezier",
                            [cubic_point(*controls, index / 16.0) for index in range(17)],
                        )
                    )
                else:
                    warnings.append(f"page {page_index + 1}: unsupported primitive {kind!r}")
                    continue

                for primitive_type, points in paths:
                    primitive_id += 1
                    length_pt = polyline_length(points)
                    length_mm = length_pt * args.mm_per_point
                    classification = "wall_candidate" if length_mm >= 1_000 else "detail_candidate"
                    row = {
                        "primitive_id": primitive_id,
                        "page": page_index + 1,
                        "type": primitive_type,
                        "point_count": len(points),
                        "x1_pt": round(points[0][0], 4),
                        "y1_pt": round(points[0][1], 4),
                        "x2_pt": round(points[-1][0], 4),
                        "y2_pt": round(points[-1][1], 4),
                        "length_pt": round(length_pt, 4),
                        "length_mm": round(length_mm, 2),
                        "stroke_width_pt": round(stroke_width, 4),
                        "classification": classification,
                    }
                    rows.append(row)

                    mm_coordinates = [
                        [round(x * args.mm_per_point, 3), round((page_height - y) * args.mm_per_point, 3)]
                        for x, y in points
                    ]
                    features.append(
                        {
                            "type": "Feature",
                            "properties": row,
                            "geometry": {"type": "LineString", "coordinates": mm_coordinates},
                        }
                    )

                    svg_points = " ".join(f"{x:.3f},{y:.3f}" for x, y in points)
                    svg_parts.append(
                        f'<polyline points="{svg_points}" fill="none" stroke="{svg_color}" '
                        f'stroke-width="{max(stroke_width, 0.5):.3f}" data-id="{primitive_id}"/>'
                    )
                    label_x = sum(value[0] for value in points) / len(points)
                    label_y = sum(value[1] for value in points) / len(points)
                    dx = points[-1][0] - points[0][0]
                    dy = points[-1][1] - points[0][1]
                    if abs(dx) >= abs(dy):
                        label_y -= 5 + (primitive_id % 3) * 7
                    else:
                        label_x += 5 + (primitive_id % 2) * 8
                    label_x = max(4.0, min(page_width - 70.0, label_x))
                    label_y = max(10.0, min(page_height - 4.0, label_y))
                    svg_parts.append(
                        f'<text x="{label_x:.3f}" y="{label_y:.3f}" font-size="7" fill="#075da8" '
                        f'paint-order="stroke" stroke="white" stroke-width="2">'
                        f'{primitive_id}: {html.escape(str(round(length_mm, 1)))} mm</text>'
                    )

        svg_parts.append("</svg>")
        svg_pages.append("\n".join(svg_parts))

    fieldnames = list(rows[0].keys()) if rows else []
    with (output_dir / "primitives.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    geojson = {
        "type": "FeatureCollection",
        "properties": {
            "source": args.input_pdf.name,
            "coordinate_units": "mm",
            "origin": "bottom-left",
            "mm_per_pdf_point": args.mm_per_point,
        },
        "features": features,
    }
    (output_dir / "geometry.geojson").write_text(json.dumps(geojson, indent=2), encoding="utf-8")
    (output_dir / "overlay.svg").write_text("\n".join(svg_pages), encoding="utf-8")

    report = {
        "source": str(args.input_pdf),
        "pages": len(document),
        "primitive_count": len(rows),
        "wall_candidate_count": sum(row["classification"] == "wall_candidate" for row in rows),
        "mm_per_pdf_point": args.mm_per_point,
        "longest_primitive_mm": max((float(row["length_mm"]) for row in rows), default=0.0),
        "warnings": warnings,
        "scope_boundary": "Primitive extraction proof only; not certified takeoff, wall/opening recognition, or IFC production support.",
    }
    (output_dir / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
