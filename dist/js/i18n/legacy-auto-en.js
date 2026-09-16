import { LEGACY_AUTO_EN_SOURCES } from './legacy-auto-en-sources.js';
import { LEGACY_EN_RB02_EXACT } from './legacy-copy-en-rb02-exact.js';

// RB02 compatibility translator. It is deliberately allow-listed: it only runs for
// Spanish system-copy literals discovered by the i18n audit. It must never be used
// as a general translator for user-authored content.
const PHRASES = [
  ['No se ha podido','Could not'],['No se pudo','Could not'],['No se puede','Cannot'],['No se pueden','Cannot'],
  ['No tienes permiso para','You do not have permission to'],['No tienes permisos para','You do not have permission to'],
  ['No tiene permiso para','Does not have permission to'],['No hay','There are no'],['Todavía no hay','There are no'],
  ['Aún no hay','There are no'],['No existe','There is no'],['No existen','There are no'],
  ['No está disponible','is not available'],['no está disponible','is not available'],['no están disponibles','are not available'],
  ['ya no está disponible','is no longer available'],['ya no están disponibles','are no longer available'],
  ['Debes confirmar','You must confirm'],['Debes aceptar','You must accept'],['Debes seleccionar','You must select'],
  ['Debes indicar','You must enter'],['Debes completar','You must complete'],['Debes iniciar sesión','You must sign in'],
  ['Inicia sesión para','Sign in to'],['Inicia sesión de nuevo','Sign in again'],['Inicia sesión','Sign in'],
  ['Cierra sesión','Sign out'],['Cerrar sesión','Sign out'],['Sesión cerrada','Signed out'],
  ['Selecciona al menos','Select at least'],['Selecciona una','Select a'],['Selecciona un','Select a'],['Selecciona el','Select the'],['Selecciona la','Select the'],
  ['Selecciona los','Select the'],['Selecciona las','Select the'],['Selecciona','Select'],
  ['Introduce tu','Enter your'],['Introduce un','Enter a'],['Introduce una','Enter a'],['Introduce el','Enter the'],['Introduce la','Enter the'],['Introduce','Enter'],
  ['Indica un','Enter a'],['Indica una','Enter a'],['Indica el','Enter the'],['Indica la','Enter the'],['Indica','Enter'],
  ['Escribe un','Enter a'],['Escribe una','Enter a'],['Escribe el','Enter the'],['Escribe la','Enter the'],['Escribe','Enter'],
  ['Revisa el','Review the'],['Revisa la','Review the'],['Revisa los','Review the'],['Revisa las','Review the'],['Revisa','Review'],
  ['Comprueba el','Check the'],['Comprueba la','Check the'],['Comprueba los','Check the'],['Comprueba las','Check the'],['Comprueba','Check'],
  ['Vuelve a intentarlo','Try again'],['Inténtalo de nuevo','Try again'],['inténtalo de nuevo','try again'],
  ['antes de volver a intentarlo','before trying again'],['antes de continuar','before continuing'],['antes de','before'],
  ['después de','after'],['a partir de','from'],['a través de','through'],['dentro de','within'],['fuera de','outside'],
  ['de forma segura','securely'],['de forma automática','automatically'],['automáticamente','automatically'],
  ['de un solo uso','single-use'],['de solo lectura','read-only'],['de forma temporal','temporarily'],
  ['por correo electrónico','by email'],['correo electrónico','email'],['por correo','by email'],
  ['contraseña actual','current password'],['nueva contraseña','new password'],['cambiar la contraseña','change the password'],
  ['cambiar contraseña','change password'],['recuperación de contraseña','password recovery'],
  ['código de recuperación','recovery code'],['código de acceso','access code'],['código de seguridad','security code'],
  ['código de equipo','team code'],['código no válido','invalid code'],['código válido','valid code'],
  ['ha caducado','has expired'],['puede haber caducado','may have expired'],
  ['en revisión','under review'],['pendiente de revisión','pending review'],['pendiente de validación','pending validation'],
  ['pendiente de verificación','pending verification'],['pendiente de aprobación','pending approval'],['pendiente de activación','pending activation'],
  ['pendiente de pago','payment pending'],['pendiente de configurar','pending setup'],['pendiente de completar','pending completion'],
  ['en curso','in progress'],['en pausa','paused'],['enviado correctamente','sent successfully'],['guardado correctamente','saved successfully'],
  ['registrada correctamente','registered successfully'],['actualizada correctamente','updated successfully'],['actualizado correctamente','updated successfully'],
  ['se ha guardado','has been saved'],['se ha actualizado','has been updated'],['se ha eliminado','has been deleted'],
  ['se ha enviado','has been sent'],['se ha creado','has been created'],['se ha publicado','has been published'],
  ['se puede','can be'],['se pueden','can be'],['se debe','must be'],['se deben','must be'],
  ['puede ser','can be'],['pueden ser','can be'],['debe ser','must be'],['deben ser','must be'],
  ['no puede','cannot'],['no pueden','cannot'],['no podrá','will not be able to'],['no podrán','will not be able to'],
  ['puedes','you can'],['puede','can'],['pueden','can'],['debes','you must'],['debe','must'],['deben','must'],
  ['tienes que','you must'],['tiene que','must'],['hay que','must'],
  ['solo si','only if'],['sólo si','only if'],['solo para','only for'],['sólo para','only for'],
  ['solo lectura','read-only'],['solo tú','only you'],['solo tu','only your'],['solo','only'],['sólo','only'],
  ['al menos','at least'],['como máximo','at most'],['máximo de','maximum of'],['hasta un máximo de','up to'],
  ['más de','more than'],['menos de','less than'],['entre 15 y 300 kg','between 15 and 300 kg'],
  ['en este momento','at this time'],['en unos instantes','in a few moments'],['hace unos instantes','a few moments ago'],
  ['por el momento','for now'],['de momento','for now'],['todavía','yet'],['aún','yet'],
  ['para poder','to'],['con el fin de','to'],['con el objetivo de','to'],
  ['con tu cuenta','with your account'],['con esta cuenta','with this account'],['con la cuenta','with the account'],
  ['esta cuenta','this account'],['tu cuenta','your account'],['mi cuenta','my account'],['cuenta conectada','connected account'],
  ['cuenta verificada','verified account'],['cuenta de vendedor','seller account'],['cuenta personal','personal account'],
  ['perfil público','public profile'],['perfil privado','private profile'],['perfil profesional','professional profile'],
  ['perfil Competidor','Competitor profile'],['perfil de competidor','competitor profile'],['perfil de miembro','member profile'],
  ['identidad de miembro','member identity'],['identidad pública','public identity'],['identidad KOMBAX','KOMBAX identity'],
  ['contenido de usuario','user content'],['contenido creado por','content created by'],['contenido público','public content'],
  ['contenido privado','private content'],['contenido multimedia','media content'],['contenido solicitado','requested content'],
  ['datos personales','personal data'],['datos de la cuenta','account data'],['datos del club','club data'],['datos disponibles','available data'],
  ['datos incompletos','incomplete data'],['datos históricos','historical data'],['datos autorizados','authorized data'],
  ['Política de Privacidad','Privacy Policy'],['política de privacidad','privacy policy'],['Condiciones de uso','Terms of Use'],
  ['condiciones de uso','terms of use'],['privacidad y soporte','privacy and support'],['seguridad y acceso','security and access'],
  ['derechos de imagen','image rights'],['protección de menores','child protection'],['seguridad infantil','child safety'],
  ['solicitud de eliminación','deletion request'],['eliminación de cuenta','account deletion'],['eliminar cuenta','delete account'],
  ['solicitud de acceso','access request'],['solicitud de equipo','team request'],['solicitud pendiente','pending request'],
  ['solicitudes pendientes','pending requests'],['solicitud abierta','open request'],['solicitud cancelada','request cancelled'],
  ['miembro del equipo','team member'],['equipo de preparación','preparation team'],['acceso al equipo','team access'],
  ['roles y permisos','roles and permissions'],['rol y los permisos','role and permissions'],['rol real','actual role'],
  ['club activo','active club'],['clubes activos','active clubs'],['mi club','my club'],['tu club','your club'],
  ['comunidad del club','club community'],['portada del club','club cover'],['configuración del club','club settings'],
  ['panel de administración','admin panel'],['administración global','global administration'],['Consola Owner','Owner Console'],
  ['consola Owner','Owner Console'],['acceso maestro','master access'],['operación crítica','critical operation'],
  ['autorización global','global authorization'],['autorización crítica','critical authorization'],['verificación crítica','critical verification'],
  ['venta de entradas','ticket sales'],['control de aforo','capacity control'],['gestión de eventos','event management'],
  ['eventos disponibles','available events'],['evento disponible','available event'],['evento no disponible','event unavailable'],
  ['Mis Eventos','My Events'],['mi evento','my event'],['publicación del evento','event publication'],['organizador del evento','event organizer'],
  ['catálogo y pedidos','catalog and orders'],['catálogo comercial','commercial catalog'],['gestión de stock','stock management'],
  ['estado del pedido','order status'],['estado del evento','event status'],['estado de la cuenta','account status'],
  ['estado de cobros','payment status'],['cobros con tarjeta','card payments'],['activar cobros','activate payments'],
  ['cobro pendiente','payment pending'],['cobros pendientes','pending payments'],['saldo pendiente','outstanding balance'],
  ['pago pendiente','pending payment'],['pagos pendientes','pending payments'],['pago duplicado','duplicate payment'],
  ['documentación financiera','financial documentation'],['informe financiero','financial report'],['estado de cuenta','account statement'],
  ['cuotas pendientes','outstanding fees'],['cuota pendiente','outstanding fee'],['cuota anulada','cancelled fee'],['cuota exenta','exempt fee'],
  ['membresía de alumno','student membership'],['ficha de alumno','student record'],['ficha informativa','information sheet'],
  ['alta de alumno','student registration'],['altas de alumnos','student registrations'],['alumnos y familias','students and families'],
  ['menor de edad','minor'],['menores de edad','minors'],['consentimiento del tutor','guardian consent'],['tutor legal','legal guardian'],
  ['documento acreditativo','supporting document'],['documentos acreditativos','supporting documents'],['documento oficial','official document'],
  ['número oficial','official number'],['registro oficial','official registration'],['referencias de verificación','verification references'],
  ['foto pública','public photo'],['foto personal','personal photo'],['imagen pública','public image'],['imagen personal','personal image'],
  ['portada del vídeo','video cover'],['portada automática','automatic cover'],['portada oficial','official cover'],
  ['fotografía o un vídeo','photo or video'],['foto o vídeo','photo or video'],['imagen o vídeo','image or video'],
  ['archivo seleccionado','selected file'],['archivo está vacío','file is empty'],['archivo supera','file exceeds'],['archivo original','original file'],
  ['subir el archivo','upload the file'],['subida reanudable','resumable upload'],['durante la subida','during upload'],
  ['conexión a Internet','Internet connection'],['la conexión','the connection'],['sin conexión','offline'],
  ['mensajería de Showcase','Showcase messaging'],['KOMBAX Social','KOMBAX Social'],['KOMBAX Showcase','KOMBAX Showcase'],['KOMBAX Events','KOMBAX Events'],
  ['KOMBAX Eventos','KOMBAX Events'],['KOMBAX Assist','KOMBAX Assist'],['KOMBAX Migrations','KOMBAX Migrations'],
  ['crear cuenta','create account'],['Crear cuenta','Create account'],['abrir cuenta','open account'],['iniciar sesión','sign in'],
  ['cambiar código','change code'],['copiar código','copy code'],['copiar invitación','copy invitation'],['crear invitación','create invitation'],
  ['enviar invitación','send invitation'],['aceptar invitación','accept invitation'],['invitación nominativa','named invitation'],
  ['de un solo uso','single-use'],['vinculada a','linked to'],['vinculado a','linked to'],['relacionado con','related to'],['relacionada con','related to'],
  ['preparación deportiva','sports preparation'],['preparación de seguridad','security preparation'],['preparación necesita','preparation requires'],
  ['registro de peso','weight record'],['registros de peso','weight records'],['fecha del pesaje','weigh-in date'],
  ['trayectoria deportiva','sports career'],['actividad deportiva','sports activity'],['recuperación deportiva','sports recovery'],
  ['entrenamiento','training'],['preparación física','physical preparation'],['alta intensidad','high intensity'],
  ['deporte de contacto','combat sport'],['deportes de contacto','combat sports'],['sector deportivo','sports sector'],
  ['red de contactos','network'],['mi red','my network'],['añadir a mi red','add to my network'],
  ['publicar en Showcase','publish in Showcase'],['publicar contenido','publish content'],['publicación propia','own posts'],
  ['publicación pública','public post'],['publicaciones públicas','public posts'],['gestionar publicaciones','manage posts'],
  ['likes, comentarios y compartir','likes, comments and sharing'],['comentarios y compartir','comments and sharing'],
  ['producto real','real product'],['productos reales','real products'],['producto ficticio','fictional product'],['contenido ficticio','fictional content'],
  ['servicio profesional','professional service'],['servicios profesionales','professional services'],['marca oficial','official brand'],
  ['sin posibilidad de compra','without purchase capability'],['sin contratación ni pago','without booking or payment'],
  ['sin comisión KOMBAX','with no KOMBAX commission'],['sin comisión','commission-free'],['sin límites','unlimited'],
  ['haz crecer','grow'],['nuevas oportunidades','new opportunities'],['dentro del ecosistema','within the ecosystem'],
  ['un único espacio','a single space'],['creado específicamente','built specifically'],['da visibilidad','give visibility'],
  ['descubre KOMBAX','discover KOMBAX'],['conecta con','connect with'],['interactúa con','interact with'],
  ['gestiona tu','manage your'],['gestiona','manage'],['promociona','promote'],['vende','sell'],['organiza','organize'],
  ['planifica','plan'],['prioriza','prioritize'],['resume','summarize'],['explica','explain'],['ayuda a','help'],['guía','guide'],
  ['propón','propose'],['ordena','organize'],['señala','highlight'],['identifica','identify'],['conserva','keep'],
  ['mantiene','keeps'],['mantener','keep'],['permanece','remains'],['queda','remains'],['quedó','remained'],
  ['requiere','requires'],['requieren','require'],['necesita','requires'],['necesitan','require'],
  ['admite','accepts'],['admiten','accept'],['permite','allows'],['permiten','allow'],
  ['disponible para','available for'],['disponibles para','available for'],['disponible','available'],['disponibles','available'],
  ['válido para','valid for'],['válida para','valid for'],['no válido','invalid'],['no válida','invalid'],['válido','valid'],['válida','valid'],
  ['correctamente','successfully'],['de nuevo','again'],['otra vez','again'],['primero','first'],['ahora','now'],['aquí','here'],
  ['de esta organización','for this organization'],['de este club','for this club'],['de esta federación','for this federation'],
  ['del contexto autorizado','in the authorized context'],['del contexto','in the context'],['del club','of the club'],['del evento','of the event'],
  ['del perfil','of the profile'],['del equipo','of the team'],['del usuario','of the user'],['del vendedor','of the seller'],
  ['para esta organización','for this organization'],['para este club','for this club'],['para este perfil','for this profile'],
  ['con información disponible','with available information'],['información disponible','available information'],
  ['información legal','legal information'],['información pública','public information'],['información privada','private information'],
  ['campo visual','field of view'],['ajuste anatómico','anatomical fit'],['material de protección','protective equipment'],
  ['textil técnico','technical apparel'],['conjunto técnico','technical kit'],['tecnología aplicada','applied technology'],
  ['nutrición deportiva','sports nutrition'],['hidratación','hydration'],['grappling','grappling'],['striking','striking']
];

const WORDS = Object.freeze({
  'a':'to','acceso':'access','acción':'action','acciones':'actions','aceptación':'acceptance','aceptar':'accept','acreditativo':'supporting',
  'abrir':'open','actividad':'activity','activo':'active','activa':'active','activos':'active','activas':'active','activación':'activation','activar':'activate','actual':'current','actualizar':'update','actualizado':'updated','actualizada':'updated',
  'administración':'administration','administrador':'administrator','aforo':'capacity','agregar':'add','ahora':'now','álbum':'album','alta':'registration','altas':'registrations','alumno':'student','alumnos':'students',
  'añadir':'add','anterior':'previous','antes':'before','anulado':'cancelled','anulada':'cancelled','anunciar':'advertise','aplicar':'apply','aprobación':'approval','aprobar':'approve','archivo':'file','archivos':'files','archivar':'archive',
  'área':'area','árbitro':'referee','asistencia':'attendance','asistente':'attendee','asistentes':'attendees','automática':'automatic','automático':'automatic','autorización':'authorization','autorizado':'authorized','autorizada':'authorized','avatar':'avatar',
  'aviso':'notice','avisos':'notifications','ayuda':'help','baja':'deactivation','banner':'banner','bloquear':'block','borrado':'deletion','buscar':'search','búsqueda':'search','cada':'each','caducado':'expired','campaña':'campaign','campañas':'campaigns',
  'cancelar':'cancel','cancelada':'cancelled','cancelado':'cancelled','cambiar':'change','cambio':'change','canal':'channel','cantidad':'amount','cargo':'charge','cargos':'charges','cargar':'load','cargando':'loading','carrito':'cart','cartel':'poster','categoría':'category','categorías':'categories',
  'centro':'center','cerrar':'close','cifras':'figures','clases':'classes','cliente':'customer','clientes':'customers','club':'club','clubes':'clubs','cobrado':'collected','cobro':'payment','cobros':'payments','código':'code','códigos':'codes',
  'colaboración':'collaboration','colaboraciones':'collaborations','comercial':'commercial','comisión':'commission','completar':'complete','completa':'complete','completo':'complete','compartir':'share','competición':'competition','competidor':'competitor','competidores':'competitors',
  'comprobar':'check','comprobación':'check','comprobaciones':'checks','comentario':'comment','comentarios':'comments','combate':'bout','combates':'bouts','completo':'complete','completa':'complete','comunidad':'community','comunicación':'communications','conversación':'conversation','conversaciones':'conversations','conciliación':'reconciliation','condiciones':'terms','configuración':'settings','configurado':'configured','configurada':'configured','confirmación':'confirmation','confirmar':'confirm',
  'conexión':'connection','conservación':'retention','consulta':'query','consultar':'view','contacto':'contact','contenido':'content','continuar':'continue','contraseña':'password','contratación':'booking','control':'control','copia':'copy','copiar':'copy','correo':'email','correos':'emails',
  'crear':'create','creado':'created','creada':'created','crecimiento':'growth','crítica':'critical','crítico':'critical','cuenta':'account','cuentas':'accounts','cuota':'fee','cuotas':'fees','datos':'data','debería':'should','deberían':'should','descargar':'download','descripción':'description',
  'destinatario':'recipient','detalle':'detail','detalles':'details','día':'day','días':'days','dirección':'management','disciplina':'discipline','disciplinas':'disciplines','dispositivo':'device','documentación':'documentation','documento':'document','documentos':'documents','duplicado':'duplicate','editar':'edit',
  'económica':'financial','economía':'finance','eliminar':'delete','eliminación':'deletion','email':'email','enlace':'link','enlaces':'links','enviar':'send','enviada':'sent','enviado':'sent','equipo':'team','error':'error','escribir':'write','espera':'wait','espacio':'space','estado':'status','estados':'statuses',
  'entrada':'ticket','entradas':'tickets','evento':'event','eventos':'events','expediente':'record','externo':'external','federación':'federation','federaciones':'federations','federado':'member','federados':'members','fecha':'date','ficha':'record','fichas':'records','finanzas':'finance','foto':'photo','fotos':'photos','fotografía':'photo','fotografías':'photos',
  'forma':'way','formato':'format','formatos':'formats','formulario':'form','función':'function','general':'general','generar':'generate','generado':'generated','gestión':'management','gestionar':'manage','gestor':'manager','global':'global','grupo':'group','grupos':'groups','guardar':'save','guardado':'saved',
  'historial':'history','histórico':'history','histórica':'historical','identidad':'identity','identidades':'identities','imagen':'image','imágenes':'images','importe':'amount','información':'information','ingresos':'revenue','iniciar':'start','inscripción':'registration','inscripciones':'registrations','interno':'internal',
  'invitación':'invitation','invitaciones':'invitations','juez':'judge','legal':'legal','like':'like','likes':'likes','licencia':'license','licencias':'licenses','límite':'limit','límites':'limits','lista':'list','marca':'brand','marcas':'brands','material':'material','membresía':'membership','membresías':'memberships','mensaje':'message','mensajes':'messages',
  'mensajería':'messaging','menor':'minor','menores':'minors','miembro':'member','miembros':'members','migración':'migration','migraciones':'migrations','móvil':'mobile','motivo':'reason','multimedia':'media','nombre':'name','notificación':'notification','notificaciones':'notifications','nuevo':'new','nueva':'new','nuevos':'new','nuevas':'new',
  'número':'number','oficial':'official','oficiales':'official','opcional':'optional','operación':'operation','operaciones':'operations','organización':'organization','organizador':'organizer','owner':'Owner','pago':'payment','pagos':'payments','país':'country','papelera':'trash','paso':'step','pasos':'steps','pendiente':'pending','pendientes':'pending',
  'perfil':'profile','perfiles':'profiles','permiso':'permission','permisos':'permissions','persona':'person','personas':'people','personal':'personal','peso':'weight','piloto':'pilot','plan':'plan','plataforma':'platform','portada':'cover','preparación':'preparation','privacidad':'privacy','privada':'private','privado':'private','pública':'public','público':'public',
  'producto':'product','productos':'products','publicación':'post','publicaciones':'posts','publicar':'publish','rechazar':'reject','recibo':'receipt','recibido':'received','recuperación':'recovery','red':'network','referencia':'reference','referencias':'references','registro':'record','registros':'records','relación':'relationship','repetir':'repeat','representación':'representation','restante':'remaining','restantes':'remaining','requisitos':'requirements',
  'reseña':'review','reseñas':'reviews','respuesta':'response','respuestas':'responses','restaurar':'restore','revisión':'review','revisar':'review','rol':'role','roles':'roles','saldo':'balance','secretaría':'administration','seguridad':'security','selección':'selection','seleccionar':'select','servicio':'service','servicios':'services','sesión':'session','sesiones':'sessions','siguiente':'next',
  'situación':'situation','socio':'member','socios':'members','solicitar':'request','solicitud':'request','solicitudes':'requests','soporte':'support','stock':'stock','subir':'upload','tarjeta':'card','tarjetas':'cards','técnica':'technical','técnico':'technical','tecnología':'technology','temporal':'temporary','tiempo':'time','ticketing':'ticketing','tienda':'store',
  'tipo':'type','todos':'all','todas':'all','trabajo':'work','trazabilidad':'traceability','ubicación':'location','usuario':'user','usuarios':'users','validación':'validation','validar':'validate','venta':'sale','ventas':'sales','vencido':'overdue','ver':'view','verificación':'verification','verificar':'verify','versión':'version','vídeo':'video','vídeos':'videos','visible':'visible','web':'website',
  'y':'and','o':'or','con':'with','sin':'without','para':'for','por':'by','desde':'from','hasta':'until','sobre':'about','entre':'between','durante':'during','tras':'after','según':'according to','como':'as','cuando':'when','donde':'where','qué':'what','que':'that','quién':'who','cuál':'which','cuáles':'which','este':'this','esta':'this','estos':'these','estas':'these','ese':'that','esa':'that','un':'a','una':'a','unos':'some','unas':'some','el':'the','la':'the','los':'the','las':'the','del':'of the','al':'to the','de':'of','tu':'your','tus':'your','su':'their','sus':'their','mi':'my','mis':'my','nuestro':'our','nuestra':'our','ningún':'any','ninguna':'any','otro':'other','otra':'other','otros':'other','otras':'other','más':'more','menos':'less','mismo':'same','misma':'same','propio':'own','propia':'own',
  'sí':'yes','no':'no','solo':'only','todos':'all','todo':'all','toda':'all','ya':'already','también':'also','muy':'very','posible':'possible','real':'real','ficticio':'fictional','ficticia':'fictional','principal':'main','premium':'premium','básico':'basic','básica':'basic','gratuita':'free','gratuito':'free','profesional':'professional','deportiva':'sports','deportivo':'sports','técnico':'technical','técnica':'technical'
});

const CLEANUPS = [
  [/\bthe your\b/gi,'your'],[/\bthe my\b/gi,'my'],[/\bof the KOMBAX\b/g,'of KOMBAX'],[/\bto the KOMBAX\b/g,'to KOMBAX'],
  [/\bfor the this\b/gi,'for this'],[/\bof the this\b/gi,'of this'],[/\bwith the this\b/gi,'with this'],
  [/\bthe this\b/gi,'this'],[/\bthe these\b/gi,'these'],[/\ba information\b/gi,'information'],[/\ba access\b/gi,'access'],
  [/\ba support\b/gi,'support'],[/\ba data\b/gi,'data'],[/\ba documentation\b/gi,'documentation'],
  [/\bmust to\b/gi,'must'],[/\bcan to\b/gi,'can'],[/\bcannot to\b/gi,'cannot'],[/\bto to\b/gi,'to'],
  [/\bSign in of again\b/gi,'Sign in again'],[/\bTry again again\b/gi,'Try again'],
  [/\s+([,.;:!?])/g,'$1'],[/([¿¡])/g,''],[/\s{2,}/g,' ']
];

function escapeRe(s){return s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');}
function preserveCase(source,target){
  if(!source)return target;
  if(source.toUpperCase()===source&&source.length>1)return target.toUpperCase();
  if(source[0]===source[0].toUpperCase())return target[0]?.toUpperCase()+target.slice(1);
  return target;
}
const phraseRules=[...PHRASES].sort((a,b)=>b[0].length-a[0].length).map(([es,en])=>[new RegExp(`\\b${escapeRe(es)}\\b`,'giu'),en]);


function buildTemplateRule(template){
  const parts=String(template).split('{VAR}');
  if(parts.length<2)return null;
  const re='^'+parts.map(escapeRe).join('(.+?)')+'$';
  let target=LEGACY_EN_RB02_EXACT[template]||String(template);
  if(LEGACY_EN_RB02_EXACT[template])return {re:new RegExp(re,'u'),target};
  // Translate the literal skeleton while preserving placeholders.
  for(const [rule,en] of phraseRules)target=target.replace(rule,m=>preserveCase(m,en));
  target=target.replace(/[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+/gu,word=>{
    const translated=WORDS[word.toLocaleLowerCase('es')];
    return translated?preserveCase(word,translated):word;
  });
  for(const [rule,repl] of CLEANUPS)target=target.replace(rule,repl);
  return {re:new RegExp(re,'u'),target};
}
const templateRules=[...LEGACY_AUTO_EN_SOURCES].filter(x=>String(x).includes('{VAR}')).map(buildTemplateRule).filter(Boolean);
function translateTemplateValue(source){
  for(const {re,target} of templateRules){
    const m=String(source).match(re);if(!m)continue;
    let i=1;return target.replace(/\{VAR\}/g,()=>m[i++]??'');
  }
  return null;
}

export function autoTranslateLegacyEnglish(value){
  const source=String(value??'');
  if(!source)return source;
  const trimmed=source.trim();
  if(LEGACY_EN_RB02_EXACT[trimmed])return `${source.match(/^\s*/)?.[0]||''}${LEGACY_EN_RB02_EXACT[trimmed]}${source.match(/\s*$/)?.[0]||''}`;
  const templated=!LEGACY_AUTO_EN_SOURCES.has(trimmed)?translateTemplateValue(trimmed):null;
  if(!LEGACY_AUTO_EN_SOURCES.has(trimmed)&&templated===null)return source;
  const lead=source.match(/^\s*/)?.[0]||'',tail=source.match(/\s*$/)?.[0]||'';
  if(templated!==null)return `${lead}${templated}${tail}`;
  let text=trimmed;
  for(const [re,en] of phraseRules)text=text.replace(re,m=>preserveCase(m,en));
  text=text.replace(/[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+/gu,word=>{
    const translated=WORDS[word.toLocaleLowerCase('es')];
    return translated?preserveCase(word,translated):word;
  });
  for(const [re,repl] of CLEANUPS)text=text.replace(re,repl);
  return `${lead}${text.trim()}${tail}`;
}

export function isLegacyAutoEnglishSource(value){return LEGACY_AUTO_EN_SOURCES.has(String(value??'').trim());}
