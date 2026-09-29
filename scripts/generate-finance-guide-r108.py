from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, Frame, Image, KeepTogether, PageBreak, PageTemplate,
    Paragraph, Spacer, Table, TableStyle
)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "pdf" / "KOMBAX_GUIA_FINANZAS_CLUB.pdf"
ASSET = ROOT / "web" / "assets" / "guides" / "finance" / OUT.name

W, H = A4
INK = colors.HexColor("#111317")
PAPER = colors.HexColor("#F4F1EC")
RED = colors.HexColor("#E6253B")
DEEP_RED = colors.HexColor("#8F1022")
MUTED = colors.HexColor("#67707B")
LINE = colors.HexColor("#D9D3CA")
GREEN = colors.HexColor("#157A52")


def register_fonts():
    candidates = [
        ("KX", r"C:\Windows\Fonts\arial.ttf"),
        ("KX-Bold", r"C:\Windows\Fonts\arialbd.ttf"),
        ("KX-Black", r"C:\Windows\Fonts\impact.ttf"),
    ]
    for name, path in candidates:
        if Path(path).exists():
            pdfmetrics.registerFont(TTFont(name, path))
    return (
        "KX" if "KX" in pdfmetrics.getRegisteredFontNames() else "Helvetica",
        "KX-Bold" if "KX-Bold" in pdfmetrics.getRegisteredFontNames() else "Helvetica-Bold",
        "KX-Black" if "KX-Black" in pdfmetrics.getRegisteredFontNames() else "Helvetica-Bold",
    )


REGULAR, BOLD, DISPLAY = register_fonts()


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(LINE)
    canvas.line(18 * mm, 13 * mm, W - 18 * mm, 13 * mm)
    canvas.setFont(REGULAR, 7.5)
    canvas.setFillColor(MUTED)
    canvas.drawString(18 * mm, 8.5 * mm, "KOMBAX · Guía de Finanzas para clubes")
    canvas.drawRightString(W - 18 * mm, 8.5 * mm, str(doc.page))
    canvas.restoreState()


def cover(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(INK)
    canvas.rect(0, 0, W, H, fill=1, stroke=0)
    canvas.setFillColor(RED)
    canvas.rect(0, H - 7 * mm, W, 7 * mm, fill=1, stroke=0)
    canvas.setFillColor(colors.HexColor("#25070C"))
    canvas.circle(W * .78, H * .74, 66 * mm, fill=1, stroke=0)
    canvas.setFillColor(DEEP_RED)
    canvas.circle(W * .82, H * .76, 43 * mm, fill=1, stroke=0)
    canvas.setFillColor(colors.white)
    canvas.setFont(BOLD, 15)
    canvas.drawString(20 * mm, H - 25 * mm, "K O M B A X")
    canvas.setFillColor(RED)
    canvas.setFont(DISPLAY, 41)
    canvas.drawString(20 * mm, H - 80 * mm, "FINANZAS")
    canvas.setFillColor(colors.white)
    canvas.drawString(20 * mm, H - 98 * mm, "DEL CLUB")
    canvas.setFont(BOLD, 16)
    canvas.drawString(20 * mm, H - 118 * mm, "Guía completa de uso")
    canvas.setFont(REGULAR, 11)
    canvas.setFillColor(colors.HexColor("#C9CED5"))
    canvas.drawString(20 * mm, H - 129 * mm, "Cargos · cuotas · avisos · tarjeta · recibos · informes")
    canvas.setFillColor(colors.HexColor("#15191F"))
    canvas.roundRect(20 * mm, 37 * mm, W - 40 * mm, 46 * mm, 5 * mm, fill=1, stroke=0)
    canvas.setFillColor(colors.white)
    canvas.setFont(BOLD, 11)
    canvas.drawString(28 * mm, 69 * mm, "UNA GUÍA PARA TRABAJAR CON SEGURIDAD")
    canvas.setFont(REGULAR, 9.5)
    canvas.setFillColor(colors.HexColor("#C8CED6"))
    canvas.drawString(28 * mm, 59 * mm, "Configura, revisa y documenta cada operación antes de confirmar.")
    canvas.drawString(28 * mm, 51 * mm, "Los cobros con tarjeta se procesan en la cuenta Stripe conectada del club.")
    canvas.setFont(REGULAR, 7.5)
    canvas.setFillColor(colors.HexColor("#8E97A3"))
    canvas.drawString(20 * mm, 18 * mm, "Documento de ayuda integrado en KOMBAX Finanzas y KOMBAX Guías")
    canvas.restoreState()


styles = getSampleStyleSheet()
S = {
    "h1": ParagraphStyle("h1", fontName=DISPLAY, fontSize=25, leading=28, textColor=INK, spaceAfter=10, keepWithNext=True),
    "h2": ParagraphStyle("h2", fontName=BOLD, fontSize=16, leading=20, textColor=INK, spaceBefore=12, spaceAfter=7, keepWithNext=True),
    "h3": ParagraphStyle("h3", fontName=BOLD, fontSize=11.5, leading=15, textColor=DEEP_RED, spaceBefore=8, spaceAfter=4, keepWithNext=True),
    "body": ParagraphStyle("body", fontName=REGULAR, fontSize=9.3, leading=13.5, textColor=INK, spaceAfter=6),
    "small": ParagraphStyle("small", fontName=REGULAR, fontSize=7.8, leading=11, textColor=MUTED),
    "lead": ParagraphStyle("lead", fontName=REGULAR, fontSize=11, leading=16, textColor=colors.HexColor("#353A42"), spaceAfter=10),
    "bullet": ParagraphStyle("bullet", fontName=REGULAR, fontSize=9.1, leading=13, leftIndent=12, firstLineIndent=-7, bulletIndent=3, textColor=INK, spaceAfter=3),
    "step": ParagraphStyle("step", fontName=REGULAR, fontSize=9.2, leading=13.5, textColor=INK, leftIndent=7, spaceAfter=5),
    "call": ParagraphStyle("call", fontName=BOLD, fontSize=9.3, leading=13.5, textColor=INK),
    "toc": ParagraphStyle("toc", fontName=REGULAR, fontSize=10, leading=15, textColor=INK, leftIndent=6, spaceAfter=3),
}


def p(text, style="body"):
    return Paragraph(text, S[style])


def bullet(text):
    return Paragraph("• " + text, S["bullet"])


def callout(title, body, tone="red"):
    bg = colors.HexColor("#FBEAEC") if tone == "red" else colors.HexColor("#EAF6F1")
    accent = RED if tone == "red" else GREEN
    table = Table([[Paragraph(title, S["call"]), Paragraph(body, S["body"])]], colWidths=[42 * mm, 124 * mm])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("BOX", (0, 0), (-1, -1), .7, accent),
        ("LINEBEFORE", (0, 0), (0, 0), 4, accent),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return KeepTogether([table, Spacer(1, 7)])


def steps(items):
    rows = []
    for i, item in enumerate(items, 1):
        rows.append([
            Paragraph(str(i), ParagraphStyle("num", fontName=BOLD, fontSize=10, alignment=TA_CENTER, textColor=colors.white)),
            Paragraph(item, S["step"]),
        ])
    t = Table(rows, colWidths=[9 * mm, 157 * mm], repeatRows=0)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), RED),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("BOX", (0, 0), (-1, -1), .4, LINE),
        ("INNERGRID", (0, 0), (-1, -1), .3, LINE),
        ("LEFTPADDING", (1, 0), (1, -1), 8),
        ("RIGHTPADDING", (1, 0), (1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return t


def matrix(headers, rows, widths=None):
    data = [[Paragraph(str(x), ParagraphStyle("th", fontName=BOLD, fontSize=8, leading=10, textColor=colors.white)) for x in headers]]
    for row in rows:
        data.append([Paragraph(str(x), S["small"]) for x in row])
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), INK),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F3F0EB")]),
        ("BOX", (0, 0), (-1, -1), .5, LINE),
        ("INNERGRID", (0, 0), (-1, -1), .35, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    return t


story = [Spacer(1, 1), PageBreak()]
story += [p("Cómo utilizar esta guía", "h1"), p("Esta guía acompaña el trabajo diario del club. Puedes abrirla desde <b>Finanzas</b>, consultarla como ayuda desplegable o descargar el PDF desde <b>KOMBAX Guías</b>.", "lead")]
story += [callout("ANTES DE EMPEZAR", "Configura el perfil público del club y su logotipo. Ese logotipo se reutiliza en recibos, informes y otras piezas identificativas. Revisa también los permisos del equipo y el estado de la cuenta Stripe antes de ofrecer pagos con tarjeta.", "green")]
story += [p("Índice práctico", "h2")]
toc = [
    "1. Qué controla Finanzas y qué significa cada estado",
    "2. Preparación inicial del club",
    "3. Crear un cargo puntual",
    "4. Automatizar cuotas recurrentes",
    "5. Registrar cobros manuales y pagos parciales",
    "6. Cobrar con tarjeta mediante Stripe",
    "7. Domiciliaciones y SEPA cuando estén habilitadas",
    "8. Crear y gestionar avisos de cobro",
    "9. Recibos, informes y trazabilidad",
    "10. Casos completos y resolución de incidencias",
]
story += [p(x, "toc") for x in toc]

story += [p("1 · Mapa de Finanzas", "h1"), p("Finanzas Premium reúne la visión del club, el detalle de cargos, las reglas automáticas, los cobros comunicados, los recibos y los informes. La información se filtra por año, mes, alumno, grupo, disciplina, categoría, estado, automatización, método de pago y antigüedad de deuda.", "lead")]
story += [matrix(["Concepto", "Qué significa", "Qué debes hacer"], [
    ["Cargo", "Importe que el club asigna a una persona o conjunto de personas.", "Revisar destinatario, concepto, importe, periodo y vencimiento."],
    ["Pendiente", "El cargo todavía conserva saldo.", "Esperar el pago, enviar un aviso o registrar un cobro."],
    ["Parcial", "Se ha pagado una parte; queda saldo abierto.", "Confirmar el importe pendiente antes del siguiente cobro."],
    ["Vencido", "La fecha límite ha pasado y queda saldo.", "Revisar el caso y usar avisos con criterio."],
    ["Cobrado", "El saldo validado cubre el cargo.", "Abrir o descargar el recibo y conciliar el movimiento."],
    ["Pago por validar", "El usuario comunicó un pago que el club aún no ha confirmado.", "Validar si coincide; rechazar con motivo si es erróneo o duplicado."],
    ["Anulado", "El cargo dejó de ser exigible, manteniendo trazabilidad.", "Conservar el motivo; no borrar el historial contable."],
], [27*mm, 77*mm, 62*mm])]
story += [p("Panel principal", "h2")]
story += [bullet("Los indicadores resumen generado, cobrado, pendiente, vencido y pagos por revisar."), bullet("El histograma compara los últimos meses y permite filtrar pulsando una barra."), bullet("La antigüedad de deuda ayuda a separar importes recientes de saldos antiguos."), bullet("Las distribuciones por categoría, grupo o disciplina muestran dónde se concentra la actividad.")]

story += [p("2 · Preparación inicial", "h1"), p("Completa estas comprobaciones antes de crear el primer ciclo real de cobros.", "lead")]
story += [steps([
    "Abre el <b>perfil público del club</b>, añade el logotipo correcto y revisa nombre, contacto y datos visibles. El logo se usa en recibos e informes.",
    "Revisa quién puede gestionar finanzas. Dirección, coordinación, secretaría o economía pueden disponer de capacidades diferentes según la configuración del club.",
    "Define conceptos y tarifas habituales: cuota mensual, matrícula, licencia, material, competición, evento, desplazamiento u otro.",
    "Comprueba alumnos activos, grupos y disciplinas. Una asignación desactualizada puede dirigir un cargo a la persona equivocada.",
    "Abre <b>Cobros y domiciliaciones</b>. Si vas a cobrar con tarjeta, completa la activación segura de Stripe.",
    "Genera primero una vista previa o una simulación. Confirma totales y destinatarios antes de crear cargos reales.",
])]
story += [callout("PRINCIPIO DE CONTROL", "La persona que crea o valida una operación debe comprobar destinatario, importe y periodo. KOMBAX aporta trazabilidad y controles, pero el club conserva la responsabilidad de revisar sus datos.")]

story += [p("3 · Crear un cargo puntual", "h1"), p("Usa <b>+ Nuevo cargo</b> cuando el importe no nace de una regla periódica o cuando necesitas asignar un concepto concreto.", "lead")]
story += [steps([
    "Elige la categoría: cuota, matrícula, licencia, material, competición, evento, desplazamiento u otro.",
    "Escribe un concepto reconocible, por ejemplo: <b>Cuota noviembre · Muay Thai</b>.",
    "Selecciona destinatarios: uno o varios alumnos, un grupo, una disciplina o todos los alumnos activos.",
    "Indica el importe por destinatario. Si hay excepciones, crea cargos separados para conservar claridad.",
    "Selecciona periodo y fecha de vencimiento.",
    "Añade observaciones internas cuando ayuden a justificar la operación.",
    "Revisa la vista previa: número de cargos, total y listado de destinatarios.",
    "Confirma <b>Crear cargos</b>. Después abre el detalle de una fila para comprobar saldo y vencimiento.",
])]
story += [callout("EJEMPLO", "25 alumnos activos × 45,00 € = 1.125,00 €. Si la vista previa muestra 24 alumnos o 1.080,00 €, vuelve atrás y revisa el grupo antes de confirmar.", "green")]

story += [p("4 · Automatizar cuotas recurrentes", "h1"), p("Las automatizaciones sirven para cargos previsibles. Una regla puede guardarse en pausa y activarse después de completar las comprobaciones internas.", "lead")]
story += [steps([
    "Pulsa <b>Nueva automatización</b> y asigna un nombre interno claro.",
    "Define categoría, concepto e importe.",
    "Elige periodicidad: mensual, trimestral, semestral, anual o única.",
    "Indica fecha de inicio, día de generación y día de vencimiento. Los días configurables se mantienen entre 1 y 28 para evitar problemas de calendario.",
    "Selecciona destinatarios: todos los alumnos activos, grupo, disciplina o alumno.",
    "Guarda en pausa cuando todavía estés verificando los datos. Activa solo cuando la simulación sea correcta.",
    "Usa la comprobación en modo seguro para simular sin crear cargos reales. Revisa cantidad y total.",
])]
story += [callout("EVITA DUPLICADOS", "No crees una segunda regla para sustituir otra sin pausar o archivar la anterior. Revisa el periodo y la simulación antes de activar.")]

story += [p("5 · Registrar cobros manuales", "h1"), p("Un cobro manual sirve para registrar dinero recibido fuera del checkout de tarjeta: transferencia, Bizum, efectivo, tarjeta presencial u otro método permitido.", "lead")]
story += [steps([
    "Abre el cargo de la persona y pulsa <b>Registrar cobro</b>.",
    "Indica el importe exacto recibido. KOMBAX permite reflejar pagos parciales.",
    "Selecciona fecha y método.",
    "Añade una referencia útil, como el identificador bancario o el número de caja. No copies datos sensibles de tarjeta.",
    "Incluye una observación si existe una diferencia o acuerdo especial.",
    "Guarda y comprueba el nuevo saldo. Si el cargo queda cubierto, verifica el recibo.",
])]
story += [matrix(["Situación", "Registro recomendado", "Resultado esperado"], [
    ["Transferencia de 45 €", "45 €, transferencia, referencia bancaria.", "Cargo cobrado y recibo disponible."],
    ["Entrega parcial de 20 €", "20 €, efectivo, observación.", "Estado parcial; quedan 25 €."],
    ["Pago comunicado por alumno", "Revisar evidencia y validar.", "Solo tras validar afecta al saldo."],
    ["Comunicación duplicada", "Rechazar con motivo.", "No se supera el importe del cargo."],
], [43*mm, 66*mm, 57*mm])]

story += [p("6 · Cobrar con tarjeta", "h1"), p("Los pagos online se procesan mediante la cuenta Stripe conectada del club. KOMBAX inicia el flujo y actualiza el estado; no almacena el número completo de tarjeta, el CVC ni las credenciales bancarias.", "lead")]
story += [p("Activación del club", "h2"), steps([
    "Abre <b>Cobros y domiciliaciones</b> y revisa el estado de la cuenta.",
    "Pulsa <b>Continuar activación en Stripe</b> cuando falte información.",
    "Completa los datos y verificaciones dentro del entorno seguro de Stripe.",
    "Vuelve a KOMBAX y comprueba: cuenta verificada, cobros activados y abonos activados.",
    "Realiza las pruebas autorizadas del entorno de piloto antes de ofrecer el cobro real.",
])]
story += [p("Pago del alumno", "h2"), steps([
    "El alumno o tutor abre su cuenta y localiza el cargo pendiente.",
    "Pulsa la opción de pago con tarjeta disponible.",
    "Completa el pago en el checkout seguro.",
    "KOMBAX espera la confirmación del proveedor y actualiza el cargo. No cierres manualmente una operación que aún figure pendiente.",
    "Cuando el pago quede confirmado, el recibo estará disponible según los permisos de la cuenta.",
])]
story += [callout("SI STRIPE PIDE INFORMACIÓN", "El estado puede ser pendiente, requiere acción, verificación en curso o restringido. Abre el centro de cobros y completa lo solicitado. No registres el mismo pago manualmente mientras el checkout siga pendiente sin comprobarlo.")]

story += [p("7 · Domiciliaciones y SEPA", "h1"), p("Las funciones de domiciliación aparecen cuando el entorno y el plan del club las tienen habilitadas. Mantén el mandato y la autorización correspondientes antes de ordenar un cobro.", "lead")]
story += [steps([
    "Abre el centro de cobros y comprueba que SEPA esté disponible.",
    "Verifica la identidad de la persona pagadora y la relación con el alumno, especialmente si es menor.",
    "Obtén y conserva la autorización necesaria mediante el flujo habilitado.",
    "Selecciona únicamente cargos pendientes que correspondan al mandato.",
    "Revisa estados pendientes, fallidos o devueltos antes de volver a intentar el cobro.",
    "No marques como cobrado hasta recibir confirmación del proveedor.",
])]

story += [p("8 · Avisos de cobro", "h1"), p("Los avisos ayudan a recordar un vencimiento; no sustituyen la revisión humana en casos sensibles. Configúralos desde <b>Avisos de cobro</b>.", "lead")]
story += [steps([
    "Pulsa <b>Configurar</b>.",
    "Define cuántos días antes del vencimiento se enviará el aviso y la hora de procesamiento.",
    "Elige canales disponibles: aviso dentro de KOMBAX, push y correo electrónico.",
    "Decide si debe existir un nuevo aviso el día del vencimiento.",
    "Activa la agrupación familiar cuando un tutor gestione varios cargos y quieras evitar mensajes repetidos.",
    "Guarda la configuración. Usa <b>Procesar hoy</b> solo cuando necesites ejecutar la revisión programada de ese día.",
    "Consulta el historial y pausa los avisos si detectas datos incompletos o una incidencia.",
])]
story += [callout("MENSAJES CON CONTEXTO", "Un aviso debe identificar el club, el concepto, el importe, el vencimiento y la vía segura para consultar o pagar. Evita exponer información económica en canales o dispositivos compartidos.")]

story += [p("9 · Recibos, informes y trazabilidad", "h1"), p("Los documentos financieros deben poder verificarse después. KOMBAX conserva el actor, los filtros, los totales y el momento de generación cuando se crea un informe financiero.", "lead")]
story += [p("Recibos", "h2")]
story += [bullet("Abre un recibo desde el cargo o desde la pestaña Recibos."), bullet("Comprueba nombre del club, logotipo, persona, concepto, importe, fecha y método."), bullet("Usa Imprimir / Guardar PDF para entregar una copia."), bullet("Si existe un error, anula o corrige mediante el flujo permitido y deja el motivo. No borres la evidencia.")]
story += [p("Informes", "h2")]
story += [bullet("Puedes generar la vista actual, tesorería mensual o anual, cobros, pendientes, vencidos, agrupaciones y estados de cuenta."), bullet("Los filtros activos determinan el conjunto de datos del informe."), bullet("El snapshot conserva el estado histórico aunque los datos cambien después."), bullet("La exportación CSV sirve para trabajo tabular; el PDF sirve para lectura, archivo y presentación.")]
story += [callout("IDENTIDAD VISUAL", "Actualiza primero el logotipo del perfil público. Finanzas utiliza esa identidad en recibos, informes y otras personalizaciones del club.", "green")]

story += [p("10 · Tres casos completos", "h1")]
story += [p("Caso A · Cuota mensual de grupo", "h2"), steps([
    "Confirma que el grupo tiene 18 alumnos activos.",
    "Crea o revisa la automatización: Cuota mensual · 45 € · generación día 1 · vencimiento día 10.",
    "Ejecuta una simulación: deben aparecer 18 cargos y un total de 810 €.",
    "Activa la regla después de comprobarla.",
    "Revisa pagos por validar y el histograma del mes.",
])]
story += [p("Caso B · Pago parcial", "h2"), steps([
    "Abre el cargo de 60 €.",
    "Registra 25 € por transferencia con referencia.",
    "Comprueba estado parcial y saldo de 35 €.",
    "Cuando lleguen los 35 € restantes, registra el segundo cobro y verifica el recibo completo.",
])]
story += [p("Caso C · Cobro con tarjeta", "h2"), steps([
    "Comprueba que Stripe muestra cobros y abonos activos.",
    "El alumno o tutor abre el cargo y paga en el checkout seguro.",
    "Espera la confirmación automática.",
    "Verifica que el cargo quede cobrado y que el recibo use el logotipo correcto.",
])]

story += [p("Resolución de incidencias", "h1"), matrix(["Problema", "Comprobación", "Acción"], [
    ["No aparece un alumno", "Estado activo, grupo, disciplina y club actual.", "Corrige la ficha y vuelve a cargar la vista previa."],
    ["Total inesperado", "Cantidad de destinatarios × importe.", "Cancela antes de crear y revisa el alcance."],
    ["Pago pendiente", "Estado del proveedor y comunicaciones duplicadas.", "Espera confirmación o revisa en Stripe; evita duplicar."],
    ["Tarjeta no disponible", "Estado Connect y requisitos.", "Completa activación segura del club."],
    ["Recibo sin logo", "Logo del perfil público.", "Actualiza el perfil y genera el documento de nuevo si procede."],
    ["Aviso no llega", "Canal, hora, contacto y permisos.", "Corrige datos y procesa de nuevo cuando corresponda."],
    ["Informe no coincide", "Filtros y fecha del snapshot.", "Genera una nueva versión; conserva la anterior."],
], [40*mm, 62*mm, 64*mm])]
story += [p("Lista de verificación semanal", "h2")]
story += [bullet("Revisar pagos por validar y duplicados."), bullet("Comprobar cargos vencidos y acuerdos especiales."), bullet("Conciliar cobros con el proveedor o la caja del club."), bullet("Verificar que avisos y automatizaciones siguen siendo correctos."), bullet("Archivar informes necesarios y registrar incidencias.")]

story += [p("Roles, privacidad y menores", "h1"), p("Cada cuenta debe ver únicamente lo necesario para su función. El acceso se limita por club, rol y contexto activo.", "lead")]
story += [matrix(["Perfil", "Uso habitual"], [
    ["Dirección / economía", "Configuración, cargos, validaciones, informes y seguimiento."],
    ["Secretaría / coordinación", "Gestión operativa permitida por sus capacidades."],
    ["Miembro", "Consulta de sus propios cargos, pagos y recibos."],
    ["Tutor", "Gestión autorizada de cargos asociados a menores o dependientes."],
], [48*mm, 118*mm])]
story += [callout("PROTECCIÓN DE MENORES", "Una persona menor de 18 años no debe realizar directamente compras o activaciones comerciales. El pago debe gestionarse mediante el tutor o la persona adulta autorizada y las restricciones deben respetarse también en el backend.")]
story += [callout("DATOS SENSIBLES", "No escribas números completos de tarjeta, CVC, contraseñas, documentos de identidad o información innecesaria en observaciones, referencias o mensajes.")]

story += [p("Ayuda rápida", "h1"), p("Si necesitas resolver una duda mientras trabajas, abre la ayuda desplegable de Finanzas. Para una revisión completa, abre este PDF desde Finanzas Premium o KOMBAX Guías.", "lead")]
story += [matrix(["Quiero…", "Ruta recomendada"], [
    ["Crear un cargo", "Finanzas Premium → + Nuevo cargo"],
    ["Automatizar una cuota", "Finanzas Premium → Nueva automatización"],
    ["Registrar transferencia o efectivo", "Abrir cargo → Registrar cobro"],
    ["Activar tarjeta", "Cobros y domiciliaciones → Continuar en Stripe"],
    ["Configurar avisos", "Finanzas → Avisos de cobro"],
    ["Abrir un recibo", "Finanzas Premium → Recibos"],
    ["Generar un informe", "Finanzas Premium → Generar informe"],
    ["Consultar esta guía", "Finanzas → Guía completa / KOMBAX Guías"],
], [58*mm, 108*mm])]
story += [Spacer(1, 10), p("KOMBAX mantiene la complejidad técnica en segundo plano para que el club pueda centrarse en revisar, confirmar y documentar cada operación.", "lead")]


def build(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    doc = BaseDocTemplate(str(path), pagesize=A4, leftMargin=18*mm, rightMargin=18*mm, topMargin=18*mm, bottomMargin=18*mm,
                          title="KOMBAX · Guía de Finanzas para clubes", author="KOMBAX")
    cover_frame = Frame(0, 0, W, H, id="cover", leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    body_frame = Frame(18*mm, 18*mm, W-36*mm, H-36*mm, id="body", leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    doc.addPageTemplates([
        PageTemplate(id="Cover", frames=[cover_frame], onPage=cover, autoNextPageTemplate="Body"),
        PageTemplate(id="Body", frames=[body_frame], onPage=footer),
    ])
    doc.build(story)


build(OUT)
ASSET.parent.mkdir(parents=True, exist_ok=True)
ASSET.write_bytes(OUT.read_bytes())
print(OUT)
print(ASSET)
