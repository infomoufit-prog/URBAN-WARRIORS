from pathlib import Path
import runpy, re, unicodedata, json, textwrap
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, Image, KeepTogether
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.units import mm

ROOT=Path(__file__).resolve().parents[1]
base=runpy.run_path(str(ROOT/'scripts'/'create-kombax-territorial-guides.py'))
T=base['T']; S=base['S']; slug=base['slug']
REVIEW='21/09/2026'
SRC=ROOT/'docs'/'11_GUIDES_TERRITORIES_DETAILED'
OUT=ROOT/'artifacts'/'guides'/'territories-detailed'
SRC.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
HERO=ROOT/'artifacts'/'assets'/'kombax-guides-hero.webp'

pdfmetrics.registerFont(TTFont('DejaVu','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('DejaVu-Bold','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))

NATIONAL_SOURCES=[
 ('Ley 39/2022, de 30 de diciembre, del Deporte','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2022-24430'),
 ('Ley Orgánica 8/2021, de protección integral a la infancia y adolescencia frente a la violencia','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2021-9347'),
 ('Real Decreto 849/1993, prestaciones mínimas del Seguro Obligatorio Deportivo','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-1993-16129'),
 ('Ley 19/2007 contra la violencia, el racismo, la xenofobia y la intolerancia en el deporte','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2007-13408'),
 ('Real Decreto 203/2010, Reglamento de prevención de violencia en el deporte','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2010-3904'),
 ('RDL 1/2007, texto refundido de la Ley General para la Defensa de los Consumidores y Usuarios','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2007-20555'),
 ('Ley Orgánica 3/2018, de Protección de Datos Personales y garantía de los derechos digitales','BOE','https://www.boe.es/buscar/act.php?id=BOE-A-2018-16673'),
 ('Protección de datos por defecto','Agencia Española de Protección de Datos','https://www.aepd.es/derechos-y-deberes/cumple-tus-deberes/medidas-de-cumplimiento/proteccion-de-datos-por-defecto'),
 ('Entidades parcialmente exentas - Impuesto sobre Sociedades','Agencia Tributaria','https://sede.agenciatributaria.gob.es/Sede/impuesto-sobre-sociedades/tienes-que-presentar-declaracion-impuesto-sociedades/entidades-parcialmente-exentas.html'),
 ('Hojas informativas de extranjería','Ministerio de Inclusión, Seguridad Social y Migraciones','https://www.inclusion.gob.es/es/web/migraciones/hojas-informativas'),
]

# Evidence-based clarifications confirmed in current official portals during this review.
EXTRA={
 'AN':[('Protección de menores','La Junta publica anexos operativos para adhesión al protocolo, designación de delegado/a, análisis de riesgos, códigos de conducta, gestión de datos e imágenes, autorizaciones familiares y canal de denuncia. La página oficial figura actualizada en 2025.')],
 'AR':[('Alta registral','El portal actual del Gobierno de Aragón mantiene la inscripción abierta permanentemente y exige, para una entidad nueva, acuerdo de tres o más personas y objeto de práctica o promoción de una modalidad oficialmente reconocida.')],
 'AS':[('Club básico','El portal de Deporte Asturiano publica cinco personas mayores de edad como mínimo para el acta fundacional del club básico y escritura pública; también informa de tres meses como plazo máximo del Registro y silencio positivo.')],
 'IB':[('Elección de régimen','El Registro publica dos vías: régimen general con al menos cinco personas físicas o jurídicas y régimen especial/simplificado con al menos tres personas físicas. En ambas fichas revisadas la solicitud se vincula a la autorización previa de denominación y se publica un plazo de tres meses desde esa autorización.')],
 'CN':[('Tramitación','El Registro de Canarias indica que los procedimientos registrales de las personas jurídicas se tramitan exclusivamente de forma telemática y publica modelos para inscripción, cuentas, cargos, estatutos y cancelación.')],
 'CM':[('Promotores','El portal oficial de Castilla-La Mancha fija un mínimo de cinco personas fundadoras y exige domicilio del club en un municipio de la comunidad para el reconocimiento registral autonómico.')],
 'CL':[('Efectos del registro','La sede oficial declara gratuita la inscripción y la vincula a ayudas públicas y participación en competiciones deportivas oficiales; también publica modelos distintos de club federado y club deportivo popular.')],
 'VC':[('Club o recreación','La sede valenciana diferencia club deportivo (orientado al ámbito federado) y grupo de recreación deportiva (actividad al margen del ámbito federado). Para clubes publica reserva de nombre, un mínimo de tres fundadores y certificado electrónico de adscripción a la federación correspondiente.')],
 'GA':[('Protocolo NNA','El procedimiento PR946A incluye el protocolo de protección de niños, niñas y adolescentes entre la documentación del club y ofrece un asiento registral específico para el protocolo.')],
 'MD':[('Elemental vs básico','Madrid publica documentación distinta: para club elemental acta fundacional y normas internas/estatutos; para club básico, acta fundacional otorgada ante notario y estatutos. La sede publica 15 días desde el acta fundacional para solicitar inscripción.')],
 'MC':[('Reconocimiento','La sede de Murcia vincula la inscripción al reconocimiento oficial deportivo y a la posibilidad de solicitar integración en la federación regional; el expediente de club utiliza acta fundacional y estatutos conforme a modelos oficiales.')],
 'NC':[('Profesiones','Navarra exige inscripción para determinadas profesiones reguladas del deporte y desde 2025 publica el régimen de habilitaciones; esto puede afectar al personal de un club o evento y debe comprobarse antes de contratar o asignar funciones técnicas.')],
 'PV':[('Constitución','El Registro vasco publica un mínimo de tres personas físicas o jurídicas con capacidad de obrar, acta fundacional y estatutos, y ofrece tramitación electrónica.')],
 'RI':[('Efecto registral','La Rioja vincula la inscripción del club a ayudas, reconocimientos y convenios con la Comunidad Autónoma y mantiene tramitación electrónica con certificado.')],
 'CE':[('Régimen local','Ceuta mantiene reglamentos propios para asociaciones deportivas, federaciones y Registro; distingue clubes elementales y básicos y exige afiliación a la federación ceutí correspondiente para actividades y competiciones oficiales.')],
 'ML':[('Expediente registral','La sede de Melilla publica solicitud, acta de constitución, estatutos y DNI de integrantes, además de documentación de representación cuando proceda.')],
}

CITY={'AN':'Sevilla','AR':'Zaragoza','AS':'Oviedo','IB':'Palma','CN':'Las Palmas de Gran Canaria','CB':'Santander','CM':'Toledo','CL':'Valladolid','CT':'Barcelona','VC':'València','EX':'Mérida','GA':'Santiago de Compostela','MD':'Madrid','MC':'Murcia','NC':'Pamplona','PV':'Bilbao','RI':'Logroño','CE':'Ceuta','ML':'Melilla'}

TOPICS=[
 ('01','Crear un club o asociación deportiva','Distinguir la forma deportiva adecuada, preparar constitución y registro y separar el reconocimiento deportivo de las obligaciones fiscales, laborales o mercantiles que puedan coexistir.'),
 ('02','Organizar un evento de deportes de contacto','Clasificar el evento antes de publicitarlo: oficial/no oficial, federado/no federado, con o sin público, recinto habitual o extraordinario, presencia de menores, ticketing y participantes extranjeros.'),
 ('03','Organizar un interclub','Evitar que la palabra “interclub” se use como atajo jurídico. Debe saberse si se trata de entrenamiento, exhibición, encuentro no oficial o competición y qué reglas de seguridad, licencias y seguros aplican.'),
 ('04','Licencias deportivas','Separar licencia o título habilitante para competición oficial de otras acreditaciones internas. La entidad debe consultar la federación y la normativa territorial aplicables a la modalidad concreta.'),
 ('05','Seguros y coberturas','No confundir el Seguro Obligatorio Deportivo de determinados deportistas federados en competición oficial estatal con la responsabilidad civil del organizador, seguros del recinto u otras coberturas territoriales o contractuales.'),
 ('06','Menores','Aplicar como mínimo la LOPIVI: protocolos, monitorización y Delegado/a de protección en entidades que trabajan habitualmente con menores, además de las reglas autonómicas adicionales cuando existan.'),
 ('07','Instalaciones y autorizaciones','Comprobar que el recinto está habilitado para el uso previsto y que la actividad concreta encaja en sus licencias, aforo, seguridad, emergencias y reglas municipales/autonómicas. El alquiler del pabellón no equivale por sí solo a autorización del evento.'),
 ('08','Protección de datos, imagen y comunicaciones','Definir qué datos son necesarios, quién es responsable, base jurídica, información a las personas, conservación, acceso interno y publicación de imágenes. Con menores y datos de salud el análisis debe ser especialmente restrictivo.'),
 ('09','Ticketing, entradas y control de acceso','Informar de precio final, condiciones, identidad del organizador, política de cancelación/reembolso y reglas de acceso; conservar trazabilidad de venta y evitar presentar condiciones de seguridad como si fueran idénticas en todos los recintos.'),
 ('10','Federaciones y relaciones federativas','Confirmar qué federación o entidad deportiva resulta competente, si el evento está reconocido y qué reglamentos técnicos, licencias, arbitraje, pesaje y homologación exige la modalidad concreta.'),
 ('11','Deportistas extranjeros','No asumir que una invitación deportiva resuelve entrada, estancia o trabajo. Revisar nacionalidad, duración, remuneración, actividad, eventual relación laboral y reglas deportivas/federativas de cada persona.'),
 ('12','Patrocinio, marcas y colaboraciones','Documentar contraprestaciones, uso de marca e imagen, soportes, duración, exclusividad, cancelación y obligaciones fiscales. No confundir patrocinio publicitario con una donación o convenio sin contraprestación.'),
 ('13','Organización de combates y participantes','Definir categorías, emparejamientos, reglas, pesaje, personal técnico/arbitral y elegibilidad bajo el reglamento deportivo realmente aplicable. KOMBAX no crea reglas de combate cuando no están verificadas por la entidad competente.'),
 ('14','Expediente y checklist del organizador','Conservar un expediente único: identidad del organizador, recinto, comunicaciones/autorizaciones, seguros, participantes, licencias, personal, menores, ticketing, contratos, incidencias y cierre.'),
 ('15','Obligaciones posteriores al evento','Cerrar incidencias, reembolsos, liquidaciones, conservación documental, comunicaciones a federación/administración cuando procedan y revisión de datos personales para no conservar información sin necesidad.'),
]

COMMON_DECISIONS=[
 ('¿Qué estoy haciendo realmente?','Club, actividad habitual, entrenamiento, interclub, exhibición o competición. La denominación comercial no sustituye la clasificación jurídica/deportiva.'),
 ('¿Quién organiza y asume responsabilidad?','Identificar la persona o entidad organizadora y separar al propietario del recinto, promotor, club, federación y proveedores.'),
 ('¿Dónde se realiza?','Comunidad autónoma, municipio e instalación concreta. Las reglas de recinto, aforo, apertura y actividad pueden depender del nivel local.'),
 ('¿Es oficial o federado?','La Ley 39/2022 vincula el carácter oficial a la calificación/reconocimiento federativo o del CSD según el caso; no debe atribuirse oficialidad por marketing.'),
 ('¿Quién participa?','Edad, licencia, modalidad, procedencia, situación de menores, personal técnico y participantes extranjeros.'),
 ('¿Hay público y venta de entradas?','Si hay ticketing deben revisarse información precontractual, condiciones, cancelación, acceso y seguridad.'),
 ('¿Qué coberturas existen?','Revisar seguro deportivo aplicable, responsabilidad civil, póliza/condiciones del recinto y coberturas específicas sin asumir importes universales.'),
]

DOC_BASE=[
 'Identificación y poderes/representación del organizador o entidad.',
 'Acta fundacional, estatutos y certificado registral cuando se trate de un club o entidad deportiva.',
 'Contrato, cesión o autorización de uso del recinto y ficha técnica/condiciones de la instalación cuando corresponda.',
 'Reglamento deportivo, convocatoria o documento que permita saber si la actividad es oficial, federada, exhibición o entrenamiento.',
 'Listado de participantes con la información mínima necesaria para comprobar elegibilidad, edad y licencia cuando proceda.',
 'Documentación de seguros y teléfonos/procedimientos de asistencia e incidencias.',
 'Protocolo y responsable de protección si participan menores de forma habitual o el caso lo exige.',
 'Condiciones de venta y cancelación/reembolso si existen entradas.',
 'Contratos esenciales con proveedores, patrocinadores y personal cuando proceda.',
 'Registro de incidencias y documentación de cierre del evento.',
]

CONSULT_WHAT=[
 'Clasificación del caso: qué es exactamente la actividad y qué niveles normativos hay que revisar.',
 'Mapa de organismos: comunidad, ayuntamiento, titular del recinto, federación y otros interlocutores.',
 'Checklist personalizado de documentación existente, faltante y pendiente de confirmación.',
 'Revisión cruzada de normas territoriales, reglamento deportivo, condiciones de recinto y operativa real.',
 'Identificación de puntos que deben ser validados por abogado/a, asesor fiscal/laboral, técnico competente, aseguradora, federación o administración cuando exista reserva profesional o competencia ajena a KOMBAX.',
]

# ReportLab setup
pdfmetrics.registerFont(TTFont('DejaVu','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('DejaVu-Bold','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))
PAGE_W,PAGE_H=A4
C_DARK=colors.HexColor('#090B10'); C_RED=colors.HexColor('#F04452'); C_CYAN=colors.HexColor('#37D6E8'); C_TEXT=colors.HexColor('#172033'); C_MUTED=colors.HexColor('#64748B'); C_SOFT=colors.HexColor('#F5F7FA'); C_AMBER=colors.HexColor('#F4B740'); C_GREEN=colors.HexColor('#11856A')
styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='KTitle',fontName='DejaVu-Bold',fontSize=24,leading=28,textColor=colors.white,spaceAfter=7))
styles.add(ParagraphStyle(name='KSub',fontName='DejaVu',fontSize=10,leading=14,textColor=colors.HexColor('#D4DBE6'),spaceAfter=6))
styles.add(ParagraphStyle(name='KH1',fontName='DejaVu-Bold',fontSize=15,leading=19,textColor=C_RED,spaceBefore=8,spaceAfter=6))
styles.add(ParagraphStyle(name='KH2',fontName='DejaVu-Bold',fontSize=11.5,leading=15,textColor=C_TEXT,spaceBefore=6,spaceAfter=4))
styles.add(ParagraphStyle(name='KBody',fontName='DejaVu',fontSize=9.0,leading=13.2,textColor=C_TEXT,spaceAfter=5))
styles.add(ParagraphStyle(name='KSmall',fontName='DejaVu',fontSize=7.3,leading=9.7,textColor=C_MUTED,spaceAfter=3))
styles.add(ParagraphStyle(name='KCall',fontName='DejaVu-Bold',fontSize=9.2,leading=13,textColor=C_TEXT,spaceAfter=2))


def footer(canvas,doc):
    canvas.saveState(); canvas.setFont('DejaVu',7); canvas.setFillColor(C_MUTED)
    canvas.drawString(16*mm,8*mm,f'KOMBAX Guías · {REVIEW} · Información operativa con fuentes oficiales')
    canvas.drawRightString(PAGE_W-16*mm,8*mm,str(doc.page)); canvas.restoreState()

def cover(t, master=False):
    st=[]
    if HERO.exists():
        st += [Image(str(HERO),width=178*mm,height=100.1*mm),Spacer(1,3*mm)]
    title='España · Dossier territorial completo' if master else t['name']
    subtitle='Guía territorial ampliada: club, eventos, interclubs, licencias, menores, seguros, recinto, ticketing y consultoría específica'
    data=[[Paragraph('KOMBAX GUÍAS',ParagraphStyle('tag',fontName='DejaVu-Bold',fontSize=9,textColor=C_CYAN))],[Paragraph(title,styles['KTitle'])],[Paragraph(subtitle,styles['KSub'])],[Paragraph(f'Revisión documental: {REVIEW}',ParagraphStyle('rev',fontName='DejaVu',fontSize=8,textColor=colors.HexColor('#AAB4C3')))]]
    tb=Table(data,colWidths=[178*mm]); tb.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),C_DARK),('LEFTPADDING',(0,0),(-1,-1),8*mm),('RIGHTPADDING',(0,0),(-1,-1),8*mm),('TOPPADDING',(0,0),(-1,-1),2.7*mm),('BOTTOMPADDING',(0,0),(-1,-1),2.7*mm)]))
    st += [tb,Spacer(1,4*mm)]
    warning=Table([[Paragraph('<b>Regla editorial KOMBAX:</b> ninguna ausencia de información se rellena con una suposición. Los requisitos que dependen de municipio, recinto, modalidad, federación, aforo, personal o circunstancias del participante se identifican como “verificación específica”.',styles['KBody'])]],colWidths=[178*mm])
    warning.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#FFF7E6')),('BOX',(0,0),(-1,-1),0.7,C_AMBER),('LEFTPADDING',(0,0),(-1,-1),5*mm),('RIGHTPADDING',(0,0),(-1,-1),5*mm),('TOPPADDING',(0,0),(-1,-1),3*mm),('BOTTOMPADDING',(0,0),(-1,-1),3*mm)]))
    st += [warning,PageBreak()]
    return st

def box(title,text,color=C_CYAN):
    tb=Table([[Paragraph(title,styles['KCall'])],[Paragraph(text,styles['KBody'])]],colWidths=[178*mm])
    tb.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),C_SOFT),('BOX',(0,0),(-1,-1),0.6,color),('LEFTPADDING',(0,0),(-1,-1),4*mm),('RIGHTPADDING',(0,0),(-1,-1),4*mm),('TOPPADDING',(0,0),(-1,-1),2.5*mm),('BOTTOMPADDING',(0,0),(-1,-1),2.5*mm)]))
    return tb

def bullets(items):
    return [Paragraph('• '+x,styles['KBody']) for x in items]

def territory_verified_text(t):
    parts=[]
    for area,status,text in t['differentials']:
        tag='VERIFICADO' if status=='verified' else 'VERIFICACIÓN ESPECÍFICA'
        parts.append((area,tag,text,status))
    for area,text in EXTRA.get(t['code'],[]):
        parts.append((area,'VERIFICADO EN PORTAL OFICIAL DURANTE ESTA REVISIÓN',text,'verified'))
    return parts

def topic_territory_note(t,idx):
    diffs=territory_verified_text(t)
    # Link topics to territory facts conservatively.
    if idx==1:
        rel=[d for d in diffs if any(k in d[0].lower() for k in ['club','registro','entidad','constit','régimen','tipos','promotor','tramit','expediente','efecto'])]
    elif idx in (2,3,7,9,13,14,15):
        rel=[d for d in diffs if 'evento' in d[0].lower() or 'interclub' in d[0].lower()]
    elif idx==6:
        rel=[d for d in diffs if any(k in d[0].lower() for k in ['menor','protección','protocolo'])]
    elif idx==10:
        rel=[d for d in diffs if any(k in d[0].lower() for k in ['feder','competición','recreación'])]
    else:
        rel=[]
    if rel:
        return ' '.join(d[2] for d in rel[:3])
    return 'En esta revisión no se publica un diferencial autonómico único para este punto. Debe aplicarse el marco estatal y comprobar, antes de actuar, si existe una exigencia autonómica, municipal, federativa o del recinto para el caso concreto.'

def detailed_md(t):
    lines=[]
    lines += [f"# KOMBAX Guías - {t['name']} · Dossier territorial ampliado",'',f'**Revisión:** {REVIEW}', '**Tipo:** material informativo y operativo con fuentes oficiales. No sustituye asesoramiento profesional ni una resolución administrativa.','']
    lines += ['## 1. Qué ofrece este dossier','',t['summary'],'', 'Este dossier no se limita a enumerar diferencias. Su función es ayudar a ordenar un expediente real: qué decidir primero, qué documentación preparar, qué puede verificarse con carácter general y qué debe confirmarse con el ayuntamiento, el recinto, la federación, la aseguradora o la administración competente.','']
    lines += ['## 2. Mapa de decisión antes de empezar','']
    for a,b in COMMON_DECISIONS: lines += [f'### {a}',b,'']
    lines += ['## 3. Diferenciales territoriales verificados','']
    for area,tag,text,status in territory_verified_text(t): lines += [f'### {area}',f'**{tag}.** {text}','']
    lines += ['## 4. Ruta práctica - crear y operar una entidad deportiva','',
      '1. Definir si se necesita realmente un club deportivo, una sección, una figura recreativa u otra estructura admitida por el territorio.','2. Verificar denominación y modelo oficial antes de firmar documentos, especialmente cuando el registro publique reserva de nombre o formularios propios.','3. Preparar acta fundacional, estatutos, órgano de gobierno, domicilio y representación conforme a la vía territorial elegida.','4. Presentar la inscripción en el registro deportivo competente y conservar justificante, resolución y número/certificado registral.','5. Tramitar NIF y revisar obligaciones censales, contables, fiscales, laborales y de facturación según la actividad real; la ausencia de ánimo de lucro no elimina automáticamente estas obligaciones.','6. Si se quiere competir oficialmente, comprobar federación, licencia y reglamentos de la modalidad.','7. Si se trabaja habitualmente con menores, implantar las obligaciones de protección y el protocolo territorial cuando exista.','8. Mantener actualizados cargos, estatutos, domicilio, modalidades y demás datos que el Registro exija comunicar.','']
    lines += ['### Documentación de trabajo que conviene preparar','']+['- '+x for x in DOC_BASE[:5]]+['']
    lines += ['## 5. Ruta práctica - organizar una velada, evento o interclub','',
      '1. Escribir una ficha de clasificación antes de anunciar el evento: organizador, modalidad, fecha, municipio, recinto, aforo previsto, público, entradas, menores, deportistas extranjeros y carácter oficial/no oficial.','2. Preguntar al titular del recinto qué usos cubre su licencia y qué documentación técnica, de seguridad, emergencia o asistencia exige para el evento concreto.','3. Consultar al ayuntamiento/administración competente si la actividad requiere licencia, autorización, comunicación u otro título; no existe un permiso único estatal para todas las veladas.','4. Confirmar con la federación o entidad deportiva competente si se pretende que los combates sean oficiales, computables o sujetos a licencias, arbitraje o reglamento federativo.','5. Separar seguros: seguro deportivo de participantes cuando proceda, responsabilidad civil del organizador y otras coberturas exigidas por recinto, contrato o norma territorial.','6. Preparar protección de menores, acceso, datos e imagen, ticketing, plan de incidencias y, si procede, asistencia sanitaria/seguridad conforme a la clasificación real del evento.','7. Validar individualmente a participantes extranjeros si la actividad puede implicar entrada, estancia, remuneración o trabajo en España.','8. No abrir venta pública hasta que la información esencial del evento, organizador, condiciones y política de cancelación/reembolso estén definidas.','']
    lines += ['## 6. Las 15 materias KOMBAX aplicadas a este territorio','']
    for n,(code,title,desc) in enumerate(TOPICS,1):
        note=topic_territory_note(t,n)
        lines += [f'### {code}. {title}',desc,'',f'**Aplicación en {t["name"]}:** {note}','']
    lines += ['## 7. Ejemplo operativo','',f'Un club quiere celebrar en {CITY[t["code"]]} un interclub de deportes de contacto con público, venta de entradas, algunos participantes menores y dos deportistas residentes fuera de España. KOMBAX no determina de forma automática que el evento esté autorizado. El plan correcto es: (1) identificar organizador y naturaleza del encuentro; (2) verificar recinto y municipio; (3) consultar modalidad/federación y licencias; (4) revisar seguros y asistencia; (5) aplicar protección de menores; (6) revisar ticketing y privacidad; (7) estudiar individualmente la situación de participantes extranjeros; y (8) conservar un expediente de decisiones y documentos.','']
    lines += ['## 8. Checklist antes de publicar o ejecutar','']+['- [ ] '+x for x in [
        'Entidad/organizador identificado y con representación suficiente.','Naturaleza deportiva del evento clasificada y, si se afirma oficialidad, soporte federativo/localizado.','Recinto y municipio verificados para la actividad concreta.','Seguros revisados por cobertura, asegurados, fechas, exclusiones y actividad.','Participantes y licencias validados cuando proceda.','Menores: protocolo, Delegado/a, autorizaciones y procedimiento de incidencias preparados cuando correspondan.','Ticketing: precio, condiciones, organizador y cancelación/reembolso definidos.','Datos e imagen: información, accesos, conservación y publicaciones revisadas.','Participantes extranjeros revisados individualmente cuando proceda.','Documentación de cierre, incidencias y reembolsos prevista.']]+['']
    lines += ['## 9. Cuándo pasar a KOMBAX Consultoría','']
    for x in t['consult']: lines += ['- '+x]
    lines += ['- La Administración, el recinto y la federación dan instrucciones que parecen incompatibles o incompletas.','- El usuario necesita transformar esta guía en un expediente concreto con documentos, responsables y fechas.','', '**Qué puede aportar KOMBAX Consultoría:**','']+['- '+x for x in CONSULT_WHAT]+['']
    lines += ['## 10. Qué KOMBAX Consultoría no debe prometer','', 'KOMBAX no debe presentar como dictamen jurídico, fiscal, laboral, sanitario o técnico una revisión que legalmente deba realizar un profesional habilitado. Tampoco garantiza la concesión de una autorización, licencia o inscripción. Su valor es ordenar el caso, localizar fuentes y organismos, revisar coherencia documental y señalar qué validaciones externas son necesarias.','']
    lines += ['## 11. Fuentes oficiales territoriales','']
    for k in t['sources']:
        title,org,url=S[k]; lines += [f'- **{title}** - {org}: {url}']
    lines += ['','## 12. Fuentes estatales comunes','']
    for title,org,url in NATIONAL_SOURCES: lines += [f'- **{title}** - {org}: {url}']
    lines += ['','## 13. Límite de actualización','',f'Contenido revisado el {REVIEW}. Antes de ejecutar una actuación real deben comprobarse la versión vigente de las normas, la sede electrónica del territorio y, cuando proceda, las ordenanzas municipales, condiciones del recinto y reglamentos federativos. Si la fuente oficial no ofrece una regla única, KOMBAX la mantiene como verificación específica en lugar de inventar un requisito.','']
    return '\n'.join(lines)

def pdf_story(t):
    st=cover(t)
    st += [Paragraph('1. Cómo utilizar este dossier',styles['KH1']),Paragraph(t['summary'],styles['KBody']),Paragraph('La utilidad del dossier es convertir una consulta genérica en un plan verificable. Por eso separa cuatro capas: marco estatal, diferencial autonómico, requisitos que dependen de municipio/recinto/federación y puntos que requieren revisión específica.',styles['KBody'])]
    st += [Paragraph('2. Mapa de decisión',styles['KH1'])]
    rows=[]
    for a,b in COMMON_DECISIONS: rows.append([Paragraph(a,styles['KCall']),Paragraph(b,styles['KBody'])])
    tb=Table(rows,colWidths=[48*mm,130*mm],repeatRows=0); tb.setStyle(TableStyle([('GRID',(0,0),(-1,-1),0.35,colors.HexColor('#D7DEE8')),('BACKGROUND',(0,0),(0,-1),colors.HexColor('#F3F6FA')),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),3*mm),('RIGHTPADDING',(0,0),(-1,-1),3*mm),('TOPPADDING',(0,0),(-1,-1),2*mm),('BOTTOMPADDING',(0,0),(-1,-1),2*mm)])); st += [tb]
    st += [Paragraph('3. Diferenciales territoriales verificados',styles['KH1'])]
    for area,tag,text,status in territory_verified_text(t):
        col=C_GREEN if status=='verified' else C_AMBER
        st += [box(area+' · '+tag,text,col),Spacer(1,2*mm)]
    st += [PageBreak(),Paragraph('4. Crear y operar un club o entidad deportiva',styles['KH1']),Paragraph('Ruta práctica',styles['KH2'])]
    for x in [
      'Definir la figura territorial adecuada y no escogerla solo por el nombre.','Comprobar denominación, modelos y requisitos publicados por el registro antes de firmar.','Preparar acta, estatutos, órgano de gobierno, domicilio y representación.','Presentar la inscripción y conservar justificante, resolución y certificado/número registral.','Gestionar NIF y obligaciones fiscales/contables/laborales según la actividad real.','Verificar federación y licencias si se quiere participar en competición oficial.','Implantar protección de menores cuando proceda.','Mantener actualizados cargos, estatutos, domicilio y modalidades.']:
        st.append(Paragraph('• '+x,styles['KBody']))
    st += [Paragraph('Expediente base',styles['KH2'])]+bullets(DOC_BASE[:5])
    st += [box('Punto territorial',topic_territory_note(t,1),C_CYAN)]
    st += [Paragraph('5. Organizar un evento o interclub',styles['KH1'])]
    for x in [
      'Clasificar la actividad antes de anunciarla.','Identificar municipio y recinto y confirmar qué uso/autorización cubre la instalación.','Comprobar con la federación si existe oficialidad, licencia o reglamento aplicable.','Separar seguro deportivo, responsabilidad civil y otras coberturas.','Preparar menores, acceso, datos, imagen, asistencia e incidencias.','Si se venden entradas, fijar identidad del organizador, condiciones, precio final y cancelación/reembolso.','Revisar individualmente a deportistas extranjeros cuando haya movilidad, remuneración o trabajo.','Mantener un expediente de decisiones y evidencias.']:
        st.append(Paragraph('• '+x,styles['KBody']))
    st += [box('Punto territorial',topic_territory_note(t,2),C_CYAN)]
    st += [PageBreak(),Paragraph('6. Las 15 materias KOMBAX aplicadas al territorio',styles['KH1'])]
    for n,(code,title,desc) in enumerate(TOPICS,1):
        note=topic_territory_note(t,n)
        st += [Paragraph(f'{code}. {title}',styles['KH2']),Paragraph(desc,styles['KBody']),Paragraph(f'<b>Aplicación en {t["name"]}:</b> {note}',styles['KBody'])]
    st += [PageBreak(),Paragraph('7. Ejemplo operativo',styles['KH1']),Paragraph(f'Un club quiere celebrar en {CITY[t["code"]]} un interclub de deportes de contacto con público, venta de entradas, algunos menores y dos participantes residentes fuera de España. La palabra “interclub” no resuelve por sí sola el régimen aplicable. El expediente debe identificar organizador, clasificación deportiva, recinto y municipio, modalidad/federación, seguros, menores, ticketing, privacidad y la situación individual de los participantes extranjeros. Solo después se puede decidir qué documentación y validaciones faltan.',styles['KBody'])]
    st += [Paragraph('8. Checklist de decisión',styles['KH1'])]+bullets([
        'Organizador y representación identificados.','Clasificación oficial/no oficial documentada.','Recinto y municipio revisados para la actividad concreta.','Seguros y exclusiones revisados.','Participantes/licencias comprobados.','Menores: protocolo y responsable de protección preparados cuando proceda.','Ticketing y política de cancelación/reembolso definidos.','Datos e imagen con accesos y conservación definidos.','Participantes extranjeros revisados individualmente.','Plan de cierre e incidencias previsto.'
    ])
    st += [Paragraph('9. KOMBAX Consultoría - cuándo tiene sentido',styles['KH1'])]+bullets(t['consult']+['Existen instrucciones contradictorias entre recinto, ayuntamiento y federación.','Se necesita convertir la guía en un expediente concreto con documentos, responsables y calendario.'])
    st += [box('Qué aporta la consulta',' '.join(CONSULT_WHAT),C_RED),Paragraph('Límite del servicio',styles['KH2']),Paragraph('KOMBAX Consultoría no debe prometer una autorización ni sustituir dictámenes jurídicos, fiscales, laborales, sanitarios o técnicos reservados a profesionales habilitados. Su papel es ordenar el supuesto, localizar las fuentes y responsables, revisar coherencia documental y señalar las validaciones externas necesarias.',styles['KBody'])]
    st += [PageBreak(),Paragraph('10. Fuentes oficiales del territorio',styles['KH1'])]
    for k in t['sources']:
        title,org,url=S[k]; st.append(Paragraph(f'<b>{title}</b> · {org}<br/><font size="7">{url}</font>',styles['KSmall']))
    st += [Paragraph('11. Fuentes estatales comunes',styles['KH1'])]
    for title,org,url in NATIONAL_SOURCES: st.append(Paragraph(f'<b>{title}</b> · {org}<br/><font size="7">{url}</font>',styles['KSmall']))
    st += [Paragraph('12. Vigencia y verificación final',styles['KH1']),Paragraph(f'Última revisión documental: {REVIEW}. Antes de actuar deben revisarse las versiones vigentes, la sede electrónica autonómica y, cuando proceda, ordenanzas municipales, condiciones del recinto y reglamentos federativos. La ausencia de una regla publicada no se transforma en una suposición.',styles['KBody'])]
    return st

def build_pdf(t,path):
    doc=SimpleDocTemplate(str(path),pagesize=A4,rightMargin=16*mm,leftMargin=16*mm,topMargin=14*mm,bottomMargin=14*mm,author='KOMBAX Spain',title=f"KOMBAX Guías - {t['name']} - Dossier territorial ampliado")
    doc.build(pdf_story(t),onFirstPage=footer,onLaterPages=footer)

# Write detailed markdown + PDFs
index={'review_date':REVIEW,'territories':[],'principle':'No inventar. Diferenciar marco estatal, autonómico, municipal/federativo y verificación específica.'}
for t in T:
    md=SRC/f"{t['code']}_{slug(t['name'])}_DETALLADO.md"
    md.write_text(detailed_md(t),encoding='utf-8')
    pdf=OUT/f"KOMBAX_GUIAS_DETALLADA_{t['code']}_{slug(t['name']).upper().replace('-','_')}.pdf"
    build_pdf(t,pdf)
    index['territories'].append({'code':t['code'],'name':t['name'],'markdown':str(md.relative_to(ROOT)),'pdf':str(pdf.relative_to(ROOT)),'territorial_sources':t['sources'],'consulting_triggers':t['consult']})

# Master PDF: cover + each detailed territory story minus its cover, pagebreak between territories
master=OUT/'KOMBAX_GUIAS_TERRITORIOS_ESPANA_DOSSIER_PROFESIONAL_DETALLADO_2026.pdf'
doc=SimpleDocTemplate(str(master),pagesize=A4,rightMargin=16*mm,leftMargin=16*mm,topMargin=14*mm,bottomMargin=14*mm,author='KOMBAX Spain',title='KOMBAX Guías - Dossier profesional territorial detallado España 2026')
st=cover({'name':'España'},master=True)
st += [Paragraph('Cómo está construido',styles['KH1']),Paragraph('Este dossier reúne el marco operativo común y 19 capas territoriales. Repite deliberadamente información esencial cuando ayuda a que cada comunidad pueda consultarse de forma autónoma. No sustituye la fuente oficial: cada ficha termina con las fuentes territoriales y estatales usadas.',styles['KBody']),Paragraph('Territorios incluidos',styles['KH1'])]
for i,t in enumerate(T,1): st.append(Paragraph(f'{i:02d}. {t["name"]}',styles['KBody']))
st.append(PageBreak())
for i,t in enumerate(T):
    st += [Paragraph(t['name'],ParagraphStyle('territoryHead',fontName='DejaVu-Bold',fontSize=22,leading=26,textColor=C_TEXT,spaceAfter=6)),Paragraph(t['summary'],styles['KBody'])]
    # Use full story without cover and without duplicate first pages
    content=pdf_story(t)
    # remove cover elements up to first page break
    cut=0
    for j,x in enumerate(content):
        if isinstance(x,PageBreak): cut=j+1; break
    st += content[cut:]
    if i<len(T)-1: st.append(PageBreak())
doc.build(st,onFirstPage=footer,onLaterPages=footer)
index['master_pdf']=str(master.relative_to(ROOT))
(SRC/'territories_detailed_index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2),encoding='utf-8')

# Research / verification memo
memo=['# KOMBAX Guías - Nota metodológica de la edición territorial detallada','',f'**Revisión:** {REVIEW}','',
'## Regla de publicación','',
'- No inventar datos ausentes.','- No convertir una práctica frecuente en obligación legal sin fuente.','- No extrapolar una norma autonómica a otra comunidad.','- No fijar tasas, importes de seguro, plazos municipales, personal sanitario/seguridad o requisitos federativos si dependen del caso.','- Mantener visible la frontera entre información general y revisión específica.','',
'## Fuentes','',
'Se priorizan BOE, sedes y portales oficiales autonómicos, AEPD, AEAT, Ministerio de Inclusión y organismos deportivos públicos. Los dossiers incorporan la URL de cada fuente y la fecha general de revisión.','',
'## Uso de KOMBAX Consultoría','',
'El CTA aparece cuando el usuario necesita aplicar el marco a un expediente real, cruzar administraciones, revisar documentación o resolver dependencias de municipio, recinto, federación o circunstancias personales. No se oculta una respuesta pública conocida para forzar una consulta de pago.','']
(SRC/'METODOLOGIA_Y_LIMITES_EDICION_DETALLADA.md').write_text('\n'.join(memo),encoding='utf-8')
print(f'OK detailed: {len(T)} PDFs + master {master}')
