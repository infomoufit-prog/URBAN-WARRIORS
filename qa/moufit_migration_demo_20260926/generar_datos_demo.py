"""Genera expedientes completamente ficticios para probar KOMBAX Migrations."""

from pathlib import Path
import csv
import json
from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parent
ROOT.mkdir(parents=True, exist_ok=True)

students = [
    ("MOUFIT-QA-001", "Alba", "Ensayo", "1999-04-12", "alba.ensayo@example.com", "Kickboxing"),
    ("MOUFIT-QA-002", "Bruno", "Simulado", "1997-09-18", "bruno.simulado@example.com", "Boxeo"),
    ("MOUFIT-QA-003", "Carla", "Prueba", "2001-02-07", "carla.prueba@example.com", "Muay Thai"),
    ("MOUFIT-QA-004", "Diego", "Ejemplo", "1995-11-23", "diego.ejemplo@example.com", "Kickboxing"),
    ("MOUFIT-QA-005", "Elena", "Ficticia", "2000-06-15", "elena.ficticia@example.com", "Boxeo"),
]

with (ROOT / "01_alumnos_demo.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["AVISO", "PRUEBA SINTÉTICA KOMBAX — NO PERSONAS REALES"])
    w.writerow(["referencia", "nombre", "apellidos", "fecha_nacimiento", "correo", "disciplina"])
    w.writerows(students[:3])

with (ROOT / "02_cuotas_demo.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["AVISO", "PRUEBA SINTÉTICA KOMBAX — NO COBRAR NI NOTIFICAR"])
    w.writerow(["referencia_alumno", "alumno", "periodo", "vencimiento", "importe_eur", "concepto"])
    w.writerow(["MOUFIT-QA-001", "Alba Ensayo", "2026-10-01", "2026-10-10", "35.00", "Cuota octubre DEMO — no cobrar"])
    w.writerow(["MOUFIT-QA-002", "Bruno Simulado", "2026-10-01", "2026-10-10", "42.00", "Cuota octubre DEMO — no cobrar"])

with (ROOT / "03_pagos_demo.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["AVISO", "PRUEBA SINTÉTICA KOMBAX — NO ES UN PAGO REAL"])
    w.writerow(["referencia_alumno", "concepto", "fecha", "importe_eur", "metodo", "referencia"])
    w.writerow(["MOUFIT-QA-001", "Cuota octubre DEMO — pago pendiente de validar", "2026-10-03", "35.00", "transferencia", "PAGO-DEMO-001"])

try:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 30)
    font_small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 22)
except OSError:
    font = ImageFont.load_default()
    font_small = font
for ref, name, surname, birth, email, discipline in students[3:]:
    im = Image.new("RGB", (1200, 760), "#f4f7fb")
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((48, 40, 1152, 718), radius=22, fill="white", outline="#24334a", width=3)
    d.rectangle((48, 40, 1152, 150), fill="#14243b")
    d.text((80, 72), "CLUB MOUFIT DEMO | FICHA SINTÉTICA", fill="white", font=font)
    lines = [
        f"Referencia: {ref}", f"Nombre: {name}", f"Apellidos: {surname}",
        f"Fecha nacimiento: {birth}", f"Correo: {email}", f"Disciplina: {discipline}",
        "AVISO: PRUEBA FICTICIA. NO ES UNA PERSONA REAL.",
    ]
    for i, line in enumerate(lines):
        d.text((80, 190 + i * 65), line, fill="#14243b", font=font_small)
    im.save(ROOT / f"04_ficha_{ref.lower()}.png", optimize=True)

pdf_path = ROOT / "05_ficha_alumno_pdf_demo.pdf"
c = canvas.Canvas(str(pdf_path), pagesize=A4)
c.setTitle("CLUB MOUFIT DEMO - ficha sintética")
c.setFont("Helvetica-Bold", 17)
c.drawString(50, 780, "CLUB MOUFIT DEMO - FICHA SINTÉTICA")
c.setFont("Helvetica", 12)
pdf_lines = [
    "Referencia: MOUFIT-QA-006", "Nombre: Fabio", "Apellidos: Demostración",
    "Fecha de nacimiento: 1998-08-04", "Correo: fabio.demo@example.com",
    "Disciplina: Boxeo", "AVISO: PRUEBA FICTICIA. NO ES UNA PERSONA REAL.",
]
for i, line in enumerate(pdf_lines):
    c.drawString(50, 730 - 38 * i, line)
c.save()

manifest = {
    "club_id": "11111111-1111-4111-8111-111111111111",
    "club": "CLUB MOUFIT DEMO (anteriormente Warriors)",
    "purpose": "Prueba sintética de KOMBAX Migrations; no contactar, cobrar ni notificar",
    "students": 6,
    "charges": 2,
    "payments": 1,
    "files": [p.name for p in sorted(ROOT.iterdir()) if p.is_file() and p.name != "generar_datos_demo.py"],
}
(ROOT / "MANIFIESTO.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
