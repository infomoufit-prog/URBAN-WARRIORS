import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const mdir=resolve(root,'supabase/migrations');
const names=(await readdir(mdir)).filter(n=>/^0(0[1-9]|1[0-4])_.*\.sql$/.test(n)).sort();
const prior=(await Promise.all(names.map(n=>readFile(resolve(mdir,n),'utf8')))).join('\n');
const current=await readFile(resolve(mdir,'015_mutation_governance_v160.sql'),'utf8');
function typeList(args){
  const types=[];
  const re=/\bp_\w+\s+([A-Za-z_][\w.]*(?:\[\])?)/g;
  for(const m of args.matchAll(re)) types.push(m[1].toLowerCase());
  return types.join(',');
}

const defs=new Set();
const defRe=/create\s+or\s+replace\s+function\s+public\.(\w+)\s*\((.*?)\)\s*returns/gis;
for(const m of prior.matchAll(defRe)) defs.add(`${m[1].toLowerCase()}(${typeList(m[2])})`);
const revRe=/revoke\s+all\s+on\s+function\s+public\.(\w+)\s*\(([^)]*)\)\s+from\s+public\s*,\s*anon\s*,\s*authenticated/gi;
const legacy=[];
for(const m of current.matchAll(revRe)) {
  const sig=`${m[1].toLowerCase()}(${m[2].replace(/\s+/g,'').toLowerCase()})`;
  if(['app_mutate_v160','app_runtime_contract_v160','app_write_channel_probe_v160'].includes(m[1])) continue;
  legacy.push(sig);
}
const missing=legacy.filter(sig=>!defs.has(sig));
if(missing.length) throw new Error(`015 revoca firmas que no existen en 001–014: ${missing.join('; ')}`);
const requiredTables=['clubes','perfiles','miembros_club','config_club','disciplinas','grados','grupos','horarios_grupo','socios','tutores_socios','socio_disciplinas','graduaciones','preinscripciones','tarifas','cuotas','pagos','sesiones_entrenamiento','asistencias','registros_acceso_clase','comunicaciones','seguimiento','consentimientos','material_catalogo','material_variantes','material_pedidos','notificaciones','notificaciones_lecturas','configuracion_avisos_cuota','historial_avisos_cuota','documentos_socios','invitaciones_club','dispositivos_push'];
const missingTables=requiredTables.filter(t=>!new RegExp(`create\\s+table\\s+(?:if\\s+not\\s+exists\\s+)?public\\.${t}\\b`,'i').test(prior));
if(missingTables.length) throw new Error(`Tablas gobernadas no creadas por migraciones previas: ${missingTables.join(', ')}`);
const gatewayCalls=[...current.matchAll(/public\.(\w+)\s*\(/g)].map(m=>m[1]).filter(n=>!['app_mutate_v160','app_runtime_contract_v160','app_write_channel_probe_v160','es_miembro_club','tiene_rol_club'].includes(n));
const definedNames=new Set([...prior.matchAll(defRe)].map(m=>m[1]));
const tableNames=new Set(requiredTables.concat(['app_mutation_requests','app_runtime_meta']));
const missingFunctions=[...new Set(gatewayCalls.filter(n=>!definedNames.has(n) && !tableNames.has(n)))];
if(missingFunctions.length) throw new Error(`Gateway referencia funciones no definidas antes de 015: ${missingFunctions.join(', ')}`);
console.log(`OK: compatibilidad SQL 015 con ${names.length} migraciones previas, ${legacy.length} firmas legacy y ${requiredTables.length} tablas.`);
