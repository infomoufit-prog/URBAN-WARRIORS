// Narrow portal financial reads to the participants legally linked to the signed-in user.
// Authorization is still independently enforced by Supabase RLS and mutation RPCs.
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function financeMemberFilter(memberIds=null){
  if(memberIds===null||memberIds===undefined)return '';
  if(!Array.isArray(memberIds))throw new Error('Selección de alumnos inválida.');
  if(memberIds.length>200)throw new Error('Demasiados alumnos seleccionados.');
  const ids=[...new Set(memberIds.map(x=>String(x||'')).filter(id=>UUID.test(id)))];
  if(ids.length!==memberIds.length&&memberIds.some(id=>!UUID.test(String(id||''))))throw new Error('Identificador de alumno inválido.');
  if(ids.length>200)throw new Error('Demasiados alumnos seleccionados.');
  return ids.length?`&socio_id=in.(${ids.join(',')})`:'&socio_id=eq.00000000-0000-0000-0000-000000000000';
}
