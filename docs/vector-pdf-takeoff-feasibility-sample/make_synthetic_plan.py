#!/usr/bin/env python3
"""Create a small vector-only floor plan for deterministic extraction tests."""

from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas


MM_PER_POINT = 10.0


def build(output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    pdf = canvas.Canvas(str(output), pagesize=A4)
    width, height = A4

    pdf.setTitle("Synthetic vector floor plan")
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(48, height - 42, "Synthetic vector floor plan - scale proof sample")
    pdf.setFont("Helvetica", 8)
    pdf.drawString(48, height - 56, "Declared calibration: 1 PDF point = 10 mm")

    left = 48
    right = 548
    bottom = 220
    top = 620
    split = 310

    pdf.setLineWidth(1.1)
    # Exterior wall centerlines with a 40 point door gap on the lower wall.
    pdf.line(left, bottom, 270, bottom)
    pdf.line(310, bottom, right, bottom)
    pdf.line(left, top, right, top)
    pdf.line(left, bottom, left, top)
    pdf.line(right, bottom, right, top)

    # Interior wall with a 50 point opening.
    pdf.line(split, bottom, split, 390)
    pdf.line(split, 440, split, top)

    # Window symbol on the upper wall.
    pdf.setLineWidth(0.6)
    pdf.line(180, top - 4, 250, top - 4)
    pdf.line(180, top + 4, 250, top + 4)

    # Door swing arc represented by a Bezier curve.
    path = pdf.beginPath()
    path.moveTo(270, bottom)
    path.curveTo(270, 245, 285, 260, 310, 260)
    pdf.drawPath(path, stroke=1, fill=0)

    # Calibration bar: exactly 500 points = 5000 mm.
    calibration_y = 160
    pdf.setLineWidth(0.8)
    pdf.line(left, calibration_y, right, calibration_y)
    pdf.line(left, calibration_y - 5, left, calibration_y + 5)
    pdf.line(right, calibration_y - 5, right, calibration_y + 5)
    pdf.setFont("Helvetica", 9)
    pdf.drawCentredString((left + right) / 2, calibration_y + 10, "5000 mm reference")

    pdf.setFont("Helvetica", 8)
    pdf.drawString(48, 120, "Vector-only synthetic input. Not a real building drawing or certified measurement.")
    pdf.drawString(48, 108, f"Expected calibration: {MM_PER_POINT:.1f} mm per PDF point.")
    pdf.save()


if __name__ == "__main__":
    build(Path(__file__).resolve().parent / "sample" / "synthetic_floor_plan.pdf")
