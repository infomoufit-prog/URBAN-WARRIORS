"""Rebuild the public KOMBAX knowledge collection from the R100.1 source HTML.

The original source documents stay archived; this script produces three reader
facing volumes without their repeated covers, indexes and production footers.
"""
from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import html as pyhtml
import json
import re
import shutil
import subprocess
import tempfile

from lxml import html

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "web/assets/guides/runtime-index.json"
HTML_DIR = ROOT / "artifacts/guides-r100-1/collections"
PDF_DIR = ROOT / "web/assets/guides/collections"
CHROME = shutil.which("chrome") or r"C:\Program Files\Google\Chrome\Application\chrome.exe"

GROUPS = [
    {
        "id": "club",
        "title": "Poner en marcha y dirigir un club",
        "subtitle": "De la constitución al cuidado diario de las personas y los documentos.",
        "audience": "Clubes, escuelas y equipos de gestión",
        "codes": ["a1", "a2", "a5", "b1", "b2", "b3"],
        "hero": "hero-guides.webp",
    },
    {
        "id": "federacion",
        "title": "Federaciones, licencias e interclubs",
        "subtitle": "Oficialidad, participación y encuentros entre clubes en una sola guía.",
        "audience": "Clubes, federaciones, participantes y organizadores",
        "codes": ["a3", "a4", "c2", "c4", "c7"],
        "hero": "hero-events.webp",
    },
    {
        "id": "eventos",
        "title": "Organizar un evento de principio a fin",
        "subtitle": "Preparación, seguridad, público, colaboradores y cierre del evento.",
        "audience": "Clubes, promotores y equipos de organización",
        "codes": ["c1", "c3", "c5", "c6", "c8", "d1", "d2"],
        "hero": "hero-events.webp",
    },
]
TOPIC_LABELS = {
    "A1": "creación del club", "A2": "vida anual del club", "A3": "oficialidad",
    "A4": "licencias", "A5": "personal del club", "B1": "menores",
    "B2": "datos e imagen", "B3": "seguros", "C1": "planificación del evento",
    "C2": "interclubs", "C3": "recinto y autorizaciones", "C4": "participantes",
    "C5": "salud y seguridad", "C6": "entradas", "C7": "deportistas extranjeros",
    "C8": "patrocinio", "D1": "expediente del organizador", "D2": "cierre del evento",
}

CSS = """
@page { size:A4; margin:18mm 17mm 18mm; }
@page cover { size:A4; margin:0; }
* { box-sizing:border-box; }
html { -webkit-print-color-adjust:exact; print-color-adjust:exact; }
body { margin:0; color:#23242a; background:#fff; font:9.5pt/1.58 "Segoe UI",Arial,sans-serif; }
.cover { page:cover; width:210mm; height:297mm; position:relative; overflow:hidden; color:#fff; background:#090a0e; break-after:page; }
.cover-photo { position:absolute; inset:0 0 auto; height:175mm; background-image:linear-gradient(180deg,rgba(5,6,9,.08),rgba(5,6,9,.38) 52%,#090a0e),var(--hero); background-size:cover; background-position:center 25%; }
.cover:after { content:""; position:absolute; left:0; top:0; width:4mm; height:100%; background:#c51235; box-shadow:0 0 17mm #a20b2e; }
.cover-brand { position:absolute; top:18mm; left:20mm; right:19mm; display:flex; align-items:center; gap:4mm; font-size:20pt; font-weight:800; letter-spacing:.18em; }
.cover-brand img { width:15mm; height:15mm; object-fit:contain; }
.cover-copy { position:absolute; top:151mm; left:20mm; right:20mm; }
.cover-kicker { color:#ff6c86; font:700 9pt/1.2 "Bahnschrift","Segoe UI",sans-serif; letter-spacing:.25em; text-transform:uppercase; }
.cover h1 { color:#fff; font:700 34pt/1.06 Georgia,serif; letter-spacing:-.035em; margin:7mm 0 5mm; max-width:172mm; }
.cover-copy p { color:#d9dce3; font-size:11pt; line-height:1.5; max-width:155mm; margin:0; }
.cover-audience { position:absolute; left:20mm; right:20mm; bottom:27mm; padding-top:5mm; border-top:1px solid #74767c; font-size:8pt; color:#d9dce3; }
.cover-foot { position:absolute; left:20mm; right:20mm; bottom:12mm; color:#9fa5af; font-size:7pt; }
.intro { break-after:page; padding-top:9mm; }
.eyebrow,.chapter-label { color:#ae1232; font:700 8pt "Bahnschrift","Segoe UI",sans-serif; letter-spacing:.18em; text-transform:uppercase; }
h1,h2,h3 { color:#25252c; break-after:avoid; page-break-after:avoid; }
.intro h1,.chapter-title { font:700 28pt/1.12 Georgia,serif; letter-spacing:-.025em; margin:4mm 0 7mm; }
.intro .lead { font-size:11pt; color:#535760; max-width:160mm; }
.contents { margin-top:12mm; display:grid; grid-template-columns:1fr 1fr; gap:3mm 8mm; }
.contents a { display:block; border-top:1px solid #dadde2; padding:3mm 0; color:#25252c; text-decoration:none; font-weight:700; }
.contents span { display:block; color:#b20c31; font-size:8pt; letter-spacing:.1em; margin-bottom:1mm; }
.reader-note { margin-top:13mm; border-left:3px solid #bd1135; padding:4mm 5mm; background:#f6f3f4; color:#535760; font-size:8.5pt; }
.chapter { break-before:page; }
.chapter-head { break-after:avoid; page-break-after:avoid; margin:0 0 9mm; padding-top:6mm; border-bottom:2px solid #bb1134; }
.chapter-deck { font-size:10pt; color:#676b73; margin:0 0 5mm; }
.chapter h3 { font:700 15pt/1.2 Georgia,serif; margin:8mm 0 3mm; }
.chapter h4 { font:700 11pt/1.2 "Segoe UI",sans-serif; margin:5mm 0 2mm; }
p { margin:0 0 3mm; }
a { color:#a60d2d; word-break:break-word; }
ul,ol { padding-left:6mm; margin:0 0 4mm; }
li { margin:1mm 0; }
table { border-collapse:collapse; width:100%; font-size:8pt; margin:3mm 0 5mm; }
tr { break-inside:avoid; page-break-inside:avoid; }
th { color:#fff; background:#292a31; text-align:left; padding:2.2mm; }
td { padding:2mm; border-bottom:1px solid #dfe1e5; vertical-align:top; }
tr:nth-child(even) td { background:#faf8f9; }
blockquote { margin:4mm 0; border-left:3px solid #c31437; padding:3mm 4mm; background:#fff2f5; break-inside:avoid; }
.tag { display:inline-block; padding:.3mm 1.3mm; border-radius:2px; color:#fff; background:#6a3d4b; font-size:7pt; font-weight:700; }
.tag.legal { background:#aa0d2d; }.tag.adm { background:#245178; }.tag.fed { background:#6a42a0; }
.tag.rec { background:#a45b09; }.tag.bp { background:#277444; }.tag.kx { background:#30333a; }.tag.prof { background:#896906; }
.pending { background:#fff1c2; padding:0 1mm; font-weight:700; }
.source-note { border-top:1px solid #e0e0e4; margin-top:7mm; padding-top:3mm; color:#686d76; font-size:8pt; }
@media screen { body { max-width:210mm; margin:0 auto; box-shadow:0 0 32px #bbb; } .chapter,.intro { padding:0 17mm 20mm; } }
"""

def cleaned_body(path: Path):
    doc = html.parse(str(path))
    body = doc.xpath("//body")[0]
    elements = []
    for node in list(body):
        if node.tag == "section" and node.get("class") in {"cover", "toc"}:
            continue
        if node.tag == "hr":
            continue
        if node.tag == "p" and "KOMBAX Guías ·" in node.text_content():
            continue
        copied = deepcopy(node)
        if copied.tag == "h2":
            copied.tag = "h3"
        for child in copied.iter():
            if child.text:
                child.text = reader_copy(child.text)
            if child.tail:
                child.tail = reader_copy(child.tail)
        elements.append(html.tostring(copied, encoding="unicode", method="html"))
    return "".join(elements)

def reader_copy(value: str) -> str:
    value = re.sub(r"\bficha T\b", "ficha territorial", value, flags=re.I)
    return re.sub(r"\b(?:A[1-5]|B[1-3]|C[1-8]|D[1-2])\b",
                  lambda match: f"«{TOPIC_LABELS[match.group()]}»", value)

def render(group, entries):
    chapters = [entries[code] for code in group["codes"]]
    page_title = group["title"]
    hero = f"../../../web/assets/brand-heroes/{group['hero']}"
    symbol = "../../../web/assets/brand/kombax-symbol-red.png"
    toc = "".join(f'<a href="#chapter-{i}"><span>{i:02d}</span>{pyhtml.escape(x["title"])}</a>' for i, x in enumerate(chapters, 1))
    parts = []
    for i, entry in enumerate(chapters, 1):
        source = ROOT / "artifacts/guides-r100-1/_build" / Path(entry["pdf"]).with_suffix(".html").name
        content = cleaned_body(source)
        parts.append(
            f'<section class="chapter" id="chapter-{i}"><header class="chapter-head"><span class="chapter-label">Tema {i:02d}</span>'
            f'<h2 class="chapter-title">{pyhtml.escape(entry["title"])}</h2><p class="chapter-deck">{pyhtml.escape(entry.get("subtitle", ""))}</p></header>'
            f'{content}</section>'
        )
    page = (
        '<!doctype html><html lang="es"><head><meta charset="utf-8"><title>'
        + pyhtml.escape(page_title)
        + '</title><style>' + CSS + '</style></head><body>'
        + f'<section class="cover" style="--hero:url(\'{hero}\')"><div class="cover-photo"></div>'
        + f'<div class="cover-brand"><img src="{symbol}" alt="">KOMBAX</div><div class="cover-copy">'
        + f'<span class="cover-kicker">Guías de conocimiento</span><h1>{pyhtml.escape(page_title)}</h1>'
        + f'<p>{pyhtml.escape(group["subtitle"])}</p></div><div class="cover-audience">Para {pyhtml.escape(group["audience"])}</div>'
        + '<div class="cover-foot">Información general. Antes de actuar, confirma las condiciones vigentes en la fuente competente.</div></section>'
        + f'<section class="intro"><span class="eyebrow">Tu recorrido</span><h1>{pyhtml.escape(page_title)}</h1>'
        + f'<p class="lead">{pyhtml.escape(group["subtitle"])} Cada tema mantiene sus fuentes y supuestos concretos.</p>'
        + f'<div class="contents">{toc}</div><p class="reader-note"><strong>Cómo usar esta guía.</strong> Empieza por el tema que corresponda a tu decisión. '
        + '«Por confirmar» indica que debes comprobar un dato en la administración, federación, recinto o aseguradora competente antes de aplicarlo a tu caso. '
        + 'Las fichas territoriales completan los requisitos de cada comunidad o ciudad autónoma.</p></section>'
        + "".join(parts)
        + '</body></html>'
    )
    HTML_DIR.mkdir(parents=True, exist_ok=True)
    PDF_DIR.mkdir(parents=True, exist_ok=True)
    html_path = HTML_DIR / f"KOMBAX_{group['id'].upper()}.html"
    pdf_path = PDF_DIR / f"KOMBAX_{group['id'].upper()}.pdf"
    html_path.write_text(page, encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="kx-chrome-") as profile:
        cmd = [CHROME, "--headless=old", "--no-sandbox", "--disable-gpu", "--disable-software-rasterizer",
               "--disable-dev-shm-usage", "--no-first-run", "--no-pdf-header-footer",
               f"--user-data-dir={profile}", f"--print-to-pdf={pdf_path}", html_path.as_uri()]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode or not pdf_path.exists() or pdf_path.stat().st_size < 10000:
            raise RuntimeError(f"PDF failed: {result.stderr[-1000:]}")
    return {
        "id": group["id"], "title": page_title, "subtitle": group["subtitle"],
        "audience": group["audience"], "pdf": f"./assets/guides/collections/{pdf_path.name}",
        "source_topics": [x["id"] for x in chapters], "chapters": [x["title"] for x in chapters],
    }

def main():
    index = json.loads(INDEX.read_text(encoding="utf-8"))
    source_entries = [x for x in index["entries"] if x["id"].startswith("r1001-") and x["kind"] == "public"]
    entries = {x["id"].split("-")[-1]: x for x in source_entries}
    collections = [render(group, entries) for group in GROUPS]
    covered = [item for group in collections for item in group["source_topics"]]
    expected = {x["id"] for x in source_entries if not x["id"].endswith("-f0")}
    if set(covered) != expected or len(covered) != len(set(covered)):
        raise RuntimeError("The public knowledge map is incomplete or duplicated")
    territories = [{
        "id": x["id"], "title": x["title"], "territory": x["territory"], "pdf": x["pdf"]
    } for x in index["entries"] if x.get("active") is not False and x["kind"] == "territorial"]
    catalog = {
        "brand": "KOMBAX", "collections": collections, "territories": territories,
        "reader_help": "Elige el tema de tu decisión y contrasta los datos que dependan de tu territorio, federación, recinto o aseguradora.",
    }
    (ROOT / "web/assets/guides/resource-collections.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    replacement = {topic: group["id"] for group in collections for topic in group["source_topics"]}
    index["entries"] = [entry for entry in index["entries"] if not entry["id"].startswith("r92-collection-")]
    for entry in index["entries"]:
        if entry["id"].startswith("r1001-") and entry["kind"] == "public":
            entry["active"] = False
            entry["archived"] = True
            entry["replaced_by"] = "r92-collection-" + replacement.get(entry["id"], "reader-help")
    for group in collections:
        index["entries"].append({
            "id": "r92-collection-" + group["id"], "kind": "public", "title": group["title"],
            "subtitle": group["subtitle"], "scope": group["audience"], "territory": "",
            "pdf": group["pdf"], "edition": "R100.1", "collection": True,
            "source_topics": group["source_topics"], "case_specific": True, "active": True,
        })
    index["version"] = "20145-r92-resource-center"
    INDEX.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("collections", len(collections), "source topics", len(covered), "territories", len(territories))

if __name__ == "__main__":
    main()
