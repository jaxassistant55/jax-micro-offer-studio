#!/usr/bin/env python3
"""Verify the deterministic synthetic extraction outputs."""

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "sample" / "output"


def main() -> None:
    report = json.loads((OUTPUT / "report.json").read_text(encoding="utf-8"))
    rows = list(csv.DictReader((OUTPUT / "primitives.csv").open(encoding="utf-8")))
    geojson = json.loads((OUTPUT / "geometry.geojson").read_text(encoding="utf-8"))
    overlay = (OUTPUT / "overlay.svg").read_text(encoding="utf-8")

    assert report["pages"] == 1
    assert report["primitive_count"] == len(rows) == len(geojson["features"])
    assert report["primitive_count"] >= 12
    assert report["wall_candidate_count"] >= 6
    assert report["mm_per_pdf_point"] == 10.0
    assert report["longest_primitive_mm"] == 5000.0
    assert not report["warnings"]
    assert "<svg" in overlay and "5000.0 mm" in overlay
    print(
        f"verified primitives={report['primitive_count']} "
        f"wall_candidates={report['wall_candidate_count']} "
        f"longest_mm={report['longest_primitive_mm']}"
    )


if __name__ == "__main__":
    main()
