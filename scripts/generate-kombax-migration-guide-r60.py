from reportlab.lib import colors
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Table, TableStyle,
    Image, PageBreak, NextPageTemplate, KeepTogether, HRFlowable
)
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from reportlab.lib.utils import ImageReader
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/protected/KOMBAX_GUIA_MIGRACIONES_CLUB_FEDERACION_R60.pdf'
LOGO_RED = ROOT / 'web/assets/brand/kombax-symbol-red.png'
LOGO_WHITE = ROOT / 'web/assets/brand/kombax-symbol-white.png'

PAGE_W, PAGE_H = A4
RED = HexColor('#E21D2D')
DARK = HexColor('#111217')
DARK_2 = HexColor('#1B1D24')
TEXT = HexColor('#171920')
MUTED = HexColor('#5D6472')
LIGHT = HexColor('#F4F5F7')
LINE = HexColor('#DDE1E7')
CYAN = HexColor('#1597B7')
GOLD = HexColor('#C98C18')
GREEN = HexColor('#138A62')

font_regular = 'Helvetica'
font_bold = 'Helvetica-Bold'

# Downscale the logo for the PDF bundle; source brand asset remains untouched.
PDF_LOGO = Path('/tmp/kombax-guide-logo-red-r60.png')
try:
    from PIL import Image as PILImage
    with PILImage.open(LOGO_RED) as _logo:
        _logo.thumbnail((360,360), PILImage.Resampling.LANCZOS)
        _logo.save(PDF_LOGO, optimize=True)
except Exception:
    PDF_LOGO = LOGO_RED

styles = getSampleStyleSheet()
BODY = ParagraphStyle('Body', fontName=font_regular, fontSize=9.4, leading=13.5, textColor=TEXT, spaceAfter=5)
BODY_SM = ParagraphStyle('BodySm', parent=BODY, fontSize=8.6, leading=12.2)
MUTED_SM = ParagraphStyle('MutedSm', parent=BODY_SM, textColor=MUTED)
H1 = ParagraphStyle('H1', fontName=font_bold, fontSize=24, leading=27, textColor=TEXT, spaceAfter=8)
H2 = ParagraphStyle('H2', fontName=font_bold, fontSize=16, leading=19, textColor=TEXT, spaceBefore=4, spaceAfter=7)
H3 = ParagraphStyle('H3', fontName=font_bold, fontSize=11.5, leading=14, textColor=TEXT, spaceAfter=4)
EYEBROW = ParagraphStyle('Eyebrow', fontName=font_bold, fontSize=7.6, leading=9, textColor=RED, tracking=1.2, spaceAfter=4)
WHITE_HERO = ParagraphStyle('WhiteHero', fontName=font_bold, fontSize=30, leading=33, textColor=colors.white, alignment=TA_LEFT)
WHITE_SUB = ParagraphStyle('WhiteSub', fontName=font_regular, fontSize=12, leading=17, textColor=HexColor('#E4E6EB'))
WHITE_SMALL = ParagraphStyle('WhiteSmall', fontName=font_regular, fontSize=8.5, leading=12, textColor=HexColor('#D1D4DB'))
CARD_TITLE = ParagraphStyle('CardTitle', fontName=font_bold, fontSize=10.2, leading=12.5, textColor=TEXT)
CARD_BODY = ParagraphStyle('CardBody', fontName=font_regular, fontSize=8.3, leading=11.7, textColor=MUTED)
TABLE_H = ParagraphStyle('TableH', fontName=font_bold, fontSize=7.9, leading=10, textColor=TEXT)
TABLE_C = ParagraphStyle('TableC', fontName=font_regular, fontSize=7.6, leading=10, textColor=TEXT)
TABLE_M = ParagraphStyle('TableM', fontName=font_regular, fontSize=7.4, leading=9.5, textColor=MUTED)
NUM = ParagraphStyle('Num', fontName=font_bold, fontSize=9.5, leading=11, textColor=colors.white, alignment=TA_CENTER)
FAQ_Q = ParagraphStyle('FaqQ', fontName=font_bold, fontSize=9.3, leading=12, textColor=TEXT)
FAQ_A = ParagraphStyle('FaqA', fontName=font_regular, fontSize=8.5, leading=12, textColor=MUTED)


def P(text, style=BODY):
    return Paragraph(text, style)

def pill(text, bg=LIGHT, fg=TEXT):
    t=Table([[Paragraph(text, ParagraphStyle('pill', fontName=font_bold, fontSize=7.8, leading=9, textColor=fg))]], hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),bg),('BOX',(0,0),(-1,-1),0.4,bg),
        ('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),
        ('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4),
    ]))
    return t

def section_header(kicker, title, intro=None):
    out=[P(kicker.upper(), EYEBROW), P(title, H1)]
    if intro: out += [P(intro, BODY), Spacer(1,2*mm)]
    return out

def card(title, body, accent=RED, width=78*mm):
    data=[[Paragraph(title, CARD_TITLE)], [Paragraph(body, CARD_BODY)]]
    t=Table(data, colWidths=[width], hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),colors.white),
        ('BOX',(0,0),(-1,-1),0.6,LINE),
        ('LINEBEFORE',(0,0),(0,-1),3,accent),
        ('LEFTPADDING',(0,0),(-1,-1),10),('RIGHTPADDING',(0,0),(-1,-1),10),
        ('TOPPADDING',(0,0),(-1,-1),9),('BOTTOMPADDING',(0,0),(-1,-1),9),
    ]))
    return t

def two_cards(a,b):
    t=Table([[a,b]], colWidths=[82*mm,82*mm], hAlign='LEFT')
    t.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),5)]))
    return t

def callout(title, body, accent=RED, bg=HexColor('#FFF4F5')):
    t=Table([[Paragraph(title, CARD_TITLE), Paragraph(body, CARD_BODY)]], colWidths=[35*mm,128*mm], hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),bg),('BOX',(0,0),(-1,-1),0.7,accent),
        ('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9),
        ('TOPPADDING',(0,0),(-1,-1),8),('BOTTOMPADDING',(0,0),(-1,-1),8),('VALIGN',(0,0),(-1,-1),'TOP')
    ]))
    return t

def step_row(n, title, body, accent=RED):
    num=Table([[P(str(n),NUM)]], colWidths=[8*mm], rowHeights=[8*mm])
    num.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),accent),('VALIGN',(0,0),(-1,-1),'MIDDLE'),('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),0),('TOPPADDING',(0,0),(-1,-1),0),('BOTTOMPADDING',(0,0),(-1,-1),0)]))
    text=Table([[P(title,CARD_TITLE)],[P(body,CARD_BODY)]], colWidths=[146*mm])
    text.setStyle(TableStyle([('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),0),('TOPPADDING',(0,0),(-1,-1),0),('BOTTOMPADDING',(0,0),(-1,-1),1)]))
    t=Table([[num,text]], colWidths=[12*mm,150*mm], hAlign='LEFT')
    t.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),0),('TOPPADDING',(0,0),(-1,-1),2),('BOTTOMPADDING',(0,0),(-1,-1),4)]))
    return t

def data_table(headers, rows, widths, header_bg=HexColor('#EEF0F4')):
    data=[[P(h,TABLE_H) for h in headers]] + [[P(str(c),TABLE_C) for c in row] for row in rows]
    t=Table(data, colWidths=widths, repeatRows=1, hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,0),header_bg),('TEXTCOLOR',(0,0),(-1,0),TEXT),
        ('GRID',(0,0),(-1,-1),0.45,LINE),('VALIGN',(0,0),(-1,-1),'TOP'),
        ('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),
        ('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6),
    ]))
    return t

def faq(q,a):
    t=Table([[P(q,FAQ_Q)],[P(a,FAQ_A)]], colWidths=[164*mm], hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),colors.white),('BOX',(0,0),(-1,-1),0.45,LINE),
        ('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9),
        ('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7),
    ]))
    return t


def cover_page(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(DARK)
    canvas.rect(0,0,PAGE_W,PAGE_H,stroke=0,fill=1)
    # brand red accent blocks
    canvas.setFillColor(RED)
    canvas.rect(0,PAGE_H-6*mm,PAGE_W,6*mm,stroke=0,fill=1)
    # logo
    try:
        canvas.drawImage(str(PDF_LOGO), 20*mm, PAGE_H-58*mm, 31*mm,31*mm, mask='auto', preserveAspectRatio=True)
    except Exception:
        pass
    canvas.setFont(font_bold, 22)
    canvas.setFillColor(colors.white)
    canvas.drawString(55*mm, PAGE_H-44*mm, 'KOMBAX')
    canvas.setFont(font_regular, 8.5)
    canvas.setFillColor(HexColor('#B8BBC4'))
    canvas.drawString(55*mm, PAGE_H-50*mm, 'FROM HYPE TO HISTORY')
    canvas.restoreState()


def body_page(canvas, doc):
    canvas.saveState()
    # header
    try:
        canvas.drawImage(str(PDF_LOGO), 18*mm, PAGE_H-21*mm, 11*mm,11*mm, mask='auto', preserveAspectRatio=True)
    except Exception:
        pass
    canvas.setFont(font_bold, 9)
    canvas.setFillColor(TEXT)
    canvas.drawString(32*mm, PAGE_H-15*mm, 'KOMBAX')
    canvas.setFont(font_regular, 7.5)
    canvas.setFillColor(MUTED)
    canvas.drawString(32*mm, PAGE_H-20*mm, 'Guía de migración y gestión de datos - Club / Federación')
    canvas.setStrokeColor(LINE); canvas.setLineWidth(.6)
    canvas.line(18*mm, PAGE_H-24*mm, PAGE_W-18*mm, PAGE_H-24*mm)
    # footer
    canvas.line(18*mm, 16*mm, PAGE_W-18*mm, 16*mm)
    canvas.setFont(font_regular, 7.2)
    canvas.setFillColor(MUTED)
    canvas.drawString(18*mm, 10.5*mm, 'KOMBAX 20.110 R60 - Uso exclusivo de Club y Federación')
    canvas.drawRightString(PAGE_W-18*mm, 10.5*mm, f'Página {doc.page}')
    canvas.restoreState()


def build():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    cover_frame=Frame(20*mm, 20*mm, PAGE_W-40*mm, PAGE_H-40*mm, leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0,id='cover')
    body_frame=Frame(18*mm, 20*mm, PAGE_W-36*mm, PAGE_H-48*mm, leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0,id='body')
    doc=BaseDocTemplate(str(OUT), pagesize=A4, title='KOMBAX - Guía de migración para Clubes y Federaciones', author='KOMBAX', subject='Migración y gestión de datos', leftMargin=18*mm,rightMargin=18*mm,topMargin=28*mm,bottomMargin=20*mm)
    doc.addPageTemplates([PageTemplate(id='cover', frames=[cover_frame], onPage=cover_page), PageTemplate(id='body', frames=[body_frame], onPage=body_page)])
    S=[]

    # PAGE 1 COVER
    S += [Spacer(1,58*mm), P('GUÍA DE MIGRACIÓN Y GESTIÓN DE DATOS', ParagraphStyle('coverKicker', fontName=font_bold,fontSize=9,leading=11,textColor=RED,tracking=1.3)), Spacer(1,4*mm)]
    S += [P('Tus datos entran en KOMBAX.<br/>Tu histórico no se pierde.', WHITE_HERO), Spacer(1,6*mm)]
    S += [P('Manual práctico y comercial para Clubes y Federaciones: alumnos, federados, grupos, matrículas, cuotas, pagos, licencias, documentos y activación de cuentas.', WHITE_SUB), Spacer(1,9*mm)]
    cover_cards=Table([
        [P('<b>Importa por lotes</b><br/>Excel, CSV, PDF e imágenes.', WHITE_SMALL), P('<b>Revisa antes de confirmar</b><br/>Nada se aplica desde el chat sin vista previa.', WHITE_SMALL), P('<b>Activa sin duplicar</b><br/>La cuenta correcta se vincula a la ficha existente.', WHITE_SMALL)]
    ], colWidths=[52*mm,52*mm,52*mm])
    cover_cards.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),HexColor('#191A20')),('BOX',(0,0),(-1,-1),0.6,HexColor('#343641')),('INNERGRID',(0,0),(-1,-1),0.5,HexColor('#343641')),
        ('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9),('TOPPADDING',(0,0),(-1,-1),10),('BOTTOMPADDING',(0,0),(-1,-1),10),('VALIGN',(0,0),(-1,-1),'TOP')
    ]))
    S += [cover_cards, Spacer(1,13*mm), P('<b>Menos fricción. Más control. Una migración que respeta la estructura de tu organización.</b>', ParagraphStyle('coverClaim', fontName=font_bold,fontSize=11,leading=15,textColor=colors.white)), Spacer(1,27*mm)]
    S += [P('KOMBAX 20.110 R60 · Guía protegida para perfiles Club y Federación', WHITE_SMALL), NextPageTemplate('body'), PageBreak()]

    # PAGE 2
    S += section_header('01 · EMPEZAR', 'Qué resuelve KOMBAX Migrations', 'El objetivo no es “copiar una hoja”. Es trasladar la información útil de tu Club o Federación conservando relaciones, histórico y control antes de convertirla en datos operativos.')
    S += [two_cards(
        card('Tu histórico sigue siendo tuyo', 'Una ficha administrativa puede existir aunque la persona todavía no tenga cuenta KOMBAX. Esto permite migrar primero y activar después.', RED),
        card('No se crean cuentas ficticias', 'Los registros importados no generan usuarios artificiales en Auth. La cuenta real se vincula más adelante a la misma ficha.', CYAN)
    ), Spacer(1,4*mm)]
    S += [P('¿Qué puedes trasladar?', H2)]
    sources = [
        ['Excel / CSV','Alumnos, federados, grupos, matrículas, tarifas, cuotas y contactos.','Lectura estructurada + normalización.'],
        ['PDF','Listados, fichas, licencias, formularios y exportaciones.','Extracción por lotes + revisión de dudas.'],
        ['Imágenes','Fichas fotografiadas, carnés o documentos escaneados.','Análisis visual controlado.'],
        ['Varios archivos','Hojas + PDFs + anexos de una misma migración.','Se mantiene el contexto del mismo caso.'],
    ]
    S += [data_table(['Origen','Ejemplos','Cómo se trata'],sources,[29*mm,70*mm,65*mm]), Spacer(1,4*mm)]
    S += [P('El proceso en 5 pasos', H2)]
    for n,t,b in [
        (1,'Explica el origen','Qué sistema usabas, qué representa cada hoja y qué quieres conservar.'),
        (2,'Sube los archivos','Añade Excel, CSV, PDF o imágenes al mismo caso de migración.'),
        (3,'KOMBAX analiza y pregunta','Se detectan campos, relaciones, vacíos, posibles duplicados y datos dudosos.'),
        (4,'Revisa la vista previa','Comprueba qué se propone crear, actualizar o dejar pendiente.'),
        (5,'Confirma','Solo después de tu revisión se puede continuar con la incorporación de datos.')
    ]: S.append(step_row(n,t,b, RED if n in [1,5] else DARK_2))
    S += [Spacer(1,3*mm), callout('Regla central','Primero se conserva la ficha y su histórico; después se activa o vincula la cuenta correcta. Nunca se crea un segundo alumno o federado para “hacer encajar” el acceso.',RED), PageBreak()]

    # PAGE 3
    S += section_header('02 · EJEMPLO CLUB', 'De un Excel de alumnos a una base ordenada', 'Ejemplo: un club tiene una hoja con 120 alumnos, grupos mezclados, algunos emails vacíos y varias columnas de cuotas. KOMBAX Migrations ayuda a separar cada concepto antes de incorporarlo.')
    S += [P('Ejemplo de archivo recibido', H2)]
    rows=[
        ['A-001','Ana Pérez','18/05/2004','ana@email.es','Muay Thai Adultos','45 €'],
        ['A-002','Marc Vidal','10/02/2014','-','Jiu-Jitsu Infantil','40 €'],
        ['A-003','Luis Gómez','22/11/1989','-','Boxeo Tarde','50 €'],
    ]
    S += [data_table(['ID origen','Nombre','Nacimiento','Email','Grupo','Cuota'],rows,[22*mm,31*mm,27*mm,33*mm,36*mm,15*mm]), Spacer(1,4*mm)]
    S += [P('Qué haría el flujo de migración', H2)]
    actions=[
        ('A-001 · Alta digital preparada','Tiene 16+ y email. La ficha administrativa se conserva y puede recibir invitación KOMBAX vinculada a esa misma ficha.',GREEN),
        ('A-002 · Menor de 16','La ficha de Marc se importa sin exigir email propio. El acceso digital se vincula después a un tutor autorizado.',GOLD),
        ('A-003 · Histórico sin email','Luis puede seguir siendo alumno administrativamente. Queda como “Falta email / Sin activar” hasta completar un email válido.',CYAN),
    ]
    for title,body,accent in actions: S += [card(title,body,accent,164*mm), Spacer(1,2.7*mm)]
    S += [P('Consejo para una migración limpia', H2)]
    S += [two_cards(
        card('Conserva un identificador estable', 'Si tu programa antiguo tiene ID de alumno, número de socio o código interno, inclúyelo. Ayuda a reconocer el mismo registro en futuras importaciones.', RED),
        card('No deduzcas por el nombre', '“Juan García” no es un identificador suficiente. Si hay ambigüedad, KOMBAX debe marcarla para revisión humana.', DARK_2)
    ), Spacer(1,4*mm)]
    S += [callout('Resultado esperado','Alumnos, grupos y matrículas quedan relacionados. Los que aún no tienen acceso digital siguen siendo gestionables; cuando se activen, entran sobre su ficha existente y conservan todo el histórico.',CYAN,HexColor('#F0FAFC')), PageBreak()]

    # PAGE 4 FINANCE
    S += section_header('03 · FINANZAS', 'Cuotas, matrículas y pagos sin perder el histórico', 'KOMBAX diferencia la ficha del alumno, la tarifa, la cuota generada, el pago comunicado/registrado y el recibo. En una migración conviene mantener estas piezas separadas para no convertir todo en una única columna “pagado”.')
    S += [P('Ejemplo de datos financieros', H2)]
    finrows=[
        ['Ana Pérez','Cuota mensual','2026-08','45,00','Pagada','Transferencia'],
        ['Marc Vidal','Matrícula temporada','2026','30,00','Pagada','Efectivo'],
        ['Luis Gómez','Cuota mensual','2026-08','50,00','Pendiente','-'],
    ]
    S += [data_table(['Alumno','Concepto','Periodo','Importe','Estado','Método'],finrows,[31*mm,38*mm,22*mm,20*mm,24*mm,29*mm]), Spacer(1,5*mm)]
    S += [P('Cómo se ordena dentro de KOMBAX', H2)]
    S += [two_cards(
        card('Tarifas y reglas', 'Define el precio de una actividad, periodicidad, posible matrícula y automatización futura. No debe confundirse con una cuota histórica ya emitida.', RED),
        card('Cuotas y cargos', 'Representan obligaciones concretas por persona y periodo. Se conserva su estado: pendiente, vencida, parcialmente pagada o pagada.', CYAN)
    ), Spacer(1,3*mm), two_cards(
        card('Pagos', 'Se registra importe, fecha, método, referencia y validación cuando corresponda. KOMBAX registra y valida; no procesa dinero.', GREEN),
        card('Recibos e informes', 'Los cobros validados pueden alimentar recibos y reportes. La migración debe respetar fecha, concepto y titular para no falsear el histórico.', GOLD)
    ), Spacer(1,4*mm)]
    S += [P('Ejemplo práctico: Club con cuotas mensuales', H2)]
    for n,t,b in [
        (1,'Sube el Excel financiero','Incluye alumno/ID, concepto, periodo, importe, estado y método si existe.'),
        (2,'KOMBAX separa conceptos','Matrícula, cuota recurrente, licencia, evento, material u “otro” no se mezclan.'),
        (3,'Revisa duplicados','Una reimportación no debe volver a crear la cuota de agosto si ya existe.'),
        (4,'Confirma la vista previa','Comprueba totales y muestras de alumnos antes de incorporar los movimientos.')
    ]: S.append(step_row(n,t,b, GREEN if n==4 else DARK_2))
    S += [PageBreak()]

    # PAGE 5 DOCUMENTS + FEDERATION
    S += section_header('04 · DOCUMENTOS Y FEDERACIÓN', 'PDF, licencias, listados y documentación institucional', 'No todo llega en columnas. KOMBAX Migrations también puede trabajar con documentos y exportaciones donde la información está distribuida entre PDF, imágenes y varias hojas.')
    S += [P('Ejemplo: licencias desde PDF', H2)]
    docrows=[
        ['LIC-20391','Ana Pérez','Kickboxing','01/09/2026','31/08/2027','Federación X'],
        ['LIC-20407','Marc Vidal','Jiu-Jitsu','01/09/2026','31/08/2027','Federación X'],
    ]
    S += [data_table(['Licencia','Titular','Disciplina','Alta','Vencimiento','Entidad'],docrows,[24*mm,31*mm,29*mm,25*mm,27*mm,28*mm]), Spacer(1,4*mm)]
    S += [two_cards(
        card('Documento + metadatos', 'Cuando corresponde, conserva el archivo y los datos que permiten encontrarlo: titular, tipo, entidad, fecha, vencimiento y referencia.', RED),
        card('Dudas marcadas', 'Si una fecha no se lee bien, un nombre aparece cortado o el documento no permite identificar titular, debe quedar para revisión antes de crear relaciones.', CYAN)
    ), Spacer(1,5*mm)]
    S += [P('Qué puede migrar una Federación', H2)]
    S += [data_table(['Sí, dentro del ámbito federativo','No debe mezclarse automáticamente con datos privados del club'],[
        ['Federados, licencias, clubes asociados, territorios, estados, vencimientos y documentación federativa.','Finanzas internas del club, asistencia de clases, datos familiares privados o historiales que la Federación no tenga autorización para tratar.']
    ],[80*mm,84*mm]), Spacer(1,4*mm)]
    S += [callout('Aislamiento organizativo','Club y Federación trabajan en contextos distintos. Tener relación federativa no concede acceso automático a las zonas privadas del club.',RED), Spacer(1,5*mm)]
    S += [P('Ejemplo Federación', H2)]
    S += [P('<b>Situación:</b> la Federación recibe un Excel de clubes asociados y tres PDFs con licencias. Puede mantenerlo en una misma migración, pedir análisis por lotes, resolver duplicados y revisar una vista previa global sin convertir datos del club en datos federativos por accidente.', BODY), PageBreak()]

    # PAGE 6 ACCOUNTS
    S += section_header('05 · CUENTAS', 'Migrar datos no significa crear cuentas', 'KOMBAX separa la identidad global de la persona y sus relaciones administrativas. Esto permite incorporar datos hoy y activar accesos más tarde, sin recrear al alumno o federado.')
    S += [P('Reglas de acceso de alumno', H2)]
    account_rows=[
        ['Alta nueva 16+','Email requerido desde la preinscripción.','Ficha -> invitación -> verificación -> misma ficha activa.'],
        ['Histórico 16+ sin email','La ficha puede migrarse y gestionarse.','Queda “Falta email / Sin activar” hasta completar el dato.'],
        ['Menor de 16','No se exige email propio del menor.','Tutor autorizado -> relación de tutor -> ficha del menor.'],
        ['Cuenta ya existente','Puede ser Espectador u otro perfil.','Solicita vinculación y el Club aprueba/rechaza sobre la ficha exacta.'],
    ]
    S += [data_table(['Caso','Antes de activar','Resultado'],account_rows,[38*mm,61*mm,65*mm]), Spacer(1,5*mm)]
    S += [P('Multiclub', H2)]
    S += [two_cards(
        card('Una identidad global', 'La persona entra con una cuenta KOMBAX. Esa identidad puede tener distintas membresías y perfiles autorizados.', RED),
        card('Datos separados por Club', 'Cuotas, asistencia, grupos, documentos, notificaciones y permisos de Club A no se mezclan con Club B.', CYAN)
    ), Spacer(1,4*mm)]
    S += [callout('Ejemplo','Ana entrena en Club A y Club B. Usa la misma cuenta KOMBAX, pero mantiene dos membresías distintas. Si Club A la da de baja, Club B continúa activo.',GREEN,HexColor('#F0FAF6')), Spacer(1,4*mm)]
    S += [P('Menores: qué no hacer', H2), P('No conviertas la ficha del menor en la cuenta de su madre, padre o tutor. El menor conserva su expediente administrativo; el adulto obtiene una relación de acceso autorizada.', BODY)]
    S += [callout('Seguridad','Nunca vincules automáticamente por nombre. Utiliza invitación, email verificado, solicitud aprobada u otro mecanismo seguro asociado a la ficha exacta.',RED), PageBreak()]

    # PAGE 7 ASSISTANT
    S += section_header('06 · ASISTENCIA', 'KOMBAX Migrations y KOMBAX Assist: dos ayudas distintas', 'La transferencia de datos tiene un canal directo propio. El soporte general empieza por correo y puede activar un chat guiado cuando el caso realmente necesita interacción.')
    S += [two_cards(
        card('KOMBAX Migrations', '<b>Para Club y Federación.</b><br/>Chat directo para explicar el origen, subir archivos, analizar por lotes, resolver dudas y preparar la vista previa de una migración.', RED),
        card('KOMBAX Assist', '<b>Soporte funcional y técnico.</b><br/>El contacto estándar comienza por soporte@kombax.es. Si hace falta interacción, soporte puede habilitar un chat asociado al caso.', CYAN)
    ), Spacer(1,5*mm)]
    S += [P('Ejemplo de conversación de migración', H2)]
    convo=Table([
        [P('<b>CLUB</b>',TABLE_H),P('Tengo un Excel con alumnos y otra hoja con cuotas. Algunos menores no tienen email.',TABLE_C)],
        [P('<b>KOMBAX MIGRATIONS</b>',TABLE_H),P('Perfecto. Primero revisaré qué identifica a cada alumno, cómo se relacionan los grupos y qué columnas representan cuotas o matrículas. Los menores de 16 podrán mantenerse sin email propio. Antes de incorporar nada te mostraré una vista previa.',TABLE_C)],
        [P('<b>CLUB</b>',TABLE_H),P('También tengo 15 licencias en PDF.',TABLE_C)],
        [P('<b>KOMBAX MIGRATIONS</b>',TABLE_H),P('Puedes añadirlas a esta misma migración. Las analizaré por lotes y marcaré cualquier titular o fecha dudosa para que la revises.',TABLE_C)],
    ], colWidths=[39*mm,125*mm])
    convo.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(0,-1),HexColor('#F1F2F5')),('BACKGROUND',(1,0),(1,-1),colors.white),('GRID',(0,0),(-1,-1),0.45,LINE),('VALIGN',(0,0),(-1,-1),'TOP'),
        ('LEFTPADDING',(0,0),(-1,-1),8),('RIGHTPADDING',(0,0),(-1,-1),8),('TOPPADDING',(0,0),(-1,-1),8),('BOTTOMPADDING',(0,0),(-1,-1),8)
    ]))
    S += [convo, Spacer(1,5*mm)]
    S += [P('Qué hace el asistente y qué decide tu organización', H2)]
    S += [data_table(['El asistente ayuda a...','El Club/Federación decide...'],[
        ['Entender columnas y documentos; detectar vacíos; proponer normalización; señalar duplicados; mantener contexto por lotes.','Qué datos conservar; cómo resolver una ambigüedad; si una vista previa es correcta; cuándo confirmar la incorporación.'],
    ],[82*mm,82*mm]), Spacer(1,4*mm)]
    S += [callout('Privacidad de consumo','La interfaz del cliente no necesita mostrar nombres de modelos, tokens ni costes técnicos. Los límites se expresan como casos, conversaciones, documentos y volumen incluido.',DARK_2,HexColor('#F4F4F6')), PageBreak()]

    # PAGE 8 DELETE / PRIVACY
    S += section_header('07 · PRIVACIDAD Y CONTROL', 'Eliminar conversaciones e historial', 'Club y Federación pueden limpiar su historial visible de Migraciones y Soporte. La eliminación debe abarcar el contenido relacionado, no limitarse a esconder una fila de la pantalla.')
    S += [P('Al eliminar una conversación de Migraciones', H2)]
    delete_rows=[
        ['Mensajes del chat','Se eliminan.'],
        ['Análisis y vistas previas derivadas','Se eliminan.'],
        ['Metadatos de archivos','Se eliminan.'],
        ['Archivo físico en Storage','Se elimina mediante la ruta autorizada.'],
        ['Caso/ticket visible','Se elimina cuando la limpieza termina.'],
        ['Contadores de uso','Se conservan; borrar no devuelve cupos.'],
        ['Auditoría mínima de seguridad/consumo','Puede conservarse sin contenido, nombres de archivo, mensajes ni IDs de ticket recuperables.'],
    ]
    S += [data_table(['Elemento','Qué ocurre'],delete_rows,[74*mm,90*mm]), Spacer(1,5*mm)]
    S += [two_cards(
        card('Eliminar conversación', 'Borra un caso concreto y sus archivos asociados después de confirmar la acción.', RED),
        card('Borrar historial', 'Borra todos los casos visibles del módulo y contexto actual, con advertencia explícita y sin restaurar consumo.', DARK_2)
    ), Spacer(1,5*mm)]
    S += [P('Buenas prácticas antes de borrar', H2)]
    for n,t,b in [
        (1,'Comprueba si necesitas exportar algo','Si el caso contiene una vista previa o documento que quieras conservar, descárgalo antes.'),
        (2,'Confirma el ámbito','Club y Federación tienen contextos distintos; asegúrate de estar en la organización correcta.'),
        (3,'Elimina solo cuando el caso esté cerrado','Una vez confirmada la limpieza, el contenido no debe quedar recuperable desde la aplicación.')
    ]: S.append(step_row(n,t,b, RED if n==3 else DARK_2))
    S += [callout('Principio de estabilización','La limpieza de contenido no debe romper metering, límites del plan, seguridad ni aislamiento entre organizaciones.',GOLD,HexColor('#FFF9EB')), PageBreak()]

    # PAGE 9 FAQ
    S += section_header('08 · DUDAS FRECUENTES', 'Respuestas rápidas antes de empezar', 'Estas son las dudas más habituales cuando un Club o Federación se plantea trasladar datos a KOMBAX.')
    faqs=[
        ('¿Tengo que limpiar el Excel antes de subirlo?','No necesariamente. Conviene que las columnas tengan un significado razonable, pero KOMBAX Migrations está pensado para ayudarte a identificar vacíos, formatos distintos y relaciones. Lo importante es explicar de dónde vienen los datos.'),
        ('¿Qué pasa si faltan emails?','Un registro histórico puede migrarse sin email y seguir siendo gestionable. Para una alta nueva 16+ el email se recoge desde la preinscripción. Los menores de 16 se gestionan mediante tutor autorizado.'),
        ('¿Se crean alumnos duplicados al activar la cuenta?','No debería. La activación está diseñada para vincular la cuenta correcta a la ficha administrativa existente. Además, la base incorpora protecciones contra duplicar la misma cuenta como dos alumnos del mismo Club.'),
        ('¿Puedo subir Excel y PDF en la misma migración?','Sí. Una misma migración puede mantener varias cargas y reutilizar lo ya analizado, siempre dentro de sus límites y contexto.'),
        ('¿La Federación puede ver las finanzas privadas de los clubes?','No por el hecho de estar federados. La relación federativa y los datos privados del Club se mantienen separados.'),
        ('¿El asistente importa automáticamente todo lo que detecta?','No. El flujo esperado es analizar, preguntar, normalizar, mostrar vista previa y confirmar. Una conversación no debe ejecutar una importación sin revisión.'),
        ('¿Cómo pido ayuda si no sé cómo preparar los datos?','Abre KOMBAX Migrations desde tu Club o Federación y explica tu situación. Para soporte general, escribe a soporte@kombax.es; si el caso necesita interacción, soporte puede habilitar un chat guiado.'),
        ('¿Puedo borrar el historial después?','Sí. Puedes eliminar una conversación o el historial visible. Se limpia el contenido y los archivos asociados, mientras el consumo ya realizado y la auditoría mínima necesaria permanecen.'),
    ]
    for q,a in faqs:
        S += [faq(q,a), Spacer(1,2.3*mm)]
    S += [PageBreak()]

    # PAGE 10 FINAL CHECKLIST
    S += section_header('09 · CHECKLIST FINAL', 'Qué revisar antes de confirmar', 'Una buena migración no se mide solo por cuántas filas entran, sino por la calidad de las relaciones que quedan después. Usa esta página como control de salida.')
    check=[
        ['Duplicados','No hay dos fichas que representen a la misma persona sin motivo documentado.'],
        ['Email y acceso','16+ nuevos tienen email; históricos sin email quedan pendientes, no bloqueados.'],
        ['Menores','El menor conserva su ficha y el tutor se vincula como relación autorizada.'],
        ['Multiclub','Las membresías se mantienen independientes y no mezclan datos privados.'],
        ['Finanzas','Importes, conceptos, periodos, estados y pagos históricos están diferenciados.'],
        ['Documentos','Archivos y licencias están asociados al titular y ámbito correctos.'],
        ['Vista previa','Campos dudosos e incompletos están visibles antes de confirmar.'],
    ]
    S += [data_table(['Comprobación','OK cuando...'],check,[39*mm,125*mm]), Spacer(1,5*mm)]
    S += [P('Plantilla mínima recomendada para un Club', H2)]
    S += [data_table(['Bloque','Campos útiles'],[
        ['Alumno','ID origen, nombre, apellidos, nacimiento, email si existe, teléfono, estado.'],
        ['Matrícula','Alumno/ID, grupo o disciplina, fecha alta, estado, tarifa.'],
        ['Finanzas','Alumno/ID, concepto, periodo, importe, estado, fecha y método de pago si existe.'],
        ['Documentos','Titular/ID, tipo, entidad, referencia, alta, vencimiento, archivo.'],
    ],[38*mm,126*mm]), Spacer(1,5*mm)]
    S += [P('Plantilla mínima recomendada para una Federación', H2)]
    S += [data_table(['Bloque','Campos útiles'],[
        ['Federado','ID federativo, identidad, club asociado, territorio, disciplina, estado.'],
        ['Licencia','Número, titular/ID, tipo, alta, vencimiento, entidad y documento.'],
        ['Club asociado','ID, nombre, territorio, estado de relación y datos de contacto autorizados.'],
    ],[38*mm,126*mm]), Spacer(1,5*mm)]
    S += [callout('¿Preparado?','Entra en KOMBAX Migrations desde tu perfil Club o Federación. Explica de dónde vienen los datos y adjunta los archivos. Para soporte general, escribe a soporte@kombax.es.',RED), Spacer(1,5*mm)]
    S += [P('<b>KOMBAX</b> convierte la transferencia de datos en un proceso guiado: menos reinicios, menos duplicados y más control antes de empezar a operar.', ParagraphStyle('closing', fontName=font_bold, fontSize=12, leading=16, textColor=TEXT, alignment=TA_CENTER))]

    doc.build(S)
    print(OUT)

if __name__ == '__main__':
    build()
