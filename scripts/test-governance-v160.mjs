import { readFile, access } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const read = (p) => readFile(resolve(root, p), 'utf8');
const [store, app, config, sw, index, migration, pkgText, gradle, activity] = await Promise.all([
  read('web/js/data-store.js'), read('web/js/app.js'), read('web/config.js'), read('web/service-worker.js'),
  read('web/index.html'), read('supabase/migrations/015_mutation_governance_v160.sql'), read('package.json'),
  read('android/app/build.gradle'), read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java')
]);
const pkg = JSON.parse(pkgText);
const checks = [];
const check = (name, ok, detail='') => checks.push({ name, ok: Boolean(ok), detail });

check('runtime 1.6.0/build12', config.includes("version: '1.6.0'") && config.includes('build: 12') && config.includes("backendVersion: '1.6.0'") && config.includes('schemaEpoch: 160'));
check('package 1.6.0', pkg.version === '1.6.0' && pkg.name === 'urban-warriors-v1.6.0');
check('Android 1.6.0', gradle.includes('versionCode 12') && gradle.includes("versionName '1.6.0'") && activity.includes('UrbanWarriorsApp/1.6.0'));
check('cache 1.6.0 build12', sw.includes("urban-warriors-v1.6.0-build12"));
check('service worker no intercepta APIs externas', sw.includes('url.origin !== self.location.origin') && sw.includes("if (event.request.method !== 'GET') return"));
for (const asset of ['app.css','config.js','demo-data.js','data-store.js','push.js','app.js','service-worker.js']) {
  check(`cache bust ${asset}`, index.includes(`${asset}?v=1.6.0-b12`), asset);
}
check('sin backup runtime', await access(resolve(root,'web/js/data-store.js.bak')).then(()=>false).catch(()=>true));
check('publishable key no usado como Bearer', !/Authorization\s*:\s*`Bearer \$\{this\.anonKey\}`/.test(store) && !/Authorization\s*:\s*`Bearer \$\{this\.session\?\.access_token \|\| this\.anonKey\}`/.test(store));
check('gateway único declarado', store.includes("const MUTATION_ENDPOINT = 'app_mutate_v160'") && store.includes("const CONTRACT_ENDPOINT = 'app_runtime_contract_v160'"));

const rpcCalls = [...store.matchAll(/supabase\.rpc\(([^,\n]+)/g)].map(m => m[1].trim());
const allowedRpcExpressions = new Set(['CONTRACT_ENDPOINT','MUTATION_ENDPOINT','PROBE_ENDPOINT']);
check('solo 3 RPC de transporte en frontend', rpcCalls.length === 3 && rpcCalls.every(x => allowedRpcExpressions.has(x)), rpcCalls.join(', '));
check('sin DML directo desde store', !/supabase\.(?:insert|upsert|update|updateWhere|remove)\s*\(/.test(store));
check('sin rpc histórica literal en runtime', !/supabase\.rpc\(\s*['"](?:app_guardar|app_crear|app_aprobar|app_rechazar|app_lista|app_solicitar|app_desactivar|comunicar_pago|registrar_cobro|validar_pago|pausar_avisos|reactivar_avisos|generar_cuotas|procesar_avisos|crear_invitacion|aceptar_invitacion|registrar_cuenta)/.test(store));
check('bloqueo de escritura no gobernada', store.includes('Escritura no gobernada bloqueada') && store.includes('Actualización no gobernada bloqueada') && store.includes('Borrado no gobernado bloqueado'));
check('notificaciones producción transaccionales', app.includes('En producción la puerta de mutación notifica dentro de la misma transacción') && app.includes('En producción la RPC de pago genera la notificación transaccionalmente'));

const frontendOps = [...new Set([...store.matchAll(/\.mutate\(\s*['"]([^'"]+)['"]/g)].map(m => m[1]))].sort();
const sqlOps = [...new Set([...migration.matchAll(/when\s+'([^']+)'\s+then/g)].map(m => m[1]))].sort();
const missingSql = frontendOps.filter(op => !sqlOps.includes(op));
check('cada operación frontend existe en gateway SQL', missingSql.length === 0, missingSql.join(', '));
check('gateway cubre >= 37 operaciones', sqlOps.length >= 37, `SQL=${sqlOps.length}; frontend=${frontendOps.length}`);

const directTables = ['clubes','perfiles','miembros_club','config_club','disciplinas','grados','grupos','horarios_grupo','socios','tutores_socios','socio_disciplinas','graduaciones','preinscripciones','tarifas','cuotas','pagos','sesiones_entrenamiento','asistencias','registros_acceso_clase','comunicaciones','seguimiento','material_catalogo','material_variantes','material_pedidos','notificaciones','notificaciones_lecturas','documentos_socios','invitaciones_club','dispositivos_push'];
check('DML directo revocado a clientes', migration.includes('revoke insert, update, delete on table') && directTables.every(t => migration.includes(`public.${t}`)) && migration.includes('from anon, authenticated'));
check('RPC históricas revocadas', migration.includes('revoke all on function public.app_guardar_disciplina') && migration.includes('revoke all on function public.app_guardar_grupo') && migration.includes('revoke all on function public.app_guardar_socio') && migration.includes('revoke all on function public.app_guardar_comunicacion'));
check('contrato antes de mutar', store.includes('if (!opts.skipContract) await this.ensureBackendContract(false)'));
check('idempotencia request_id', migration.includes('create table if not exists public.app_mutation_requests') && migration.includes('request_id uuid primary key') && store.includes('p_request_id: requestId'));
check('membresía obligatoria gateway', migration.includes("p_operation not in ('cuenta.registrar','invitacion.aceptar')") && migration.includes('MUTATION_MEMBERSHIP_REQUIRED'));
check('respuesta versionada confirmada', store.includes("response?.backend_version !== RUNTIME_VERSION") && store.includes('response?.request_id !== requestId'));

const failed = checks.filter(c => !c.ok);
for (const c of checks) console.log(`${c.ok ? 'OK' : 'FAIL'} ${c.name}${c.detail ? ` — ${c.detail}` : ''}`);
if (failed.length) throw new Error(`Gobernanza 1.6.0: ${failed.length} fallo(s): ${failed.map(x=>x.name).join(', ')}`);
console.log(`OK: ${checks.length} controles de gobernanza 1.6.0.`);
