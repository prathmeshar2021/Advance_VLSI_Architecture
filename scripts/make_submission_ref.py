#!/usr/bin/env python3
"""
make_submission_ref.py - build build/reference-submission.docx :
an A4 Word template with plain black serif headings, a serif body and small
monospaced code, so the rendered report looks like an ordinary typed document
rather than a pandoc default.

Usage:  python3 -I scripts/make_submission_ref.py
"""

import os
import re
import subprocess
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")
SRC = os.path.join(BUILD, "ref-default.docx")
DST = os.path.join(BUILD, "reference-submission.docx")

A4_W, A4_H = 11906, 16838
MARGIN = 1134          # 20 mm

BODY_FONT = "Times New Roman"
CODE_FONT = "Consolas"

os.makedirs(BUILD, exist_ok=True)
with open(SRC, "wb") as f:
    subprocess.run(["pandoc", "--print-default-data-file", "reference.docx"],
                   stdout=f, check=True)

SOURCECODE_STYLE = (
    '<w:style w:type="paragraph" w:styleId="SourceCode">'
    '<w:name w:val="Source Code"/>'
    '<w:basedOn w:val="Normal"/>'
    '<w:pPr><w:spacing w:before="0" w:after="0" w:line="200" w:lineRule="auto"/></w:pPr>'
    '<w:rPr><w:rFonts w:ascii="%s" w:hAnsi="%s" w:cs="%s"/>'
    '<w:sz w:val="16"/><w:szCs w:val="16"/></w:rPr>'
    '</w:style>' % (CODE_FONT, CODE_FONT, CODE_FONT)
)


def patch_styles(text):
    # body + heading fonts -> serif (replace theme font references)
    text = re.sub(r'w:asciiTheme="[^"]*"', 'w:ascii="%s"' % BODY_FONT, text)
    text = re.sub(r'w:hAnsiTheme="[^"]*"', 'w:hAnsi="%s"' % BODY_FONT, text)
    text = re.sub(r'w:cstheme="[^"]*"', 'w:cs="%s"' % BODY_FONT, text)
    text = re.sub(r'w:eastAsiaTheme="[^"]*"', 'w:eastAsia="%s"' % BODY_FONT, text)

    # blue heading colours -> black
    for blue in ("345A8A", "365F91", "4F81BD"):
        text = text.replace('w:val="%s"' % blue, 'w:val="000000"')

    # body default 12pt -> 11pt
    text = text.replace('<w:sz w:val="24" />', '<w:sz w:val="22" />')
    text = text.replace('<w:szCs w:val="24" />', '<w:szCs w:val="22" />')

    # code font stays monospaced: undo the serif substitution for the two
    # verbatim styles, and shrink them to 8pt
    def fix_verbatim(m):
        blk = m.group(0)
        blk = blk.replace('w:ascii="%s"' % BODY_FONT, 'w:ascii="%s"' % CODE_FONT)
        blk = blk.replace('w:hAnsi="%s"' % BODY_FONT, 'w:hAnsi="%s"' % CODE_FONT)
        blk = blk.replace('w:cs="%s"' % BODY_FONT, 'w:cs="%s"' % CODE_FONT)
        blk = blk.replace('<w:sz w:val="22"', '<w:sz w:val="16"')
        blk = blk.replace('<w:szCs w:val="22"', '<w:szCs w:val="16"')
        return blk

    text = re.sub(r'<w:style [^>]*w:styleId="VerbatimChar".*?</w:style>',
                  fix_verbatim, text, flags=re.S)
    text = re.sub(r'<w:style [^>]*w:styleId="BodyTextChar".*?</w:style>',
                  fix_verbatim, text, flags=re.S)

    # add a Source Code paragraph style for code blocks
    text = text.replace('</w:styles>', SOURCECODE_STYLE + '</w:styles>')
    return text


def patch_document(text):
    sect = ('<w:pgSz w:w="%d" w:h="%d"/>'
            '<w:pgMar w:top="%d" w:right="%d" w:bottom="%d" w:left="%d"'
            ' w:header="709" w:footer="709" w:gutter="0"/>'
            % (A4_W, A4_H, MARGIN, MARGIN, MARGIN, MARGIN))
    new, n = re.subn(r'<w:sectPr\s*/>', '<w:sectPr>' + sect + '</w:sectPr>', text)
    if n == 0:
        raise SystemExit("empty <w:sectPr/> not found in reference document")
    return new


zin = zipfile.ZipFile(SRC, "r")
if os.path.exists(DST):
    os.remove(DST)
zout = zipfile.ZipFile(DST, "w", zipfile.ZIP_DEFLATED)
for item in zin.infolist():
    data = zin.read(item.filename)
    if item.filename == "word/styles.xml":
        data = patch_styles(data.decode("utf-8")).encode("utf-8")
    elif item.filename == "word/document.xml":
        data = patch_document(data.decode("utf-8")).encode("utf-8")
    zout.writestr(item, data)
zin.close()
zout.close()
print("wrote %s" % DST)
