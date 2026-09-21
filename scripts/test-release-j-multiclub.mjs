import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RELEASE J: ${msg}`);console.log(`OK RELEASE J: ${msg}`)};
const [sql,rollback,repos,matrix]=await Promise.all([
  read('supabase/migrations/030_multiclub_rls_performance.sql'),read('supabase/rollbacks/030_multiclub_rls_performance.sql'),
  read('web/js/core/repositories.js'),read('RLS_MATRIX.md')
]);

for(const index of ['idx_socios_club_nombre','idx_sesiones_club_fecha','idx_comunicaciones_club_feed','idx_material_catalogo_club_activo','idx_dispositivos_push_club_activos','idx_notificaciones_dispatch_pendiente'])assert(sql.includes(index),`índice multiclub ${index}`);
assert(sql.includes('dispositivos_propios_v030')&&sql.includes('public.es_miembro_club(club_id)'),'token push exige usuario y pertenencia al club');
assert(sql.includes('preferencias_notificacion_propias_v030')&&sql.includes('notificaciones_lecturas_insertar_v030'),'preferencias y lecturas quedan ligadas a tenant visible');
assert(sql.includes('app_privilege_snapshot_v030')&&sql.includes('revoke insert,update,delete'),'DML crítico pasa exclusivamente por gateway');
assert(rollback.includes("where had_privilege")&&rollback.includes("grant %s"),'rollback restaura privilegios efectivos previos');
assert(sql.includes('app_multiclub_audit_v030')&&sql.includes('direct_client_dml'),'migración entrega diagnóstico auditable');
for(const resource of ['publicaciones_comunidad','comunicaciones','cuotas','material_catalogo','dispositivos_push','preferencias_notificacion'])assert(sql.includes(`'${resource}'`),`${resource} forma parte del control tenant`);
assert(repos.includes('const filterClub=')&&repos.includes('${filterClub()}'),'repositorios filtran el club en backend');
for(const action of ['SELECT','INSERT','UPDATE','DELETE'])assert(matrix.includes(action),`matriz documenta ${action}`);
console.log('RELEASE J MULTICLUB: PASS');
