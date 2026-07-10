# Vector PDF Takeoff Feasibility Sample

This is a bounded technical proof for extracting auditable vector primitives from architectural PDFs.

It generates a synthetic vector-only floor plan, extracts line/rectangle/Bezier primitives with PyMuPDF, converts calibrated lengths to millimetres, and writes:

- `primitives.csv`
- `geometry.geojson`
- `overlay.svg`
- `report.json`

Run:

```bash
python3 make_synthetic_plan.py
python3 extract_vector_pdf.py sample/synthetic_floor_plan.pdf sample/output --mm-per-point 10
python3 verify_sample.py
```

Scope boundary: this proves primitive extraction and coordinate traceability. It is not certified quantity surveying, automatic wall/opening recognition, raster OCR, production IFC support, or a guarantee that arbitrary drawings are measurable. Drawings marked NTS require a separate trusted calibration source and should not be treated as measured geometry.
