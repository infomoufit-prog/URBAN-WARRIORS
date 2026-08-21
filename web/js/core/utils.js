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
export const money = (value) => new Intl.NumberFormat('es-ES',{style:'currency',currency:'EUR'}).format(Number(value||0));
export const dateFmt = (value) => value ? new Intl.DateTimeFormat('es-ES').format(new Date(`${String(value).slice(0,10)}T12:00:00`)) : '—';
export const dtFmt = (value) => value ? new Intl.DateTimeFormat('es-ES',{dateStyle:'short',timeStyle:'short'}).format(new Date(value)) : '—';
export const fullName = (name='',surnames='') => [name,surnames].map(value=>String(value||'').trim()).filter(Boolean).join(' ').replace(/\s+/g,' ');
export const byName = (a,b) => String(a?.nombre||a?.titulo||'').localeCompare(String(b?.nombre||b?.titulo||''),'es');
export const opt = (rows, selected, label=(r)=>r.nombre) => rows.map(r=>`<option value="${esc(r.id)}" ${String(r.id)===String(selected||'')?'selected':''}>${esc(label(r))}</option>`).join('');
export const sleep = (ms) => new Promise(r=>setTimeout(r,ms));

export function technicalError(error) {
  return [error?.message,error?.details,error?.hint].filter(Boolean).join(' · ') || String(error||'');
}

const TECHNICAL_ERROR_PATTERN=/(?:\brls\b|row[- ]level security|\brpc\b|\bpgrst\w*\b|sqlstate|postgres|supabase|schema cache|\bschema\b|\bconstraint\b|foreign key|duplicate key|violates|permission denied|\bpolicy\b|\brelation\b|\bcolumn\b|\buuid\b|\bjsonb?\b|\bapp_kombax_[a-z0-9_]+|\bapp_[a-z0-9_]+_v\d+|\bKOMBAX_[A-Z0-9_]+|\bpublic\.|\bauth\.|storage\/v1|rest\/v1|functions\/v1|\bHTTP\s*\d{3}\b|\b42P\w+\b|\b23\d{3}\b)/i;
const SAFE_SPANISH_PREFIX=/^(?:No se |No tienes |No puedes |Debes |Indica |Introduce |Selecciona |El código |La contraseña |Tu sesión |Has alcanzado |Esta |Este |Primero |Revisa |Comprueba |La nueva |La foto |El archivo |Formato |Club |Cuenta |Solicitud |Perfil |Mensaje |Comentario |Publicación |Acceso |Inicia sesión)/i;

export function humanError(error) {
  if(error?.code==='AUTH_EXPIRED')return 'Tu sesión ha caducado. Vuelve a iniciar sesión.';
  const raw=technicalError(error).trim();
  if(/invalid\s*refresh\s*token|refresh\s*token\s*(?:not\s*found|invalid|expired)|refresh_token_not_found|jwt.*expired|token.*expired/i.test(raw))return 'Tu sesión ha caducado. Vuelve a iniciar sesión.';
  if(/failed to fetch|networkerror|network request failed|load failed|internet|timeout|tiempo de espera|aborterror/i.test(raw))return 'No se pudo conectar. Comprueba tu conexión a Internet e inténtalo de nuevo.';
  if(/rate.?limit|too many|frequent|429/i.test(raw))return 'Has realizado demasiados intentos. Espera un momento y vuelve a intentarlo.';
  if(/invalid login credentials|invalid credentials|email or password|wrong password|bad password/i.test(raw))return 'El correo o la contraseña no son correctos.';
  if(/otp|one.?time|token|code.*expired|expired.*code|invalid.*code/i.test(raw)&&!/codigo|código/i.test(raw))return 'El código no es válido o ha caducado. Solicita uno nuevo e inténtalo otra vez.';
  if(/not authorized|unauthorized|forbidden|permission denied|platform_admin_required/i.test(raw))return 'No tienes permiso para realizar esta acción.';
  if(/not found|does not exist|no rows|404/i.test(raw)&&!SAFE_SPANISH_PREFIX.test(raw))return 'El contenido solicitado ya no está disponible.';
  if(TECHNICAL_ERROR_PATTERN.test(raw))return 'No se ha podido completar la operación. Inténtalo de nuevo.';
  if(raw&&raw.length<=240&&SAFE_SPANISH_PREFIX.test(raw))return raw.replace(/^Error:\s*/,'');
  return 'No se ha podido completar la operación. Inténtalo de nuevo.';
}

export function todayTime(offsetMinutes=0) {
  const d = new Date(Date.now()+offsetMinutes*60000);
  return d.toTimeString().slice(0,5);
}
