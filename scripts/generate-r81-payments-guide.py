from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, Color, white
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase.pdfmetrics import stringWidth
from pathlib import Path
import textwrap, os

ROOT=Path('/mnt/data/kombax_r81_taptopay')
OUT=ROOT/'web/assets/docs/GUIA_KOMBAX_COBROS_TAP_TO_PAY_IPHONE_R81.pdf'
OUT.parent.mkdir(parents=True,exist_ok=True)
W,H=A4
BG=HexColor('#07090C'); PANEL=HexColor('#10151B'); PANEL2=HexColor('#151C24'); TEXT=HexColor('#F3F6F8'); MUTED=HexColor('#9AA6B2'); GOLD=HexColor('#FFB02E'); CYAN=HexColor('#45D6FF'); GREEN=HexColor('#5AE08F'); RED=HexColor('#FF5268'); LINE=HexColor('#27313B')
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'; bold='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
pdfmetrics.registerFont(TTFont('D',font)); pdfmetrics.registerFont(TTFont('DB',bold))
logo=ROOT/'web/assets/brand/kombax-symbol-white.png'

def rr(c,x,y,w,h,r=12,fill=PANEL,stroke=LINE):
    c.setFillColor(fill); c.setStrokeColor(stroke); c.roundRect(x,y,w,h,r,fill=1,stroke=1)

def txt(c,s,x,y,size=10,color=TEXT,font='D'):
    c.setFillColor(color); c.setFont(font,size); c.drawString(x,y,s)

def wrap(c,s,x,y,w,size=9,color=MUTED,font='D',leading=None,max_lines=None):
    leading=leading or size*1.45
    words=s.split(); lines=[]; cur=''
    for word in words:
        test=(cur+' '+word).strip()
        if stringWidth(test,font,size)<=w: cur=test
        else:
            if cur: lines.append(cur)
            cur=word
    if cur: lines.append(cur)
    if max_lines: lines=lines[:max_lines]
    c.setFillColor(color); c.setFont(font,size)
    yy=y
    for line in lines:
        c.drawString(x,yy,line); yy-=leading
    return yy

def header(c,kicker,title,sub=''):
    c.setFillColor(BG); c.rect(0,0,W,H,fill=1,stroke=0)
    txt(c,kicker.upper(),42,H-48,7.5,GOLD,'DB')
    txt(c,title,42,H-80,22,TEXT,'DB')
    if sub: wrap(c,sub,42,H-102,W-84,9.2,MUTED,'D',13)
    c.setStrokeColor(LINE); c.line(42,H-124,W-42,H-124)
    txt(c,'KOMBAX · R81 · build 20133',42,24,7.5,MUTED,'DB')
    txt(c,'Stripe Connect · SEPA · Tap to Pay · iPhone',W-240,24,7.5,MUTED,'D')

def bullet(c,title,body,x,y,w,accent=CYAN):
    c.setFillColor(accent); c.circle(x+5,y+3,3,fill=1,stroke=0)
    txt(c,title,x+16,y,9,TEXT,'DB')
    return wrap(c,body,x+16,y-16,w-16,8.4,MUTED,'D',12)

def page1(c):
    c.setFillColor(BG); c.rect(0,0,W,H,fill=1,stroke=0)
    c.setFillColor(HexColor('#11161C')); c.circle(W-70,H-80,185,fill=1,stroke=0)
    c.setFillColor(HexColor('#0B2128')); c.circle(W-40,H-35,112,fill=1,stroke=0)
    c.setFillColor(HexColor('#2A1E09')); c.circle(W-115,H-150,100,fill=1,stroke=0)
    if logo.exists(): c.drawImage(ImageReader(str(logo)),44,H-145,74,74,mask='auto')
    txt(c,'KOMBAX',42,H-177,18,TEXT,'DB')
    txt(c,'PAGOS PRESENCIALES + iPHONE',42,H-225,8,GOLD,'DB')
    txt(c,'Guía de activación y operación',42,H-267,29,TEXT,'DB')
    wrap(c,'Stripe Connect · Tarjeta online · SEPA · Tap to Pay Android · Tap to Pay on iPhone · QR/enlace web',42,H-300,W-95,11,MUTED,'D',16)
    rr(c,42,H-470,W-84,120,18,HexColor('#0E1319'),HexColor('#2D3945'))
    txt(c,'RELEASE',60,H-380,7.5,CYAN,'DB'); txt(c,'R81 · build 20133',60,H-404,16,TEXT,'DB')
    txt(c,'Modelo',250,H-380,7.5,CYAN,'DB'); txt(c,'Direct Charges',250,H-404,16,TEXT,'DB')
    txt(c,'Ámbito inicial',420,H-380,7.5,CYAN,'DB'); txt(c,'España',420,H-404,16,TEXT,'DB')
    wrap(c,'El dinero se cobra en la cuenta Stripe Connect de la identidad comercial. KOMBAX orquesta el servicio y concilia el estado, pero no custodia el dinero del negocio.',60,H-435,W-120,8.6,MUTED)
    txt(c,'Documento integrado en la plataforma y en el ZIP acumulativo R81.',42,42,8,MUTED,'D')

def page2(c):
    header(c,'01 · alcance','Qué activa R81','La fase incorpora un tercer método de cobro sin duplicar el motor financiero existente.')
    y=H-160
    items=[
      ('Tarjeta online','Se mantiene para checkout, cuotas y pagos inmediatos según el servicio habilitado.',CYAN),
      ('Domiciliación SEPA','Continúa para cuotas y cobros recurrentes/diferidos compatibles. El mandato se gestiona en Stripe.',GREEN),
      ('Tap to Pay / NFC','Convierte un móvil compatible en terminal contactless mediante Stripe Terminal nativo.',GOLD),
      ('QR / enlace web','Fallback inmediato para Safari/PWA o dispositivos sin Tap to Pay nativo. Usa Stripe Checkout.',CYAN),
      ('Una cuenta Connect por identidad','Club, Federación, Marca/Showcase u Organizador reutilizan su misma cuenta Stripe.',GREEN),
    ]
    for t,b,a in items:
        rr(c,42,y-62,W-84,64,12,PANEL,PANEL2); bullet(c,t,b,56,y-22,W-116,a); y-=76
    rr(c,42,80,W-84,92,16,HexColor('#15120B'),HexColor('#60471A'))
    txt(c,'PRINCIPIO FINANCIERO',58,144,7.5,GOLD,'DB')
    wrap(c,'KOMBAX no debe crear un segundo sistema por NFC. Todos los canales terminan en el mismo PaymentIntent, webhook, conciliación y trazabilidad del negocio.',58,122,W-116,9.3,TEXT,'D',14)

def page3(c):
    header(c,'02 · frontend','Payment Center premium','Tarjeta, SEPA y cobro presencial se muestran juntos, con estado independiente y acceso contextual.')
    # mock UI
    rr(c,42,H-420,W-84,266,20,HexColor('#0D1117'),HexColor('#29333D'))
    txt(c,'COBROS Y STRIPE',62,H-185,7,GOLD,'DB'); txt(c,'Métodos de cobro',62,H-215,18,TEXT,'DB')
    wrap(c,'Una cuenta Stripe Connect. Tres métodos activables según servicio, capacidad y dispositivo.',62,H-237,W-125,8.5,MUTED)
    labels=[('💳','Tarjeta online','Activa',CYAN),('🏦','SEPA','Activa',GREEN),('📱','Tap to Pay','Activar',GOLD)]
    x=62
    for ico,name,state,a in labels:
        rr(c,x,H-385,145,118,14,HexColor('#121820'),HexColor('#2B3540'))
        txt(c,ico,x+14,H-292,18,TEXT,'D'); txt(c,name,x+14,H-321,10,TEXT,'DB'); txt(c,state,x+14,H-347,8,a,'DB')
        wrap(c,'Estado de capacidad, seguridad y disponibilidad.',x+14,H-366,117,7.2,MUTED)
        x+=156
    y=H-465
    bullet(c,'Visible donde trabaja el usuario','El centro se reutiliza en Finanzas, Showcase, Events y hubs de perfiles comerciales.',42,y,W-84,CYAN)
    bullet(c,'Sin botones muertos','Tap to Pay solo se habilita para cobro si Stripe/card/payouts están listos. En web aparece QR/enlace.',42,y-70,W-84,GOLD)
    bullet(c,'Guía + Assist','El mismo centro abre este PDF y KOMBAX Assist con prompts seguros, sin pedir tarjetas, PIN, IBAN completos o claves.',42,y-140,W-84,GREEN)

def page4(c):
    header(c,'03 · perfiles','Quién puede cobrar','Stripe Connect es una capacidad comercial reutilizable, no una función exclusiva del Club.')
    rows=[
      ('Club','Cuotas, matrículas, seminarios, material','Tarjeta · SEPA · Tap to Pay · QR'),
      ('Federación','Licencias, inscripciones, servicios presenciales','Tarjeta · SEPA compatible · Tap to Pay · QR'),
      ('Marca / Showcase','Venta presencial y Commerce','Tarjeta · Tap to Pay · QR'),
      ('Organizador de eventos','Taquilla, entradas y servicios del evento','Tarjeta · Tap to Pay · QR'),
    ]
    y=H-175
    for name,use,methods in rows:
        rr(c,42,y-92,W-84,78,12,PANEL,LINE)
        txt(c,name,58,y-35,11,TEXT,'DB'); wrap(c,use,58,y-53,230,8,MUTED); wrap(c,methods,325,y-39,225,8.5,GOLD,'DB',11)
        y-=91
    rr(c,42,86,W-84,96,16,HexColor('#0B1716'),HexColor('#1D554C'))
    txt(c,'REGLA DE IDENTIDAD',58,150,7.5,GREEN,'DB')
    wrap(c,'Cada identidad comercial usa una sola cuenta Connect. Activar un nuevo servicio no crea otra cuenta Stripe; cambia permisos y métodos de cobro sobre la identidad ya verificada.',58,127,W-116,9.2,TEXT)

def flow(c,steps,y,colors=None):
    colors=colors or [CYAN]*len(steps); x=42; total=W-84; gap=10; ww=(total-gap*(len(steps)-1))/len(steps)
    for i,(s,a) in enumerate(zip(steps,colors)):
        rr(c,x,y,ww,66,11,PANEL,LINE); txt(c,str(i+1),x+12,y+42,8,a,'DB'); wrap(c,s,x+12,y+24,ww-24,7.7,TEXT,'DB',10)
        if i<len(steps)-1:
            c.setStrokeColor(MUTED); c.line(x+ww,y+33,x+ww+gap,y+33)
        x+=ww+gap

def page5(c):
    header(c,'04 · Android','Tap to Pay en Android','La APK utiliza Stripe Terminal nativo 5.8.1; el WebView sigue siendo la interfaz KOMBAX.')
    flow(c,['KOMBAX crea venta','Backend crea Direct Charge','Token Terminal + Location','SDK conecta Tap to Pay','Cliente acerca tarjeta','Webhook concilia'],H-255,[CYAN,CYAN,GOLD,GOLD,GREEN,GREEN])
    y=H-335
    bullet(c,'Requisitos del móvil','Android 13+, NFC, hardware-backed keystore compatible, permiso de ubicación e internet.',42,y,W-84,GOLD)
    bullet(c,'Entorno seguro','En producción no debe estar en modo debug ni con opciones de desarrollador activas. Stripe valida además la integridad del dispositivo.',42,y-70,W-84,RED)
    bullet(c,'Datos de tarjeta','KOMBAX no recibe PAN, PIN ni criptogramas. La pantalla sensible la controla Stripe Terminal.',42,y-140,W-84,GREEN)
    bullet(c,'APK','El ZIP incluye el proyecto Android con Terminal. Para la APK/AAB release solo falta la firma privada local, que nunca se empaqueta.',42,y-210,W-84,CYAN)

def page6(c):
    header(c,'05 · iPhone hoy','Safari/PWA antes de App Store','Los usuarios de iPhone pueden usar KOMBAX completa desde Safari; el cobro presencial se resuelve con QR/enlace hasta disponer de app nativa.')
    rr(c,42,H-355,235,170,18,PANEL,LINE); txt(c,'iPhone · Safari',60,H-220,12,TEXT,'DB'); txt(c,'WEB / PWA',60,H-246,7.5,CYAN,'DB')
    wrap(c,'Gestión, Social, Showcase, Events, Finanzas, tarjeta online y SEPA funcionan desde web.',60,H-272,194,8.5,MUTED)
    rr(c,315,H-355,238,170,18,HexColor('#15120B'),HexColor('#60471A')); txt(c,'Cobro presencial',333,H-220,12,TEXT,'DB'); txt(c,'QR / ENLACE',333,H-246,7.5,GOLD,'DB')
    wrap(c,'El negocio indica importe y concepto; KOMBAX crea Stripe Checkout, muestra un QR local y permite copiar/abrir el enlace.',333,H-272,198,8.5,MUTED)
    y=H-430
    bullet(c,'No usa el NFC interno desde Safari','El navegador no puede convertir por sí solo el iPhone en un lector Tap to Pay de Stripe.',42,y,W-84,RED)
    bullet(c,'Mismo backend','El QR sigue siendo un Direct Charge en la cuenta Connect del negocio y termina en el mismo webhook.',42,y-70,W-84,GREEN)
    bullet(c,'Sin esperar a la App Store','Permite vender presencialmente desde iPhone desde el primer día mediante QR/enlace.',42,y-140,W-84,CYAN)

def page7(c):
    header(c,'06 · iPhone nativo','Base iOS preparada','El ZIP incluye una variante iOS que reutiliza la web KOMBAX mediante WKWebView y añade Stripe Terminal nativo.')
    flow(c,['WKWebView carga kombax.es','Puente kombaxTerminal','ConnectionToken backend','Tap to Pay on iPhone','PaymentIntent Direct Charge','Webhook R81'],H-255,[CYAN,CYAN,GOLD,GOLD,GREEN,GREEN])
    y=H-335
    bullet(c,'Incluido en /ios','SwiftUI, WKWebView, bridge Terminal, project.yml y entitlement de Tap to Pay.',42,y,W-84,CYAN)
    bullet(c,'Pendiente externo Apple','Apple Developer debe autorizar el entitlement para el Team. Después se firma y publica por TestFlight/App Store.',42,y-70,W-84,GOLD)
    bullet(c,'Una sola experiencia','La misma pantalla web detecta si existe puente iOS; entonces ofrece “Cobrar con este iPhone”.',42,y-140,W-84,GREEN)
    bullet(c,'Sin secretos','No se incluyen certificados, .p12, provisioning profiles, claves Stripe ni credenciales privadas.',42,y-210,W-84,RED)

def page8(c):
    header(c,'07 · backend','Stripe Terminal + Supabase','R81 amplía el backend sin abrir tablas financieras al cliente.')
    cols=[('terminal_locations_r81','Location de Stripe por identidad comercial.'),('terminal_sales_r81','Venta presencial, canal, importe, estado y referencia.'),('payment_attempts','Intento financiero común para trazabilidad e idempotencia.'),('app_stripe_event_apply_v267','Reconciliación de succeeded, failed, refunded y disputed.')]
    y=H-175
    for i,(a,b) in enumerate(cols):
        rr(c,42,y-70,W-84,58,12,PANEL,LINE); txt(c,a,58,y-35,9.2,CYAN if i<2 else GOLD,'DB'); wrap(c,b,245,y-35,300,8.3,MUTED); y-=72
    rr(c,42,92,W-84,106,16,HexColor('#0B1716'),HexColor('#1D554C'))
    txt(c,'SEGURIDAD DE ACCESO',58,164,7.5,GREEN,'DB')
    wrap(c,'Las tablas Terminal tienen RLS activado y no se conceden a authenticated/anon. El frontend trabaja a través de RPC y Edge Functions controladas. stripe-terminal exige JWT; stripe-webhook conserva autenticación por firma Stripe.',58,141,W-116,9,TEXT)

def page9(c):
    header(c,'08 · seguridad','Qué KOMBAX guarda y qué no','El diseño minimiza datos sensibles y mantiene la responsabilidad de cobro en Stripe Connect.')
    rr(c,42,H-375,245,208,16,HexColor('#0B1716'),HexColor('#1D554C')); txt(c,'SÍ guarda',60,H-205,11,GREEN,'DB')
    for i,s in enumerate(['IDs Stripe necesarios','Estado del intento y venta','Importe / concepto','Identidad comercial','Location y canal','Referencia interna KOMBAX']): txt(c,'✓ '+s,60,H-237-i*24,8.5,TEXT,'D')
    rr(c,307,H-375,246,208,16,HexColor('#1A1012'),HexColor('#5A2630')); txt(c,'NO guarda',325,H-205,11,RED,'DB')
    for i,s in enumerate(['Número completo de tarjeta','PIN','Criptograma NFC','Clave secreta Stripe en app','IBAN completo en chat','Certificados Apple/Android']): txt(c,'× '+s,325,H-237-i*24,8.5,TEXT,'D')
    y=H-440
    bullet(c,'Direct Charges','El cargo pertenece a la cuenta conectada del negocio. KOMBAX no actúa como monedero del comercio.',42,y,W-84,GOLD)
    bullet(c,'Webhook como fuente de verdad','La UI no marca un pago como definitivo por sí sola; Stripe reconcilia el estado financiero.',42,y-70,W-84,CYAN)
    bullet(c,'Idempotencia','request_id y claves de idempotencia reducen cobros duplicados en reintentos.',42,y-140,W-84,GREEN)

def page10(c):
    header(c,'09 · operación','Cómo cobrar en el día a día','Flujo común para una tienda, club, federación u organizador.')
    steps=[
      ('1. Abrir Cobros','Entrar en Finanzas, Mi Showcase, Mis Eventos o el hub comercial.'),
      ('2. Revisar Stripe','La cuenta debe estar verificada, payouts y tarjeta activos.'),
      ('3. Activar presencial','Habilitar Tap to Pay / cobro presencial para esa identidad.'),
      ('4. Configurar Location','Nombre y dirección física una única vez por identidad.'),
      ('5. Importe y concepto','Indicar total y referencia opcional: cuota, producto, ticket o servicio.'),
      ('6. Elegir canal','Móvil nativo: Tap to Pay. Safari/web: QR o enlace.'),
      ('7. Cobrar','Stripe muestra la interfaz segura de presentación de tarjeta.'),
      ('8. Conciliar','KOMBAX recibe el webhook y actualiza venta/cuota/estado.')]
    y=H-164
    for i,(a,b) in enumerate(steps):
        col=i%2; row=i//2; x=42+col*260; yy=y-row*126
        rr(c,x,yy-100,244,96,14,PANEL,LINE); txt(c,a,x+14,yy-31,9.2,GOLD if i in (2,3,5) else CYAN,'DB'); wrap(c,b,x+14,yy-52,214,8.1,MUTED)

def page11(c):
    header(c,'10 · casos','Ejemplos por negocio','El mismo módulo se adapta al contexto de venta.')
    examples=[
      ('Club','60 € · Cuota mensual','Tap to Pay en recepción; referencia a cuota si se desea conciliar automáticamente.'),
      ('Marca','42 € · Guantes de boxeo','Cobro presencial en tienda o stand; QR desde iPhone Safari si no hay app.'),
      ('Eventos','25 € · Entrada taquilla','Cobro inmediato presencial. El servicio puede asociarse al evento/ticketing.'),
      ('Federación','35 € · Licencia / inscripción','Cobro directo sobre Connect de la federación, con referencia a servicio interno.')]
    y=H-175
    for name,price,body in examples:
        rr(c,42,y-105,W-84,92,14,PANEL,LINE); txt(c,name,58,y-42,10,TEXT,'DB'); txt(c,price,190,y-42,10,GOLD,'DB'); wrap(c,body,58,y-64,W-116,8.2,MUTED); y-=106

def page12(c):
    header(c,'11 · KOMBAX Assist','Pide ayuda sin compartir datos sensibles','Assist puede explicar el alta y resolver dudas operativas, pero los datos bancarios y de tarjeta se introducen solo en Stripe.')
    prompts=[
      '“Ayúdame a activar Stripe y dime qué requisito me falta para cobrar.”',
      '“Quiero cobrar cuotas por SEPA y pagos presenciales por Tap to Pay en mi club.”',
      '“Estoy en iPhone Safari: ¿cómo genero un QR para cobrar 45 €?”',
      '“Comprueba si mi perfil de organizador puede habilitar Ticketing y cobro presencial.”',
      '“Explícame por qué Tap to Pay no aparece como disponible en este Android.”',
    ]
    y=H-175
    for i,p in enumerate(prompts):
        rr(c,42,y-58,W-84,48,12,HexColor('#0C1419'),HexColor('#23424E')); txt(c,'ASSIST',56,y-36,6.8,CYAN,'DB'); wrap(c,p,112,y-32,W-168,8.5,TEXT,'D',12); y-=64
    rr(c,42,94,W-84,105,16,HexColor('#1A1012'),HexColor('#5A2630'))
    txt(c,'NUNCA EN EL CHAT',58,165,7.5,RED,'DB')
    wrap(c,'No escribir números completos de tarjeta, PIN, claves API, contraseñas, IBAN completos, documentos de identidad o certificados. Assist debe redirigir esos pasos a Stripe, Apple/Android o al flujo seguro correspondiente.',58,141,W-116,9,TEXT)

def page13(c):
    header(c,'12 · requisitos','Checklist de activación','Qué debe estar listo antes de aceptar pagos presenciales reales.')
    checks=[
      ('Backend R81','Migración aplicada, stripe-terminal activo, webhook v267 activo.'),
      ('Stripe Connect','Cuenta verificada, card_payments activo, payouts activo.'),
      ('Terminal Location','Dirección física creada desde KOMBAX.'),
      ('Android','App release firmada, Android 13+, NFC, hardware compatible, entorno seguro.'),
      ('iPhone nativo','Apple Developer, entitlement aprobado, firma y publicación/TestFlight.'),
      ('Web iPhone','Safari/PWA puede cobrar por QR/enlace sin app nativa.'),
      ('QA','Primero modo TEST: éxito, rechazo, reintento, refund y dispute.'),
    ]
    y=H-170
    for title,body in checks:
        txt(c,'□',44,y,13,GOLD,'DB'); txt(c,title,65,y+1,9,TEXT,'DB'); wrap(c,body,190,y+1,360,8.2,MUTED); y-=63
    rr(c,42,72,W-84,80,14,HexColor('#15120B'),HexColor('#60471A'))
    wrap(c,'No activar cobros live en clientes hasta terminar el smoke TEST con una cuenta Connect piloto y un dispositivo físico compatible.',58,120,W-116,9.2,TEXT,'DB')

def page14(c):
    header(c,'13 · entrega','Qué contiene el ZIP R81','Paquete preparado para GitHub, Netlify, Android Studio y continuación iOS.')
    cols=[
      ('/web','Fuente frontend/PWA canonical.'),('/dist','Build listo para publicar en Netlify.'),('/android','Proyecto Android con Stripe Terminal Tap to Pay.'),('/ios','Base iOS SwiftUI/WKWebView + Stripe Terminal.'),('/supabase','Migraciones y Edge Functions R81.'),('/docs','Informes, QA, guía y trazabilidad.'),('/scripts','Tests, build, preflight, auditorías.'),('/qa','Evidencias QA acumulativas.')]
    y=H-165
    for i,(a,b) in enumerate(cols):
        col=i%2; row=i//2; x=42+col*260; yy=y-row*90
        rr(c,x,yy-70,244,60,12,PANEL,LINE); txt(c,a,x+14,yy-35,9,CYAN if col==0 else GOLD,'DB'); wrap(c,b,x+82,yy-35,148,7.8,MUTED)
    rr(c,42,86,W-84,112,16,HexColor('#0B1716'),HexColor('#1D554C'))
    txt(c,'RELEASE R81 · BUILD 20133',58,162,9,GREEN,'DB')
    wrap(c,'Nueva base acumulativa. Mantiene R80 Stripe/SEPA, R79 internacionalización y todo el producto previo. La firma Android y el entitlement/provisioning Apple siguen siendo secretos externos del propietario y no se incluyen.',58,136,W-116,9,TEXT)

pages=[page1,page2,page3,page4,page5,page6,page7,page8,page9,page10,page11,page12,page13,page14]
c=canvas.Canvas(str(OUT),pagesize=A4)
c.setTitle('KOMBAX R81 · Cobros, Tap to Pay e iPhone')
c.setAuthor('KOMBAX Spain')
for p in pages:
    p(c); c.showPage()
c.save()
print(OUT)
