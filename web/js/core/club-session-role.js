export function clubSessionRole(memberships,candidate){
 const active=(memberships||[]).filter(m=>m.activo!==false);
 const owner=active.find(m=>m.rol==='direccion');
 const coordination=!owner&&active.some(m=>m.coordinacion===true);
 const chosen=owner||(coordination?active.find(m=>m.rol==='secretaria'):null)||candidate;
 return {chosen,coordinacion:coordination,rol:owner?'direccion':coordination?'coordinacion':chosen?.rol,roles:coordination?['coordinacion']:[...new Set(active.map(m=>m.rol))]};
}
