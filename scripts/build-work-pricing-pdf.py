"""Build the public KOMBAX pricing summary from the approved WORK offer amounts."""
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'web/assets/docs/commercial/KOMBAX_PLAN_PRECIOS.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)

page_w, page_h = 595.28, 841.89
c = canvas.Canvas(str(OUT), pagesize=(page_w, page_h), pageCompression=1)
c.setTitle('KOMBAX · Planes y servicios')
c.setAuthor('KOMBAX')

bg = HexColor('#11141B')
panel = HexColor('#1C2029')
red = HexColor('#EB3349')
white = HexColor('#F6F6F7')
muted = HexColor('#A8ADBA')

c.setFillColor(bg)
c.rect(0, 0, page_w, page_h, fill=1, stroke=0)
c.setFillColor(red)
c.rect(42, page_h-51, 44, 4, fill=1, stroke=0)
c.setFillColor(white)
c.setFont('Helvetica-Bold', 12)
c.drawString(42, page_h-78, 'KOMBAX')
c.setFont('Helvetica-Bold', 28)
c.drawString(42, page_h-122, 'Planes y servicios')
c.setFillColor(muted)
c.setFont('Helvetica', 11)
c.drawString(42, page_h-144, 'Tu identidad pública comienza gratis. Activa la gestión cuando la necesites.')

rows = [
    ('Perfil Club', 'Gratis', 'Presencia pública y relaciones'),
    ('KOMBAX Club', '23,90 €/mes + IVA', 'Gestión operativa del club'),
    ('KOMBAX Premium', '37,90 €/mes + IVA', 'Gestión y mayor capacidad'),
    ('KOMBAX MultiClub', 'Desde 29,90 €/mes + IVA', 'Organización con varias sedes'),
    ('KOMBAX Enterprise', 'Condiciones a medida', 'Escala y capacidades superiores'),
]

y = page_h-190
for title, price, detail in rows:
    c.setFillColor(panel)
    c.roundRect(42, y-54, page_w-84, 60, 11, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont('Helvetica-Bold', 13)
    c.drawString(56, y-18, title)
    c.setFont('Helvetica-Bold', 11)
    c.drawRightString(page_w-56, y-18, price)
    c.setFillColor(muted)
    c.setFont('Helvetica', 9)
    c.drawString(56, y-37, detail)
    y -= 69

c.setFillColor(red)
c.setFont('Helvetica-Bold', 12)
c.drawString(42, y-10, 'También para marcas y federaciones')
c.setFillColor(muted)
c.setFont('Helvetica', 10)
c.drawString(42, y-29, 'El perfil público es gratuito. Sus planes operativos se publicarán al cerrar condiciones.')
c.drawString(42, y-47, 'La verificación de identidad y la activación de servicios son procesos distintos.')

c.setStrokeColor(HexColor('#3A404D'))
c.line(42, 106, page_w-42, 106)
c.setFillColor(white)
c.setFont('Helvetica-Bold', 10)
c.drawString(42, 88, 'Capacidades separadas')
c.setFillColor(muted)
c.setFont('Helvetica', 9)
c.drawString(42, 72, 'Showcase Display y Commerce; publicar eventos y Ticketing; ampliaciones de catálogo.')
c.drawString(42, 57, 'Los precios de suscripciones existentes siguen sujetos a sus contratos vigentes.')
c.drawString(42, 34, 'Consulta el detalle y la disponibilidad desde Plan y servicios de tu identidad KOMBAX.')
c.showPage()
c.save()
print(OUT)
