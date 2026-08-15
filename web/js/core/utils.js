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
export const byName = (a,b) => String(a?.nombre||a?.titulo||'').localeCompare(String(b?.nombre||b?.titulo||''),'es');
export const opt = (rows, selected, label=(r)=>r.nombre) => rows.map(r=>`<option value="${esc(r.id)}" ${String(r.id)===String(selected||'')?'selected':''}>${esc(label(r))}</option>`).join('');
export const sleep = (ms) => new Promise(r=>setTimeout(r,ms));

export function humanError(error) {
  const parts = [error?.message, error?.details, error?.hint].filter(Boolean);
  return parts.join(' · ') || 'Error desconocido';
}

export function todayTime(offsetMinutes=0) {
  const d = new Date(Date.now()+offsetMinutes*60000);
  return d.toTimeString().slice(0,5);
}
