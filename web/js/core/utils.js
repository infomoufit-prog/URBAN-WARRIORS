import { formatCurrency, formatDate, formatDateTime, getLocale } from '../i18n/index.js';
import { localizeSystemText } from '../i18n/legacy-runtime.js';
export const esc = (value) => String(value ?? '')
  .replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;')
  .replaceAll('"','&quot;').replaceAll("'",'&#039;');

export const uuid = () => {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
  const b = new Uint8Array(16); globalThis.crypto?.getRandomValues?.(b);
  b[6]=(b[6]&15)|64; b[8]=(b[8]&63)|128;
  const h=[...b].map(x=>x.toString(16).padStart(2,'0')).join('');
  return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20)}`;
};

export const isoDate = (date=new Date()) => date.toISOString().slice(0,10);
export const monthStart = (date=new Date()) => `${date.toISOString().slice(0,7)}-01`;

export const localIsoDate = (date=new Date()) => {
  const d = new Date(date);
  const y=d.getFullYear(),m=String(d.getMonth()+1).padStart(2,'0'),day=String(d.getDate()).padStart(2,'0');
  return `${y}-${m}-${day}`;
};
export function weekRange(offset=0, base=new Date()) {
  const d=new Date(base);d.setHours(12,0,0,0);
  const mondayIndex=(d.getDay()+6)%7;
  d.setDate(d.getDate()-mondayIndex+(Number(offset)||0)*7);
  const start=localIsoDate(d);const endDate=new Date(d);endDate.setDate(d.getDate()+6);
  return {start,end:localIsoDate(endDate)};
}
export function sortSessionsForWeek(rows, offset=0, now=new Date()) {
  const nowKey=`${localIsoDate(now)} ${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;
  return [...(rows||[])].sort((a,b)=>{
    const ak=`${String(a?.fecha||'')} ${String(a?.hora_inicio||'').slice(0,5)}`;
    const bk=`${String(b?.fecha||'')} ${String(b?.hora_inicio||'').slice(0,5)}`;
    if(Number(offset)===0){const af=ak>=nowKey,bf=bk>=nowKey;if(af!==bf)return af?-1:1;return af?ak.localeCompare(bk):bk.localeCompare(ak);}
    return ak.localeCompare(bk);
  });
}
export const money = (value,currency='EUR') => formatCurrency(Number(value||0),{currency});
export const dateFmt = (value) => formatDate(value);
export const dtFmt = (value) => formatDateTime(value);
export const fullName = (name='',surnames='') => [name,surnames].map(value=>String(value||'').trim()).filter(Boolean).join(' ').replace(/\s+/g,' ');
export const byName = (a,b) => String(a?.nombre||a?.titulo||'').localeCompare(String(b?.nombre||b?.titulo||''),getLocale());
export const opt = (rows, selected, label=(r)=>r.nombre) => rows.map(r=>`<option value="${esc(r.id)}" ${String(r.id)===String(selected||'')?'selected':''}>${esc(label(r))}</option>`).join('');
export const sleep = (ms) => new Promise(r=>setTimeout(r,ms));

export function technicalError(error) {
  return [error?.message,error?.details,error?.hint].filter(Boolean).join(' · ') || String(error||'');
}

const TECHNICAL_ERROR_PATTERN=/(?:\brls\b|row[- ]level security|\brpc\b|\bpgrst\w*\b|sqlstate|postgres|supabase|schema cache|\bschema\b|\bconstraint\b|foreign key|duplicate key|violates|permission denied|\bpolicy\b|\brelation\b|\bcolumn\b|\buuid\b|\bjsonb?\b|\bapp_kombax_[a-z0-9_]+|\bapp_[a-z0-9_]+_v\d+|\bKOMBAX_[A-Z0-9_]+|\bpublic\.|\bauth\.|storage\/v1|rest\/v1|functions\/v1|\bHTTP\s*\d{3}\b|\b42P\w+\b|\b23\d{3}\b)/i;
const SAFE_SPANISH_PREFIX=/^(?:No se |No tienes |No puedes |Debes |Indica |Introduce |Selecciona |El código |La contraseña |Tu sesión |Has alcanzado |Esta |Este |Primero |Revisa |Comprueba |La nueva |La foto |El archivo |Formato |Club |Cuenta |Solicitud |Perfil |Mensaje |Comentario |Publicación |Acceso |Inicia sesión)/i;
const APPLICATION_FIELD_LABELS={
  ubicacion:'ubicación',disciplinas:'disciplinas',nombre_legal:'nombre legal',email:'correo electrónico',email_oficial:'correo oficial',email_corporativo:'correo corporativo',
  registro_entidad:'registro o número oficial',responsable:'persona responsable',rol_responsable:'cargo de la persona responsable',evidencia:'referencias de verificación',
  pais:'país',territorio:'territorio',web_publica_https:'web pública con HTTPS'
};

function applicationFieldsMessage(raw){
  const match=raw.match(/KOMBAX_(?:APPLICATION|CLUB)_FIELDS_REQUIRED:([^\s·]+)/i);if(!match)return '';
  const labels=match[1].split(',').map(key=>APPLICATION_FIELD_LABELS[key]||key.replaceAll('_',' '));
  return `Revisa los campos obligatorios antes de enviar: ${labels.join(', ')}.`;
}

function humanErrorSpanish(error) {
  if(error?.code==='AUTH_EXPIRED')return 'Tu sesión ha caducado. Vuelve a iniciar sesión.';
  const raw=technicalError(error).trim();
  if(/KOMBAX_BASE_VERIFICATION_REQUIRED/i.test(raw))return 'Primero debe verificarse la identidad del club en KOMBAX. Puedes preparar el catálogo, pero todavía no activar la venta directa.';
  if(/KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED/i.test(raw))return 'Indica tu fecha de nacimiento para crear la cuenta KOMBAX.';
  if(/KOMBAX_ACCOUNT_BIRTH_DATE_INVALID/i.test(raw))return 'La fecha de nacimiento no es válida. Revísala e inténtalo de nuevo.';
  if(/KOMBAX_MINOR_MUST_USE_TUTOR_FLOW/i.test(raw))return 'Si eres menor de 16 años, utiliza el alta mediante padre, madre o tutor.';
  if(/KOMBAX_TUTOR_MIN_AGE_18/i.test(raw))return 'La cuenta de padre, madre o tutor debe pertenecer a una persona de 18 años o más.';
  if(/KOMBAX_MEMBER_INDEPENDENT_MIN_AGE_16/i.test(raw))return 'El Perfil Social independiente de Miembro/Practicante está disponible a partir de los 16 años. Para menores, utiliza la vinculación familiar o del club.';
  if(/KOMBAX_POSSIBLE_IMPORTED_MEMBER_REVIEW_REQUIRED|KOMBAX_EXISTING_MEMBER_EMAIL_USE_EXISTING_RECORD/i.test(raw))return 'Hemos encontrado una ficha del Club que podría corresponder a esta persona. Revisa la ficha existente y vincúlala en lugar de crear un duplicado.';
  if(/KOMBAX_DUPLICATE_PENDING_PRE_ENROLLMENT_EMAIL|KOMBAX_DUPLICATE_PENDING_PRE_ENROLLMENT/i.test(raw))return 'Ya existe una solicitud de vinculación pendiente para esta persona. Revisa la solicitud existente antes de crear otra.';
  if(/user already registered|already been registered|email.*already.*registered|email.*already.*exists/i.test(raw))return 'Ya existe una cuenta KOMBAX con este correo. Inicia sesión o recupera tu contraseña.';
  if(/database error saving new user/i.test(raw))return 'No se pudo crear la cuenta. Revisa la fecha de nacimiento y los datos obligatorios e inténtalo de nuevo.';
  if(/SELLER_APPLICATION_DATA_INCOMPLETE/i.test(raw))return 'Revisa los datos de vendedor: domicilio, teléfono, identificación fiscal y correo de atención deben estar completos.';
  if(/SELLER_DECLARATIONS_REQUIRED/i.test(raw))return 'Acepta las dos declaraciones de vendedor antes de enviar la solicitud.';
  if(/SELLER_SHIPPING_MODE_REQUIRED/i.test(raw))return 'Selecciona al menos una forma de entrega para tus productos.';
  if(/invalid\s*refresh\s*token|refresh\s*token\s*(?:not\s*found|invalid|expired)|refresh_token_not_found|jwt.*expired|token.*expired/i.test(raw))return 'Tu sesión ha caducado. Vuelve a iniciar sesión.';
  if(/failed to fetch|networkerror|network request failed|load failed|internet|timeout|tiempo de espera|aborterror/i.test(raw))return 'No se pudo conectar. Comprueba tu conexión a Internet e inténtalo de nuevo.';
  if(/rate.?limit|too many|frequent|429/i.test(raw))return 'Has realizado demasiados intentos. Espera un momento y vuelve a intentarlo.';
  if(/invalid login credentials|invalid credentials|email or password|wrong password|bad password/i.test(raw))return 'El correo o la contraseña no son correctos.';
  if(/otp|one.?time|token|code.*expired|expired.*code|invalid.*code/i.test(raw)&&!/codigo|código/i.test(raw))return 'El código no es válido o ha caducado. Solicita uno nuevo e inténtalo otra vez.';
  if(/FINANCE_PAYMENT_ALREADY_COVERED/i.test(raw))return 'Esta cuota ya está completamente pagada. Revisa o rechaza el pago pendiente duplicado; no puede validarse otro cobro.';
  if(/FINANCE_PAYMENT_EXCEEDS_REMAINING/i.test(raw))return 'El importe supera el saldo pendiente de esta cuota. Revisa el importe antes de continuar.';
  if(/FINANCE_PAYMENT_DUPLICATE/i.test(raw))return 'Ya existe un pago prácticamente idéntico registrado hace unos instantes. Revisa la lista antes de repetirlo.';
  if(/FINANCE_PAYMENT_ALREADY_REVIEWED/i.test(raw))return 'Este pago ya fue revisado y no puede volver a validarse.';
  if(/FINANCE_DOCUMENT_REASON_REQUIRED/i.test(raw))return 'Indica el motivo antes de archivar o enviar documentación financiera a la papelera.';
  if(/FINANCE_PAYMENT_AMOUNT_INVALID/i.test(raw))return 'El importe del pago debe ser mayor que cero.';
  if(/FINANCE_CHARGE_DUPLICATE/i.test(raw))return 'Ya existe un cargo prácticamente idéntico creado hace unos instantes. Revisa la lista antes de repetirlo.';
  if(/FINANCE_PAYMENT_CHARGE_CLOSED/i.test(raw))return 'Esta cuota está anulada o exenta y no admite nuevos pagos ni validaciones.';
  if(/KOMBAX_VERIFICATION_DOCUMENT_REQUIRED/i.test(raw))return 'Adjunta un documento acreditativo antes de enviar la solicitud.';
  if(/KOMBAX_SOCIAL_COMPETITOR_VERIFIED_AGE_REQUIRED/i.test(raw))return 'Verifica tu condición de competidor y la edad requerida para activar Social como Competidor.';
  if(/KOMBAX_SOCIAL_PROFESSIONAL_AGE_REQUIRED/i.test(raw))return 'Tu perfil Profesional debe estar verificado y acreditar 18 años o más para activar Social.';
  if(/KOMBAX_DIRECT_PROFILE_VERIFIED_REQUIRED/i.test(raw))return 'Verifica esta identidad antes de activar su publicación en Social.';
  const applicationFields=applicationFieldsMessage(raw);if(applicationFields)return applicationFields;
  if(/KOMBAX_DECLARATION_REQUIRED/i.test(raw))return 'Debes confirmar la declaración de identidad y representación.';
  if(/KOMBAX_APPLICATION_LOCKED_FOR_REVIEW/i.test(raw))return 'La solicitud ya está en revisión y no se puede modificar.';
  if(/KOMBAX_APPLICATION_NOT_SUBMITTABLE/i.test(raw))return 'La solicitud no está en un estado que permita volver a enviarla.';
  if(/KOMBAX_WEIGHT_OUT_OF_RANGE/i.test(raw))return 'Introduce un peso válido entre 15 y 300 kg.';
  if(/KOMBAX_PREPARATION_SUBJECT_REQUIRED/i.test(raw))return 'Selecciona el competidor o miembro al que pertenece esta preparación.';
  if(/KOMBAX_COMPETITOR_PROFILE_REQUIRED/i.test(raw))return 'Esta preparación necesita un perfil Competidor válido.';
  if(/KOMBAX_COMPETITOR_PROFILE_EDIT_REQUIRED|KOMBAX_PREPARATION_SUBJECT_EDIT_REQUIRED/i.test(raw))return 'No tienes permiso para crear o modificar la preparación de este deportista.';
  if(/KOMBAX_PREPARATION_READ_REQUIRED/i.test(raw))return 'No tienes permiso para consultar esta preparación.';
  if(/KOMBAX_PREPARATION_LOG_REQUIRED/i.test(raw))return 'No tienes permiso para añadir registros de peso en esta preparación.';
  if(/KOMBAX_PREPARATION_VERIFY_REQUIRED|KOMBAX_OFFICIAL_VERIFICATION_REQUIRED/i.test(raw))return 'No tienes permiso para verificar este pesaje.';
  if(/KOMBAX_PREPARATION_MANAGE_REQUIRED/i.test(raw))return 'No tienes permiso para gestionar esta preparación ni sus accesos.';
  if(/KOMBAX_ACCESS_PROFILE_REQUIRED/i.test(raw))return 'Selecciona una persona válida para conceder acceso.';
  if(/KOMBAX_ACCESS_ROLE_INVALID|KOMBAX_ACCESS_PERMISSIONS_INVALID|KOMBAX_ACCESS_PERMISSION_NOT_ALLOWED/i.test(raw))return 'Revisa el rol y los permisos del equipo de preparación.';
  if(/KOMBAX_MEASUREMENT_DATE_INVALID/i.test(raw))return 'La fecha del pesaje no puede estar en el futuro.';
  if(/KOMBAX_MEASUREMENT_CONTEXT_INVALID/i.test(raw))return 'Selecciona un contexto válido para el registro.';
  if(/KOMBAX_EVIDENCE_PATH_INVALID/i.test(raw))return 'No se pudo vincular correctamente la foto privada del pesaje.';
  if(/not authorized|unauthorized|forbidden|permission denied|platform_admin_required/i.test(raw))return 'No tienes permiso para realizar esta acción.';
  if(/not found|does not exist|no rows|404/i.test(raw)&&!SAFE_SPANISH_PREFIX.test(raw))return 'El contenido solicitado ya no está disponible.';
  if(TECHNICAL_ERROR_PATTERN.test(raw))return 'No se ha podido completar la operación. Inténtalo de nuevo.';
  if(raw&&raw.length<=240&&SAFE_SPANISH_PREFIX.test(raw))return raw.replace(/^Error:\s*/,'');
  return 'No se ha podido completar la operación. Inténtalo de nuevo.';
}

export function humanError(error) {
  return localizeSystemText(humanErrorSpanish(error), getLocale());
}

export function todayTime(offsetMinutes=0) {
  const d = new Date(Date.now()+offsetMinutes*60000);
  return d.toTimeString().slice(0,5);
}
