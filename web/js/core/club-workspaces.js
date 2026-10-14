// A role selects a view, never grants a capability. Supabase remains the authority.
export const CLUB_ROLE_PRIORITY=Object.freeze(['direccion','coordinacion','secretaria','economia','comunicacion','monitor','familia','alumno']);
export const CLUB_SPACE_LABELS=Object.freeze({direccion:'Dirección',coordinacion:'Coordinación',secretaria:'Secretaría',economia:'Tesorería',comunicacion:'Comunicación',monitor:'Monitor',familia:'Padre, madre o tutor',alumno:'Participante'});
export const clubSpacePreferenceKey=(userId,clubId)=>`kx-club-space-v1:${userId}:${clubId}`;
export function availableClubSpaces(memberships=[],clubId,facets=[]){
  const selected=(memberships||[]).filter(m=>m&&m.activo!==false&&String(m.club_id)===String(clubId));
  const set=new Set(selected.map(m=>String(m.rol||'')));
  if(!set.has('direccion')&&selected.some(m=>m.coordinacion===true))set.add('coordinacion');
  // Verified self/guardian associations may grant a personal view, but NEVER an administrative role.
  for(const facet of facets||[])if(facet==='alumno'||facet==='familia')set.add(facet);
  return CLUB_ROLE_PRIORITY.filter(role=>set.has(role));
}
export function resolveClubSpaceRole(session,preferred=''){
  const available=availableClubSpaces(session?.memberships||[],session?.club_id,session?.club_space_facets||[]);
  return available.includes(preferred)?preferred:(available.includes(session?.rol)?session.rol:available[0]||session?.rol||'');
}
export function chooseClubSpace(session,requested){
  if(!session?.club_id||!session.id||session.support_mode||session.scope==='owner-support')throw new Error('No hay un espacio de club disponible.');
  const available=availableClubSpaces(session.memberships||[],session.club_id,session.club_space_facets||[]);
  if(!available.includes(requested))throw new Error('Este rol no está autorizado en el club seleccionado.');
  return {...session,rol:requested,active_club_role:requested};
}
export function readClubSpacePreference(userId,clubId,storage=undefined){
  try{return String((storage??globalThis.localStorage)?.getItem(clubSpacePreferenceKey(userId,clubId))||'');}catch{return '';}
}
export function writeClubSpacePreference(userId,clubId,role,storage=undefined){
  try{(storage??globalThis.localStorage)?.setItem(clubSpacePreferenceKey(userId,clubId),role);}catch{}
}
