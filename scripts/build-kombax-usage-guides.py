"""Produce the web and PDF usage guides from one editable source."""
from __future__ import annotations

from pathlib import Path
import html
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "artifacts/guides-r100-1/usage-guides-source.json"
HTML_DIR = ROOT / "artifacts/guides-r100-1/usage-html"
PDF_DIR = ROOT / "web/assets/guides/usage"
WEB_INDEX = ROOT / "web/assets/guides/usage-guides.json"
CHROME = shutil.which("chrome") or r"C:\Program Files\Google\Chrome\Application\chrome.exe"

CSS = """
@page { size:A4; margin:18mm 17mm 19mm; }
@page cover { size:A4; margin:0; }
* { box-sizing:border-box; }
html { -webkit-print-color-adjust:exact; print-color-adjust:exact; }
body { margin:0; background:#fff; color:#25262d; font:10pt/1.56 "Segoe UI",Arial,sans-serif; }
.cover { page:cover; width:210mm; height:297mm; position:relative; overflow:hidden; color:#fff; background:#090a0d; break-after:page; }
.cover-photo { position:absolute; top:0; left:0; right:0; height:180mm; background-image:linear-gradient(180deg,rgba(7,8,10,.05),rgba(7,8,10,.3) 55%,#090a0d),url("../../../web/assets/brand-heroes/hero-guides.webp"); background-size:cover; background-position:center; }
.cover:after { content:""; position:absolute; inset:0 auto 0 0; width:4mm; background:#c41135; box-shadow:0 0 16mm #8d0a29; }
.brand { position:absolute; top:18mm; left:20mm; display:flex; align-items:center; gap:4mm; font-size:19pt; font-weight:800; letter-spacing:.18em; }
.brand img { width:15mm; height:15mm; object-fit:contain; }
.cover-copy { position:absolute; top:153mm; left:20mm; right:19mm; }
.kicker { font:700 8pt "Bahnschrift","Segoe UI",sans-serif; letter-spacing:.24em; color:#ff6d86; text-transform:uppercase; }
.cover h1 { color:#fff; font:700 33pt/1.07 Georgia,serif; letter-spacing:-.025em; margin:7mm 0 6mm; }
.cover p { color:#dde0e6; font-size:11pt; max-width:155mm; }
.cover-audience { position:absolute; bottom:25mm; left:20mm; right:20mm; border-top:1px solid #777; padding-top:5mm; font-size:8.5pt; color:#ccd0d7; }
.intro { break-after:page; padding-top:10mm; }
.intro h1 { font:700 27pt/1.15 Georgia,serif; margin:4mm 0 6mm; }
.intro p { color:#60646c; font-size:10.5pt; }
.contents { display:grid; grid-template-columns:1fr 1fr; gap:3mm 8mm; margin-top:10mm; }
.contents div { border-top:1px solid #d9dade; padding:3mm 0; font-weight:700; }
.contents span { display:block; color:#b91137; font-size:8pt; margin-bottom:1mm; }
.note { margin:8mm 0; padding:4mm 5mm; border-left:3px solid #be1236; background:#f8f3f5; }
.chapter { break-before:page; }
.chapter-head { border-bottom:2px solid #bb1234; padding-top:7mm; margin-bottom:9mm; }
.chapter-head span { color:#b01131; font:700 8pt "Bahnschrift","Segoe UI",sans-serif; letter-spacing:.18em; }
.chapter h2 { font:700 24pt/1.14 Georgia,serif; margin:3mm 0 6mm; }
.purpose { margin:0 0 8mm; color:#4b5260; font-size:10.5pt; line-height:1.52; }
.step { display:grid; grid-template-columns:10mm 1fr; gap:4mm; margin:0 0 6mm; break-inside:avoid; }
.step b { display:grid; place-items:center; width:8mm; height:8mm; border-radius:50%; background:#b70f32; color:#fff; font-size:8pt; }
.step p { margin:0; }
.chapter .note { font-size:9pt; color:#4c4f57; }
.example,.check { margin:5mm 0 0; padding:4mm 5mm; border:1px solid #e2e5ea; border-radius:3mm; break-inside:avoid; font-size:9pt; line-height:1.48; }
.example { background:#f5f7fa; }
.check { background:#f0f7f2; border-color:#cee4d4; }
.example b,.check b { display:block; margin-bottom:1mm; font:700 7.5pt "Bahnschrift","Segoe UI",sans-serif; letter-spacing:.13em; text-transform:uppercase; color:#a41332; }
.check b { color:#2e7850; }
.footer { margin-top:15mm; padding-top:4mm; border-top:1px solid #e2e2e5; font-size:8pt; color:#6f727a; }
@media screen { body { max-width:210mm; margin:0 auto; box-shadow:0 0 30px #aaa; } .intro,.chapter { padding:0 17mm 25mm; } }
"""

def build_one(guide, intro):
    gid = guide["id"]
    title = guide["title"]
    chapters = guide["chapters"]
    contents = "".join(
        f'<div><span>{i:02d}</span>{html.escape(ch["title"])}</div>'
        for i, ch in enumerate(chapters, 1)
    )
    sections = []
    for i, chapter in enumerate(chapters, 1):
        steps = "".join(
            f'<div class="step"><b>{j}</b><p>{html.escape(step)}</p></div>'
            for j, step in enumerate(chapter["steps"], 1)
        )
        sections.append(
            f'<section class="chapter"><header class="chapter-head"><span>CAPÍTULO {i:02d}</span>'
            f'<h2>{html.escape(chapter["title"])}</h2></header>'
            f'<p class="purpose">{html.escape(chapter.get("purpose", ""))}</p>{steps}'
            f'<div class="example"><b>Ejemplo habitual</b>{html.escape(chapter.get("example", ""))}</div>'
            f'<div class="check"><b>Comprueba al terminar</b>{html.escape(chapter.get("check", ""))}</div>'
            f'<div class="note">{html.escape(chapter["note"])}</div></section>'
        )
    page = (
        '<!doctype html><html lang="es"><head><meta charset="utf-8"><title>'
        + html.escape(title) + '</title><style>' + CSS + '</style></head><body>'
        + '<section class="cover"><div class="cover-photo"></div>'
        + '<div class="brand"><img src="../../../web/assets/brand/kombax-symbol-red.png" alt="">KOMBAX</div>'
        + f'<div class="cover-copy"><span class="kicker">Guía de uso</span><h1>{html.escape(title)}</h1>'
        + f'<p>{html.escape(guide["lead"])}</p></div>'
        + f'<div class="cover-audience">Para {html.escape(guide["audience"])}</div></section>'
        + f'<section class="intro"><span class="kicker">Tu recorrido</span><h1>{html.escape(title)}</h1>'
        + f'<p>{html.escape(guide["lead"])}</p><div class="contents">{contents}</div>'
        + f'<div class="note">{html.escape(intro)}</div></section>'
        + "".join(sections)
        + '</body></html>'
    )
    HTML_DIR.mkdir(parents=True, exist_ok=True)
    PDF_DIR.mkdir(parents=True, exist_ok=True)
    hp = HTML_DIR / f"KOMBAX_USO_{gid.upper()}.html"
    pp = PDF_DIR / f"KOMBAX_USO_{gid.upper()}.pdf"
    hp.write_text(page, encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="kx-usage-chrome-") as profile:
        cmd = [CHROME, "--headless=old", "--no-sandbox", "--disable-gpu", "--disable-software-rasterizer",
               "--disable-dev-shm-usage", "--no-first-run", "--no-pdf-header-footer",
               f"--user-data-dir={profile}", f"--print-to-pdf={pp}", hp.as_uri()]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode or not pp.exists() or pp.stat().st_size < 10000:
            raise RuntimeError(f"PDF failed for {gid}: {result.stderr[-1000:]}")
    return {**guide, "pdf": f"./assets/guides/usage/{pp.name}"}

def main():
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    guides = [build_one(g, source["intro"]) for g in source["guides"]]
    assert len({g["id"] for g in guides}) == len(guides)
    WEB_INDEX.write_text(json.dumps({"brand": "KOMBAX", "intro": source["intro"], "guides": guides},
                                    ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("usage guides", len(guides))

if __name__ == "__main__":
    main()
