#!/bin/sh
# ---------------------------------------------------------------------------
# make_pdf.sh - render the report to DOCX and PDF for hard-copy submission.
#
# Requires pandoc and LibreOffice (used as the PDF engine, so no LaTeX
# installation is needed).  Output is A4, as the submission guidelines
# require - pandoc's stock reference document is US Letter, so an A4 one is
# generated first.
#
#   sh scripts/make_pdf.sh
#
# Produces, in docs/ :
#   REPORT.docx       full report, editable - fill in name and ID, then print
#   REPORT.pdf        full report including all Verilog listings
#   REPORT_body.pdf   report without the source-code appendix, for reading
# ---------------------------------------------------------------------------
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

mkdir -p build

echo "assembling docs/REPORT.md ..."
python3 -I scripts/make_report.py

echo "building A4 reference document ..."
python3 -I scripts/make_a4_reference.py

REF=build/reference-a4.docx

echo "pandoc -> docx ..."
pandoc docs/REPORT.md      -o build/REPORT.docx      --reference-doc="$REF"
pandoc docs/report_body.md -o build/REPORT_body.docx --reference-doc="$REF"

echo "libreoffice -> pdf ..."
soffice --headless --convert-to pdf build/REPORT.docx      --outdir build >/dev/null 2>&1
soffice --headless --convert-to pdf build/REPORT_body.docx --outdir build >/dev/null 2>&1

cp build/REPORT.docx     docs/REPORT.docx
cp build/REPORT.pdf      docs/REPORT.pdf
cp build/REPORT_body.pdf docs/REPORT_body.pdf

echo ""
echo "written:"
ls -la docs/REPORT.docx docs/REPORT.pdf docs/REPORT_body.pdf
