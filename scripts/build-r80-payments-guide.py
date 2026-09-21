from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle,
                                PageBreak, KeepTogether, HRFlowable)
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from PIL import Image as PILImage

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'web' / 'assets' / 'docs' / 'GUIA_KOMBAX_COBROS_STRIPE_SEPA_R80.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)

# Use a Unicode-safe system font if present. Do not ship the font file itself.
font_regular = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
font_bold = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
if Path(font_regular).exists():
    pdfmetrics.registerFont(TTFont('KxSans', font_regular))
    pdfmetrics.registerFont(TTFont('KxSans-Bold', font_bold))
    F = 'KxSans'; FB = 'KxSans-Bold'
else:
    F = 'Helvetica'; FB = 'Helvetica-Bold'

W, H = A4
M = 16*mm
RED = colors.HexColor('#FF3B30')
RED_D = colors.HexColor('#D9251C')
BG = colors.HexColor('#0B0D10')
PANEL = colors.HexColor('#15191F')
PANEL2 = colors.HexColor('#1D232B')
TEXT = colors.HexColor('#F4F7FA')
MUTED = colors.HexColor('#AEB7C2')
LINE = colors.HexColor('#303844')
GOLD = colors.HexColor('#E2B84B')
CYAN = colors.HexColor('#30D5C8')
GREEN = colors.HexColor('#44D17A')

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name='KxTitle', parent=styles['Title'], fontName=FB, fontSize=26, leading=30, textColor=TEXT, spaceAfter=8))
styles.add(ParagraphStyle(name='KxH1', parent=styles['Heading1'], fontName=FB, fontSize=18, leading=22, textColor=TEXT, spaceBefore=4, spaceAfter=8))
styles.add(ParagraphStyle(name='KxH2', parent=styles['Heading2'], fontName=FB, fontSize=12.5, leading=16, textColor=RED, spaceBefore=8, spaceAfter=5))
styles.add(ParagraphStyle(name='KxBody', parent=styles['BodyText'], fontName=F, fontSize=9.3, leading=14, textColor=TEXT, spaceAfter=6))
styles.add(ParagraphStyle(name='KxSmall', parent=styles['BodyText'], fontName=F, fontSize=7.7, leading=11, textColor=MUTED, spaceAfter=3))
styles.add(ParagraphStyle(name='KxCallout', parent=styles['BodyText'], fontName=FB, fontSize=9.3, leading=14, textColor=TEXT, spaceAfter=4))
styles.add(ParagraphStyle(name='KxCenter', parent=styles['BodyText'], fontName=F, fontSize=8.4, leading=12, textColor=TEXT, alignment=TA_CENTER))
styles.add(ParagraphStyle(name='KxTable', parent=styles['BodyText'], fontName=F, fontSize=7.8, leading=10.5, textColor=TEXT))
styles.add(ParagraphStyle(name='KxTableBold', parent=styles['BodyText'], fontName=FB, fontSize=7.8, leading=10.5, textColor=TEXT))
styles.add(ParagraphStyle(name='KxCode', parent=styles['BodyText'], fontName=F, fontSize=8.2, leading=12, textColor=colors.HexColor('#DDE4EC'), backColor=colors.HexColor('#10141A'), borderColor=LINE, borderWidth=.5, borderPadding=7, spaceAfter=6))


def p(text, style='KxBody'):
    return Paragraph(text, styles[style])

def asset(rel):
    return ROOT / rel

def fit_image(path, max_w, max_h):
    im = PILImage.open(path)
    w,h=im.size
    scale=min(max_w/w,max_h/h)
    return Image(str(path), width=w*scale, height=h*scale)

def pill(text, color=RED):
    t=Table([[p(text,'KxSmall')]], colWidths=[45*mm])
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),color),('TEXTCOLOR',(0,0),(-1,-1),colors.white),
        ('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),
        ('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4),
        ('VALIGN',(0,0),(-1,-1),'MIDDLE')]))
    return t

def callout(title, body, accent=RED):
    t=Table([[p(title,'KxCallout')],[p(body,'KxSmall')]], colWidths=[W-2*M-8*mm])
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),PANEL2),('BOX',(0,0),(-1,-1),.8,accent),
        ('LINEBEFORE',(0,0),(0,-1),4,accent),('LEFTPADDING',(0,0),(-1,-1),9),
        ('RIGHTPADDING',(0,0),(-1,-1),9),('TOPPADDING',(0,0),(-1,0),7),
        ('BOTTOMPADDING',(0,-1),(-1,-1),7)]))
    return t

def section_header(kicker,title,body=None):
    items=[p(kicker.upper(),'KxSmall'),p(title,'KxH1')]
    if body: items.append(p(body))
    items.append(HRFlowable(width='100%',thickness=.7,color=LINE,spaceBefore=2,spaceAfter=8))
    return items

def info_table(rows, widths=None, header=True):
    data=[]
    for r,row in enumerate(rows):
        data.append([p(str(c), 'KxTableBold' if r==0 and header else 'KxTable') for c in row])
    if widths is None: widths=[(W-2*M)/len(rows[0])]*len(rows[0])
    t=Table(data,colWidths=widths,repeatRows=1 if header else 0,hAlign='LEFT')
    style=[('BACKGROUND',(0,0),(-1,0),PANEL2 if header else PANEL),('TEXTCOLOR',(0,0),(-1,-1),TEXT),
           ('GRID',(0,0),(-1,-1),.5,LINE),('VALIGN',(0,0),(-1,-1),'TOP'),
           ('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),
           ('TOPPADDING',(0,0),(-1,-1),5),('BOTTOMPADDING',(0,0),(-1,-1),5)]
    for r in range(1,len(data)):
        style.append(('BACKGROUND',(0,r),(-1,r),PANEL if r%2 else colors.HexColor('#12161C')))
    t.setStyle(TableStyle(style)); return t

def flow_diagram(labels, accents=None):
    accents=accents or [RED]*len(labels)
    cells=[]
    for i,l in enumerate(labels):
        cells.append(p(f'<b>{l}</b>','KxCenter'))
        if i<len(labels)-1: cells.append(p('>', 'KxCenter'))
    widths=[]
    total_arrows=(len(labels)-1)*7*mm
    boxw=(W-2*M-total_arrows)/len(labels)
    for i in range(len(cells)):
        widths.append(boxw if i%2==0 else 7*mm)
    t=Table([cells],colWidths=widths)
    st=[('VALIGN',(0,0),(-1,-1),'MIDDLE'),('TOPPADDING',(0,0),(-1,-1),8),('BOTTOMPADDING',(0,0),(-1,-1),8)]
    bi=0
    for i in range(0,len(cells),2):
        st += [('BACKGROUND',(i,0),(i,0),PANEL2),('BOX',(i,0),(i,0),.8,accents[bi]),('LEFTPADDING',(i,0),(i,0),4),('RIGHTPADDING',(i,0),(i,0),4)]
        bi+=1
    t.setStyle(TableStyle(st)); return t


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(BG); canvas.rect(0,0,W,H,fill=1,stroke=0)
    # Content is later painted over by Platypus; this callback is onPage, so draw only header/footer regions.
    canvas.setFillColor(BG); canvas.rect(0,H-9*mm,W,9*mm,fill=1,stroke=0)
    canvas.setStrokeColor(LINE); canvas.line(M,9*mm,W-M,9*mm)
    canvas.setFont(F,6.8); canvas.setFillColor(MUTED)
    canvas.drawString(M,5.5*mm,'KOMBAX - Guia de cobros Stripe Connect y SEPA - R80')
    canvas.drawRightString(W-M,5.5*mm,f'Pagina {doc.page}')
    canvas.restoreState()

# SimpleDocTemplate background: use page callback that fills before content.
def page_bg(canvas, doc):
    canvas.saveState(); canvas.setFillColor(BG); canvas.rect(0,0,W,H,fill=1,stroke=0); canvas.restoreState(); footer(canvas,doc)

doc=SimpleDocTemplate(str(OUT),pagesize=A4,rightMargin=M,leftMargin=M,topMargin=14*mm,bottomMargin=14*mm,
                      title='KOMBAX - Guia de cobros Stripe Connect y SEPA', author='KOMBAX')
story=[]

# COVER
logo=fit_image(asset('web/assets/brand/kombax-symbol-red.png'),30*mm,30*mm)
hero=fit_image(asset('web/assets/assist/hero-assist.webp'),W-2*M,68*mm)
story += [Spacer(1,10*mm), logo, Spacer(1,5*mm), p('KOMBAX','KxSmall'), p('Cobros con Stripe Connect y domiciliacion SEPA','KxTitle'),
          p('Guia operativa para Clubes, Federaciones, Marcas, vendedores de Showcase y Organizadores de eventos.','KxBody'),
          Spacer(1,4*mm), hero, Spacer(1,6*mm),
          callout('Objetivo de esta guia','Activar y gestionar cobros sin exponer datos bancarios en KOMBAX. Cada identidad comercial utiliza una cuenta Stripe Connect propia. Tarjeta y SEPA se pueden activar de forma independiente segun el servicio.',RED),
          Spacer(1,5*mm),
          info_table([['Version','Base','Alcance'],['R80','R79 build 20130 + correccion de video','Stripe Connect universal + tarjeta + SEPA para servicios compatibles']], [30*mm,58*mm,84*mm]),
          PageBreak()]

# 1
story += section_header('1. Modelo KOMBAX','Una cuenta Stripe por identidad, varios servicios','KOMBAX mantiene una unica relacion Stripe Connect por identidad comercial y reutiliza esa cuenta en los servicios para los que el plan/perfil tenga permisos.')
story += [flow_diagram(['Cliente / tutor','KOMBAX','Stripe del perfil','Banco del perfil'],[CYAN,RED,GOLD,GREEN]),Spacer(1,5*mm),
          callout('El dinero no pasa por KOMBAX','Los cobros se crean como cargos directos en la cuenta conectada del Club, Federacion, Marca, vendedor u Organizador. KOMBAX aporta el software y la gestion; Stripe procesa el pago y liquida al banco configurado por el titular de la cuenta.',GOLD),Spacer(1,5*mm),
          p('<b>Metodos independientes</b>','KxH2'),
          info_table([['Metodo','Uso recomendado','Confirmacion'],['Tarjeta','Showcase Commerce, Ticketing, cuotas o cobros inmediatos','Inmediata / apta para entregar producto o entrada'],['SEPA Direct Debit','Cuotas y cobros recurrentes o diferidos compatibles','Diferida; no usar para entregar una entrada de forma inmediata']], [37*mm,81*mm,54*mm]),
          Spacer(1,5*mm),p('Desde <b>Cobros y Stripe</b> cada metodo puede estar Activo o Desactivado sin desconectar la cuenta Stripe completa.'),PageBreak()]

# 2 eligibility
story += section_header('2. Perfiles y servicios','Quien puede habilitar Stripe Connect','La capacidad sigue al servicio comercial y a los permisos del perfil. No se limita al perfil Club.')
rows=[['Perfil / identidad','Tarjeta','SEPA','Servicios principales'],
      ['Club','Si','Si','Cuotas, Commerce, Ticketing segun plan/activacion'],
      ['Federacion','Si','Si si existe cobro recurrente compatible','Events, Ticketing y servicios habilitados'],
      ['Marca / vendedor Showcase','Si','Activable solo para usos diferidos compatibles','Showcase Commerce y otros servicios comerciales'],
      ['Organizador de eventos / profesional elegible','Si','Activable solo para usos diferidos compatibles','Ticketing y cobros de eventos'],
      ['Otros perfiles vendedores de Showcase','Si','Segun servicio compatible','Commerce si su perfil/plan lo permite']]
story += [info_table(rows,[46*mm,25*mm,42*mm,59*mm]),Spacer(1,6*mm),
          callout('Regla de seguridad de producto','Aunque un perfil pueda activar SEPA, KOMBAX no lo utiliza en un checkout que necesite confirmacion inmediata. Ticketing y Showcase Commerce mantienen tarjeta como metodo inmediato.',RED),PageBreak()]

# 3 activation
story += section_header('3. Activacion','Como habilitar Cobros y Stripe','La configuracion se realiza desde el centro de cobros del perfil. Stripe aloja los pasos sensibles de verificacion y cuenta bancaria.')
story += [p('<b>Paso 1.</b> Abre el perfil que gestionas y entra en <b>Cobros y Stripe</b> desde Finanzas, Mi Showcase, Events/Ticketing o el hub del perfil.'),
          p('<b>Paso 2.</b> Pulsa <b>Configurar Stripe</b> o <b>Completar configuracion</b>. La aplicacion abre el flujo seguro de Stripe Connect.'),
          p('<b>Paso 3.</b> Completa en Stripe la identidad del titular y la cuenta bancaria de liquidacion. No introduzcas esos datos en KOMBAX Assist.'),
          p('<b>Paso 4.</b> Regresa a KOMBAX. El centro mostrara el estado de Stripe, tarjeta, SEPA y abonos.'),
          p('<b>Paso 5.</b> Activa o desactiva <b>Tarjeta</b> y <b>Domiciliacion bancaria SEPA</b> de forma independiente.'),
          Spacer(1,5*mm),
          info_table([['Estado','Significado'],['Cuenta Stripe verificada','La identidad puede operar segun las capacidades concedidas por Stripe.'],['Tarjeta activa','Los servicios inmediatos compatibles pueden crear cargos con tarjeta.'],['SEPA activo','Los servicios recurrentes/diferidos compatibles pueden crear mandatos y adeudos.'],['Abonos activos','Stripe puede liquidar el saldo a la cuenta bancaria configurada.']], [52*mm,120*mm]),PageBreak()]

# 4 club sepa
story += section_header('4. Clubes','Domiciliar las cuotas de alumnos o tutores','El motor de cuotas de KOMBAX sigue siendo la fuente de verdad. Stripe ejecuta el adeudo y KOMBAX concilia el resultado.')
story += [flow_diagram(['Cuota KOMBAX','Mandato SEPA','Adeudo Stripe','Procesando','Pagada'],[RED,CYAN,GOLD,GOLD,GREEN]),Spacer(1,5*mm),
          p('<b>Responsable de pago.</b> En un menor, el pagador puede ser el padre, madre o tutor. El alumno no tiene que ser el titular de la cuenta bancaria.'),
          p('<b>Alta del mandato.</b> El pagador pulsa <b>Domiciliar cuota</b> y completa nombre e IBAN en el flujo seguro de Stripe. KOMBAX guarda referencias tecnicas, estado y ultimos digitos; no almacena el IBAN completo.'),
          p('<b>Cobro.</b> El gestor puede iniciar el adeudo de una cuota pendiente desde Finanzas. La cuota pasa a Procesando y solo se confirma como Pagada cuando Stripe comunica el resultado.'),
          callout('SEPA no es instantaneo','No marques manualmente una cuota como pagada al crear el adeudo. Debe conservar el estado Procesando hasta que llegue la confirmacion de Stripe. Los fallos y devoluciones vuelven a reflejar deuda.',GOLD),
          Spacer(1,5*mm),
          info_table([['Ejemplo','Valor'],['Alumno','Daniel Garcia - 15 anos'],['Pagador','Laura Garcia - tutora'],['Metodo','SEPA **** 4821'],['Mandato','Activo'],['Cuota','45 EUR - octubre'],['Estado inicial','Procesando']], [47*mm,125*mm]),PageBreak()]

# 5 club card/sepa
story += section_header('5. Clubes','Tarjeta y SEPA pueden convivir','Un club puede ofrecer distintas vias de pago sin duplicar cuentas Stripe ni perder la trazabilidad de cuotas.')
story += [info_table([['Escenario','Tarjeta','SEPA'],['Cobro puntual en recepcion / enlace','Recomendado','No necesario'],['Cuota mensual domiciliada','Posible','Recomendado'],['Tutor que autoriza una vez','Posible','Recomendado'],['Cambio de metodo de pago','Disponible','Disponible mediante nuevo mandato'],['Pago manual / efectivo','Se registra aparte','Se registra aparte']], [78*mm,47*mm,47*mm]),Spacer(1,6*mm),
          callout('Una sola ficha financiera','El recibo, la deuda y el historial siguen en KOMBAX. El metodo de pago solo cambia la via por la que se intenta cobrar.',CYAN),PageBreak()]

# 6 showcase
hero2=fit_image(asset('web/assets/brand-heroes/hero-showcase.webp'),W-2*M,52*mm)
story += section_header('6. Marcas y Showcase','Cobrar ventas con la cuenta Stripe del vendedor','Los perfiles habilitados para Showcase Commerce pueden conectar Stripe desde Mi Showcase / centro de vendedor.')
story += [hero2,Spacer(1,5*mm),
          p('<b>Tarjeta.</b> Es el metodo de pago de referencia para checkout inmediato: el pedido puede confirmarse cuando Stripe confirma el cargo.'),
          p('<b>SEPA.</b> La preferencia puede existir en la identidad, pero KOMBAX no la utiliza para confirmar de inmediato una compra de Showcase mientras el adeudo siga pendiente.'),
          p('<b>Cuenta unica.</b> Si la misma identidad usa otros servicios comerciales, reutiliza la misma cuenta conectada; no se crea una cuenta Stripe por producto o por servicio.'),
          callout('Que ve el vendedor','Estado de Stripe, Tarjeta, Domiciliacion SEPA, abonos a banco y acceso a la guia. Las operaciones sensibles siempre redirigen a Stripe.',RED),PageBreak()]

# 7 events
hero3=fit_image(asset('web/assets/brand-heroes/hero-events.webp'),W-2*M,52*mm)
story += section_header('7. Events y organizadores','Ticketing con Stripe Connect','Un organizador de eventos profesional o una organizacion con Ticketing habilitado puede conectar Stripe y gestionar el cobro desde el centro de Events.')
story += [hero3,Spacer(1,5*mm),
          p('<b>Ticketing inmediato.</b> KOMBAX utiliza tarjeta porque la entrada y su QR necesitan una confirmacion de pago compatible con entrega inmediata.'),
          p('<b>Organizador profesional.</b> Si el perfil dispone de la capacidad Events, su hub muestra Cobros y Stripe y permite completar el onboarding de la cuenta conectada.'),
          p('<b>Una cuenta por organizador.</b> Todos sus eventos reutilizan la misma identidad Stripe; el contexto del evento queda en los metadatos y registros de KOMBAX.'),
          callout('No emitir QR con un SEPA pendiente','La domiciliacion puede tardar varios dias en confirmarse. Por eso no se usa para considerar pagada una entrada en el checkout inmediato.',GOLD),PageBreak()]

# 8 federation
story += section_header('8. Federaciones','Cobros por servicios habilitados','La Federacion dispone del mismo centro Stripe cuando su plan o activacion habilita un servicio de cobro.')
story += [p('Puede conectar una cuenta Stripe propia y usar tarjeta en Ticketing u otros servicios comerciales compatibles.'),
          p('SEPA se puede activar como metodo independiente cuando exista un flujo recurrente o diferido compatible. La activacion del metodo no obliga a utilizarlo en todos los servicios.'),
          info_table([['Principio','Aplicacion'],['Identidad financiera','La Federacion es titular de su cuenta conectada.'],['Servicios','Solo cobran los servicios que el plan/permisos tengan habilitados.'],['Metodos','Tarjeta y SEPA se gobiernan de forma independiente.'],['Liquidacion','Stripe abona a la cuenta bancaria configurada por la Federacion.']], [52*mm,120*mm]),PageBreak()]

# 9 states
story += section_header('9. Estados y conciliacion','Como interpretar un cobro SEPA','Los webhooks de Stripe actualizan el estado financiero. El frontend nunca debe inventar que un adeudo ya esta pagado.')
story += [info_table([['Estado KOMBAX','Que significa','Accion'],['Pendiente','La cuota existe pero aun no se ha enviado al banco.','Preparar cobro o cambiar metodo.'],['Procesando','Stripe ha iniciado el adeudo.','Esperar confirmacion.'],['Pagado','Stripe ha confirmado el pago.','Cerrar deuda.'],['Fallido','El adeudo no pudo completarse.','Mantener/reabrir deuda y revisar motivo.'],['Devuelto','Un pago confirmado se ha devuelto.','Reabrir deuda y notificar.'],['Disputado','Existe reclamacion del adeudo.','Revisar en Stripe y mantener trazabilidad.']], [31*mm,74*mm,67*mm]),Spacer(1,6*mm),
          p('<b>Motivos legibles.</b> KOMBAX puede traducir motivos tecnicos de Stripe a mensajes operativos como saldo insuficiente, mandato cancelado, cuenta cerrada o autorizacion revocada.'),PageBreak()]

# 10 assist
assist=fit_image(asset('web/assets/assist/assistant-avatar.webp'),27*mm,27*mm)
story += section_header('10. KOMBAX Assist','Pedir ayuda sin compartir datos sensibles','Assist puede explicar el flujo, comprobar que servicio quieres activar y guiarte hasta el punto seguro de Stripe.')
assist_table=Table([[assist,p('<b>Ejemplos de peticiones</b><br/>"Ayudame a activar cobros con tarjeta para mi evento."<br/><br/>"Quiero domiciliar las cuotas de mi club por SEPA. Que me falta?"<br/><br/>"Revisa si mi Marca tiene Commerce habilitado y como conecto Stripe."<br/><br/>"Soy organizador profesional. Guiame para activar Ticketing y cobrar entradas."','KxBody')]],colWidths=[36*mm,W-2*M-36*mm])
assist_table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),PANEL2),('BOX',(0,0),(-1,-1),.8,RED),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),8),('RIGHTPADDING',(0,0),(-1,-1),8),('TOPPADDING',(0,0),(-1,-1),8),('BOTTOMPADDING',(0,0),(-1,-1),8)]))
story += [assist_table,Spacer(1,6*mm),
          callout('Nunca escribas en Assist','IBAN completo, claves de Stripe, contrasenas, codigos 2FA, documentos de identidad completos ni datos bancarios sensibles. KOMBAX debe enviarte al flujo seguro de Stripe para esos pasos.',RED),PageBreak()]

# 11 checklist
story += section_header('11. Checklist de activacion','Antes de cobrar en real','Usa este control tanto en piloto como al incorporar una nueva identidad comercial.')
checks=[['Control','OK'],['Perfil/servicio comercial habilitado','[ ]'],['Cuenta Stripe Connect creada o vinculada','[ ]'],['Identidad verificada en Stripe','[ ]'],['Cuenta bancaria de abono configurada','[ ]'],['Tarjeta activada si hay Commerce/Ticketing','[ ]'],['SEPA activado si hay cobro recurrente/diferido','[ ]'],['Mandato SEPA creado por el pagador (si aplica)','[ ]'],['Prueba en modo test completada','[ ]'],['Webhook de pago procesado correctamente','[ ]'],['Recibo/deuda conciliado en KOMBAX','[ ]'],['Guia y Assist accesibles para el gestor','[ ]']]
story += [info_table(checks,[145*mm,27*mm]),Spacer(1,7*mm),callout('Piloto recomendado','Primero Stripe TEST, despues una organizacion piloto con importes controlados y, solo tras validar estados, fallos y devoluciones, habilitacion progresiva.',CYAN),PageBreak()]

# 12 technical / support
story += section_header('12. Resumen','Que aporta R80','El centro de pagos deja de ser una pantalla exclusiva de tarjeta de Club y se convierte en una capacidad transversal de KOMBAX.')
story += [info_table([['Componente','Resultado'],['Stripe Connect','Una cuenta conectada por identidad comercial.'],['Tarjeta','Activacion independiente para servicios inmediatos.'],['SEPA','Activacion independiente; mandato seguro y adeudo para cuotas/servicios diferidos compatibles.'],['Club Finanzas','Cuotas con tarjeta, pago manual y domiciliacion SEPA.'],['Showcase','Centro Stripe para vendedores con Commerce.'],['Events','Centro Stripe para organizadores/Ticketing.'],['Federacion','Centro Stripe por servicios comerciales habilitados.'],['KOMBAX Assist','Especialista de Stripe, tarjeta y SEPA con proteccion de datos sensibles.'],['Guia','Este PDF esta incluido dentro de los assets de la plataforma y enlazado desde Cobros y Stripe.']], [48*mm,124*mm]),Spacer(1,8*mm),
          p('<b>Recordatorio:</b> KOMBAX es el software de gestion. Stripe procesa el pago en la cuenta conectada del titular y liquida el saldo a su banco. La disponibilidad final de capacidades depende de la verificacion y elegibilidad que Stripe aplique a cada cuenta.'),Spacer(1,5*mm),
          p('Fin de la guia - KOMBAX R80','KxSmall')]

doc.build(story,onFirstPage=page_bg,onLaterPages=page_bg)
print(OUT)
