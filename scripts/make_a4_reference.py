#!/usr/bin/env python3
"""
make_a4_reference.py - build an A4 pandoc reference.docx.

Pandoc's built-in reference document is US Letter, but the assignment requires
A4 hard copy.  This takes pandoc's own default, rewrites the page-size and
margin records to A4, and writes build/reference-a4.docx for --reference-doc.

A4 is 210 x 297 mm = 11906 x 16838 twips (1 inch = 1440 twips).

Usage:  python3 -I scripts/make_a4_reference.py
"""

import os
import re
import shutil
import subprocess
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")
SRC = os.path.join(BUILD, "reference-default.docx")
DST = os.path.join(BUILD, "reference-a4.docx")

A4_W, A4_H = 11906, 16838
MARGIN = 1134          # 20 mm
GUTTER_TOP = 1134

os.makedirs(BUILD, exist_ok=True)

with open(SRC, "wb") as f:
    subprocess.run(["pandoc", "--print-default-data-file", "reference.docx"],
                   stdout=f, check=True)

zin = zipfile.ZipFile(SRC, "r")
if os.path.exists(DST):
    os.remove(DST)
zout = zipfile.ZipFile(DST, "w", zipfile.ZIP_DEFLATED)

patched = False
for item in zin.infolist():
    data = zin.read(item.filename)
    if item.filename == "word/document.xml":
        text = data.decode("utf-8")

        sect_body = (
            '<w:pgSz w:w="%d" w:h="%d"/>'
            '<w:pgMar w:top="%d" w:right="%d" w:bottom="%d" w:left="%d"'
            ' w:header="709" w:footer="709" w:gutter="0"/>'
            % (A4_W, A4_H, GUTTER_TOP, MARGIN, MARGIN, MARGIN))

        # pandoc ships an EMPTY <w:sectPr/>, so the page size is whatever the
        # renderer defaults to (US Letter under LibreOffice).  Fill it in.
        text, n = re.subn(r'<w:sectPr\s*/>',
                          '<w:sectPr>' + sect_body + '</w:sectPr>', text)
        if n == 0:
            # already populated - replace the size/margin records in place
            text, n1 = re.subn(r'<w:pgSz[^/]*/>',
                               '<w:pgSz w:w="%d" w:h="%d"/>' % (A4_W, A4_H),
                               text)
            text, _ = re.subn(r'<w:pgMar[^/]*/>', '', text)
            if n1 == 0:
                raise SystemExit(
                    "neither <w:sectPr/> nor <w:pgSz> found - "
                    "pandoc reference format changed")
        patched = True
        data = text.encode("utf-8")
    zout.writestr(item, data)

zin.close()
zout.close()

if not patched:
    raise SystemExit("word/document.xml not found in reference docx")

print("wrote %s (A4, %d x %d twips)" % (DST, A4_W, A4_H))
