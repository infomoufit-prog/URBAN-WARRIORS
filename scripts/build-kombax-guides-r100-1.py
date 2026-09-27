#!/usr/bin/env python3
from pathlib import Path
import re, html, subprocess, json, os, shutil, sys

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'artifacts/guides-r100-1/source'
OUT=ROOT/'web/assets/guides/public-r100-1'
MANUAL_SRC=ROOT/'artifacts/manuals/MANUAL_KOMBAX_GESTION_DE_CLUBES_R100_1.md'
MANUAL_OUT=ROOT/'artifacts/manuals/KOMBAX_MANUAL_GESTION_DE_CLUBES_R100_1.pdf'
TMP=ROOT/'artifacts/guides-r100-1/_build'
HERO=(ROOT/'web/assets/brand-heroes/hero-guides.webp').resolve()
SYMBOL=(ROOT/'web/assets/brand/kombax-symbol-red.png').resolve()
from weasyprint import HTML

CSS=r'''
@page{size:A4;margin:19mm 16mm 18mm 16mm}
@page cover{size:A4;margin:0}
*{box-sizing:border-box}html{-webkit-print-color-adjust:exact;print-color-adjust:exact}body{margin:0;font-family:Arial,"Helvetica Neue",sans-serif;color:#17181c;font-size:9.5pt;line-height:1.55;background:#fff}
a{color:#980019;text-decoration:none;word-break:break-word}p{margin:0 0 2.6mm}strong{font-weight:700}hr{border:0;border-top:1px solid #ddd;margin:6mm 0}
ul,ol{margin:0 0 3mm;padding-left:6mm}li{margin:.8mm 0}table{border-collapse:collapse;width:100%;font-size:8.1pt;margin:3mm 0 5mm;page-break-inside:auto}tr{page-break-inside:avoid}th{background:#101116;color:#fff;text-align:left;padding:2mm}td{border-bottom:1px solid #dedede;padding:1.7mm 2mm;vertical-align:top}tr:nth-child(even) td{background:#fafafa}blockquote{margin:3mm 0;padding:2.8mm 4mm;border-left:3px solid #d00626;background:#fff3f5;page-break-inside:avoid}code{font-family:Consolas,monospace;font-size:8pt;background:#f4f4f4;padding:0 .6mm}pre{background:#f4f4f4;padding:3mm;white-space:pre-wrap}
h1,h2,h3,h4{font-family:Arial,"Helvetica Neue",sans-serif;page-break-after:avoid;color:#101116}h1{font-size:24pt;line-height:1.04;text-transform:uppercase;border-bottom:3px solid #d00626;padding-bottom:2.5mm;margin:0 0 6mm}h2{font-size:16pt;line-height:1.15;border-left:4px solid #d00626;padding-left:3mm;margin:8mm 0 3mm}h3{font-size:12pt;color:#850014;margin:5mm 0 2mm}h4{font-size:10pt;margin:4mm 0 1.5mm}.cover{page:cover;position:relative;width:210mm;height:297mm;background:#06070a;color:#fff;overflow:hidden;break-after:page}.cover-bg{position:absolute;inset:0;background-image:linear-gradient(180deg,rgba(6,7,10,.18),rgba(6,7,10,.45) 40%,rgba(6,7,10,.95) 78%,#06070a 100%),url('HERO');background-size:cover;background-position:center}.cover-red{position:absolute;left:0;top:0;width:5mm;height:297mm;background:#d00626;box-shadow:0 0 24px rgba(255,0,48,.7)}.cover-top{position:absolute;left:16mm;right:15mm;top:15mm;display:flex;align-items:center;gap:4mm}.cover-top img{width:16mm;height:16mm;object-fit:contain}.brand{font-weight:800;font-size:17pt;letter-spacing:.2em}.brand small{display:block;font-size:6pt;letter-spacing:.3em;color:#c7c7c7;margin-top:1.3mm}.edition{margin-left:auto;text-align:right;font-weight:700;font-size:7pt;line-height:1.45;letter-spacing:.15em;text-transform:uppercase;color:#f1f1f1}.cover-main{position:absolute;left:16mm;right:15mm;top:142mm}.kicker{display:inline-block;background:#d00626;padding:1.6mm 3mm;font-weight:800;font-size:7pt;letter-spacing:.18em;text-transform:uppercase}.code{font-size:51pt;font-weight:900;line-height:.9;color:transparent;-webkit-text-stroke:1px rgba(255,255,255,.85);margin:5mm 0 2mm}.title{font-size:31pt;line-height:1.02;font-weight:900;text-transform:uppercase;max-width:174mm}.subtitle{margin-top:5mm;padding-left:4mm;border-left:2px solid #d00626;font-size:10pt;line-height:1.45;color:#e3e3e3;max-width:165mm}.cover-meta{position:absolute;left:16mm;right:15mm;bottom:28mm;display:grid;grid-template-columns:1.2fr 1fr 1fr;gap:3mm}.cover-meta div{border:1px solid rgba(255,255,255,.2);background:rgba(255,255,255,.06);padding:3mm}.cover-meta b{display:block;color:#ff5d73;font-size:6pt;letter-spacing:.14em;text-transform:uppercase;margin-bottom:1mm}.cover-meta span{font-size:7.6pt;line-height:1.35}.cover-foot{position:absolute;left:16mm;right:15mm;bottom:10mm;padding-top:3mm;border-top:1px solid rgba(255,255,255,.2);font-size:6.2pt;line-height:1.45;color:#a9a9a9}.toc{break-after:page}.toc .eyebrow{color:#d00626;font-size:7pt;font-weight:800;letter-spacing:.18em;text-transform:uppercase}.toc h1{margin-top:2mm}.toc ol{list-style:none;padding:0}.toc li{padding:1.6mm 0;border-bottom:1px solid #e8e8e8}.toc a{color:#17181c;font-weight:700}.toc .note{margin-top:5mm;padding:3mm;border-left:3px solid #d00626;background:#f6f6f6;color:#5c5c5c;font-size:7.6pt}.tag{display:inline-block;border-radius:2px;padding:.3mm 1.4mm;font-size:6.6pt;font-weight:700;white-space:nowrap}.legal{background:#c9001b;color:#fff}.adm{background:#1f4e79;color:#fff}.fed{background:#6f42c1;color:#fff}.rec{background:#b35c00;color:#fff}.bp{background:#2e7d32;color:#fff}.kx{background:#16171b;color:#fff}.prof{background:#8a6d00;color:#fff}.pending{background:#fff3cd;color:#704500;font-weight:700;padding:0 1mm}.product-strip{margin:0 0 6mm;padding:3mm 4mm;background:#101116;color:#fff;border-left:4px solid #d00626}.product-strip strong{color:#ff6077}.manual-price{font-size:20pt;font-weight:900;color:#d00626}.manual-badge{display:inline-block;background:#d00626;color:#fff;padding:1mm 2mm;font-weight:800;font-size:7pt;text-transform:uppercase;letter-spacing:.12em}
'''.replace('HERO',HERO.as_uri())

TAGS={
 '[Obligación legal]':('legal','Obligación legal'),
 '[Requisito administrativo]':('adm','Requisito administrativo'),
 '[Requisito federativo]':('fed','Requisito federativo'),
 '[Recinto / municipio]':('rec','Recinto / municipio'),
 '[Buena práctica]':('bp','Buena práctica'),
 '[Recomendación KOMBAX]':('kx','Recomendación KOMBAX'),
 '[Requiere profesional]':('prof','Requiere profesional'),
}

def parse_frontmatter(text):
    meta={}; body=text
    if text.startswith('---'):
        parts=text.split('---',2)
        if len(parts)>=3:
            for line in parts[1].strip().splitlines():
                if ':' in line:
                    k,v=line.split(':',1);meta[k.strip()]=v.strip()
            body=parts[2]
    return meta,body.strip()

def clean_inline(s):
    s=re.sub(r'\[([^\]]+)\]\([^)]+\)',r'\1',s)
    s=re.sub(r'[*_`]+','',s)
    return re.sub(r'\s+',' ',s).strip()

def subtitle(body):
    for line in body.splitlines():
        line=line.strip()
        if line.startswith('*') and line.endswith('*') and len(line)>2:
            return clean_inline(line.strip('*'))
    return ''

def toc_from_md(body):
    rows=[]
    for line in body.splitlines():
        m=re.match(r'^(##)\s+(.+)$',line.strip())
        if m:
            txt=clean_inline(m.group(2));slug=re.sub(r'[^a-z0-9]+','-',txt.lower()).strip('-')
            rows.append((slug,txt))
    return rows

def pandoc_html(body):
    # Remove top H1 and its immediate italic subtitle from body; cover carries them.
    body=re.sub(r'^#\s+[^\n]+\n','',body,count=1)
    body=re.sub(r'^\s*\*[^\n]+\*\s*\n','',body,count=1)
    cp=subprocess.run(['pandoc','-f','markdown+pipe_tables','-t','html5','--wrap=none'],input=body,text=True,capture_output=True,check=True)
    h=cp.stdout
    # inject deterministic ids on h2 headings in order
    n=0
    def rep(m):
        nonlocal n;n+=1
        txt=re.sub('<[^>]+>','',m.group(1));slug=re.sub(r'[^a-z0-9]+','-',html.unescape(txt).lower()).strip('-') or f's{n}'
        return f'<h2 id="{slug}">{m.group(1)}</h2>'
    h=re.sub(r'<h2[^>]*>(.*?)</h2>',rep,h,flags=re.S)
    for raw,(cls,lbl) in TAGS.items(): h=h.replace(raw,f'<span class="tag {cls}">{lbl}</span>')
    h=h.replace('PENDIENTE DE VERIFICACIÓN','<span class="pending">PENDIENTE DE VERIFICACIÓN</span>')
    return h

def cover(meta,body,manual=False):
    code=meta.get('codigo','KX')
    title=meta.get('titulo','KOMBAX Guía')
    sub=meta.get('subtitulo') or subtitle(body)
    publico=meta.get('publico','Dirección y equipos de gestión')
    fecha=meta.get('verificado_hasta','23/09/2026')
    ed='Manual profesional<br>Edición R100.1' if manual else 'Guías profesionales<br>Edición R100.1'
    kicker='GESTIÓN DE CLUBES' if manual else ('CAPA TERRITORIAL' if code.startswith('T') else 'KOMBAX GUÍAS')
    return f'''<section class="cover"><div class="cover-bg"></div><div class="cover-red"></div>
      <div class="cover-top"><img src="{SYMBOL.as_uri()}"><div class="brand">KOMBAX<small>FROM HYPE TO HISTORY</small></div><div class="edition">{ed}</div></div>
      <div class="cover-main"><div class="kicker">{html.escape(kicker)}</div><div class="code">{html.escape(code)}</div><div class="title">{html.escape(title)}</div><div class="subtitle">{html.escape(sub)}</div></div>
      <div class="cover-meta"><div><b>Para quién</b><span>{html.escape(publico)}</span></div><div><b>Revisión</b><span>{html.escape(fecha)}</span></div><div><b>Edición</b><span>R100.1 · KOMBAX</span></div></div>
      <div class="cover-foot">Información general y herramientas de trabajo. Comprueba siempre la fuente oficial vigente antes de actuar. KOMBAX no sustituye asesoramiento jurídico, fiscal, laboral, asegurador o administrativo individualizado.</div>
    </section>'''

def toc(body,title,manual=False):
    if manual:
        rows=[]
        for line in body.splitlines():
            line=line.strip()
            m=re.match(r'^#\s+(.+)$',line)
            if m:
                txt=clean_inline(m.group(1))
                if txt.lower().startswith('manual kombax'):
                    continue
                if re.match(r'^(?:[1-8]\.|panel operativo)',txt,re.I):
                    rows.append(('',txt))
    else:
        rows=toc_from_md(body)
    lis=''.join(f'<li>{("<a href=\"#"+slug+"\">"+html.escape(txt)+"</a>") if slug else html.escape(txt)}</li>' for slug,txt in rows)
    return f'''<section class="toc"><div class="eyebrow">KOMBAX · índice operativo</div><h1>{html.escape(title)}</h1><ol>{lis}</ol><div class="note">Las etiquetas distinguen obligación legal, requisito administrativo o federativo, condición del recinto, buena práctica y recomendación KOMBAX. Si un dato aparece pendiente, no lo conviertas en requisito hasta verificarlo en la fuente competente.</div></section>'''

def html_doc(meta,body,manual=False):
    title=meta.get('titulo','KOMBAX')
    extra=''
    if manual:
        extra='<div class="product-strip"><span class="manual-badge">Producto editorial</span> <strong>Incluido en KOMBAX Premium</strong> · adquisición individual de referencia: <span class="manual-price">6 €</span></div>'
    return f'''<!doctype html><html lang="es"><head><meta charset="utf-8"><title>{html.escape(title)}</title><style>{CSS}</style></head><body>{cover(meta,body,manual)}{toc(body,title,manual)}{extra}{pandoc_html(body)}</body></html>'''

def render(md_path,pdf_path,manual=False):
    text=Path(md_path).read_text(encoding='utf-8');meta,body=parse_frontmatter(text)
    TMP.mkdir(parents=True,exist_ok=True);pdf_path=Path(pdf_path);pdf_path.parent.mkdir(parents=True,exist_ok=True)
    hp=TMP/(pdf_path.stem+'.html');hp.write_text(html_doc(meta,body,manual),encoding='utf-8')
    HTML(filename=str(hp), base_url=str(ROOT)).write_pdf(str(pdf_path))
    if not pdf_path.exists() or pdf_path.stat().st_size<10000:
        raise RuntimeError(f'PDF render failed {pdf_path}')
    return meta

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    for old in OUT.glob('*.pdf'): old.unlink()
    metas=[]
    for md in sorted(SRC.glob('*.md')):
        meta=render(md,OUT/(md.stem+'.pdf'))
        metas.append((md.stem,meta))
        print('guide',md.stem)
    # The commercial manual has a maintained HTML layout. Keep its cover and
    # reader-facing text when rebuilding the public guide collection.
    manual_html=TMP/'KOMBAX_MANUAL_GESTION_DE_CLUBES_R100_1.html'
    if manual_html.exists():
        HTML(filename=str(manual_html),base_url=str(ROOT)).write_pdf(str(MANUAL_OUT))
    else:
        render(MANUAL_SRC,MANUAL_OUT,True)
    print('manual',MANUAL_OUT)
    # concise build manifest
    manifest={'edition':'R100.1','built_at':'2026-09-23','guides':len(metas),'manual':str(MANUAL_OUT.relative_to(ROOT))}
    (ROOT/'artifacts/guides-r100-1/build-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')

if __name__=='__main__': main()
