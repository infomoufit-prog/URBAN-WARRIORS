import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import vm from 'node:vm';

const root = resolve(import.meta.dirname, '..');
const memory = new Map();
const CLUB = '11111111-1111-4111-8111-111111111111';
const USER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const DISC = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const GROUP = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const MEMBER = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const GRADE = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const TARIFF = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
const MATERIAL = '11111111-2222-4333-8444-555555555555';
const SESSION = '22222222-3333-4444-8555-666666666666';
const COMM = '33333333-4444-4555-8666-777777777777';
const ORDER = '44444444-5555-4666-8777-888888888888';
const ENROLLMENT = '55555555-6666-4777-8888-999999999999';

const appSession = { mode: 'supabase', id: USER, email: 'admin@test.local', nombre: 'Admin', rol: 'direccion', roles: ['direccion'], club_id: CLUB, socio_ids: [] };
const authSession = { access_token: 'expired-token', refresh_token: 'refresh-token', expires_at: 1, user: { id: USER, email: appSession.email } };
memory.set('uw_phase1_session_v2', JSON.stringify(appSession));
memory.set('uw_supabase_session', JSON.stringify(authSession));

globalThis.window = globalThis;
globalThis.localStorage = {
  getItem: (key) => memory.has(key) ? memory.get(key) : null,
  setItem: (key, value) => memory.set(key, String(value)),
  removeItem: (key) => memory.delete(key)
};
globalThis.FileReader = class {};
window.UW_CONFIG = {
  demoMode: false, appName: 'Urban Warriors', clubSlug: 'urban-warriors', primaryClubId: CLUB,
  brand: { slogan: 'Bring the Pain', logo: './logo.png' },
  supabase: { enabled: true, url: 'https://example.supabase.co', anonKey: 'sb_publishable_test' }
};
window.UW_DEMO_SEED = { club: { id: 'demo' }, socios: [{ id: 'demo-member' }] };

const calls = [];
let refreshCount = 0;
const club = { id: CLUB, nombre: 'Urban Warriors', slug: 'urban-warriors', activo: true };
const records = new Map([
  ['clubes', [club]], ['disciplinas', []], ['grados', []], ['grupos', []], ['horarios_grupo', []],
  ['socios', []], ['tutores_socios', []], ['socio_disciplinas', []], ['graduaciones', []], ['preinscripciones', []],
  ['tarifas', []], ['cuotas', []], ['pagos', []], ['sesiones_entrenamiento', []], ['asistencias', []],
  ['registros_acceso_clase', []], ['comunicaciones', []], ['seguimiento', []], ['consentimientos', []],
  ['material_catalogo', []], ['material_variantes', []], ['material_pedidos', []], ['notificaciones', []],
  ['config_club', []], ['configuracion_avisos_cuota', []], ['historial_avisos_cuota', []], ['documentos_socios', []],
  ['miembros_club', []], ['invitaciones_club', []], ['v_progreso_socio', []]
]);

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}
function rpcId(name) {
  return ({
    app_guardar_disciplina: DISC, app_guardar_grado: GRADE, app_guardar_grupo: GROUP,
    app_guardar_socio: MEMBER, app_guardar_tarifa: TARIFF, app_guardar_material: MATERIAL,
    app_guardar_sesion: SESSION, app_guardar_comunicacion: COMM, app_solicitar_material: ORDER,
    app_actualizar_pedido_material: ORDER, app_aprobar_preinscripcion: MEMBER, app_crear_preinscripcion: ENROLLMENT,
    app_registrar_graduacion: '66666666-7777-4888-8999-000000000000'
  })[name] || null;
}

globalThis.fetch = async (url, options = {}) => {
  const parsed = new URL(url);
  const method = options.method || 'GET';
  const body = options.body && typeof options.body === 'string' ? JSON.parse(options.body) : options.body;
  calls.push({ url: parsed.href, path: parsed.pathname, method, body, headers: options.headers });

  if (parsed.pathname === '/auth/v1/token' && parsed.searchParams.get('grant_type') === 'refresh_token') {
    refreshCount += 1;
    return jsonResponse({ access_token: 'fresh-token', refresh_token: 'fresh-refresh', expires_in: 3600, user: { id: USER, email: appSession.email } });
  }
  if (parsed.pathname.startsWith('/storage/v1/object/club-public-media/') || parsed.pathname.startsWith('/storage/v1/object/member-documents/') || parsed.pathname.startsWith('/storage/v1/object/justificantes-pago/')) {
    return jsonResponse({ Key: parsed.pathname });
  }
  if (parsed.pathname.startsWith('/rest/v1/rpc/')) {
    const name = parsed.pathname.split('/').pop();
    if (name === 'crear_invitacion_club') return jsonResponse({ id: 'inv-1', token: '77777777-8888-4999-8aaa-bbbbbbbbbbbb', email: body.p_email, rol: body.p_rol });
    if (name === 'app_rechazar_preinscripcion') return jsonResponse(null);
    if (name === 'generar_cuotas_periodo') return jsonResponse(2);
    if (name === 'procesar_avisos_cobro_club') return jsonResponse({ avisos_generados: 5 });
    return jsonResponse(rpcId(name));
  }
  if (parsed.pathname.startsWith('/rest/v1/')) {
    const table = parsed.pathname.replace('/rest/v1/', '');
    if (method === 'GET') return jsonResponse(records.get(table) || []);
    if (method === 'POST') {
      const item = { id: `${table}-1`, club_id: CLUB, ...(body || {}) };
      const list = records.get(table) || []; list.push(item); records.set(table, list);
      return jsonResponse([item]);
    }
    if (method === 'PATCH') return jsonResponse([{ id: 'updated', ...(body || {}) }]);
    if (method === 'DELETE') return jsonResponse([]);
  }
  return jsonResponse([]);
};

vm.runInThisContext(await readFile(resolve(root, 'web/js/data-store.js'), 'utf8'), { filename: 'web/js/data-store.js' });
const store = window.UW_STORE;
await store.init();
if (refreshCount !== 1) throw new Error('La sesión caducada no se renovó automáticamente.');
if (store.getData().socios.some((item) => item.id === 'demo-member')) throw new Error('La producción sigue mostrando datos demo.');
for (const collection of ['socios','grupos','cuotas','material','comunicaciones','notificaciones','documentos']) {
  if (!Array.isArray(store.getData()[collection])) throw new Error(`La colección ${collection} no se inicializó como array.`);
}

await store.saveDiscipline({ nombre: 'Muay Thai', descripcion: 'Adultos', color: '#ffffff', activa: true, orden: 1 });
await store.saveGrade({ disciplina_id: DISC, nombre: 'Nivel inicial', orden: 1, activo: true });
await store.saveGroup({ nombre: 'Adultos tarde', disciplina_id: DISC, monitor: 'Pedro', plazas: 20, edad_min: 16, edad_max: 60, activo: true }, [{ dia_semana: 2, hora_inicio: '19:30', hora_fin: '20:30' }]);
await store.createMember({ nombre: 'Ana', apellidos: 'Prueba', disciplina_id: DISC, grupo_id: GROUP, grado_id: GRADE, tarifa_id: TARIFF, estado: 'activo' });
await store.saveTariff({ nombre: 'Mensual', importe: 40, matricula: 10, activa: true });
await store.saveMaterial({ nombre: 'Guantes', categoria: 'Protección', disciplina_id: DISC, precio: 35, stock: 10, activo: true });
await store.saveCommunication({ tipo: 'evento', titulo: 'Seminario', cuerpo: 'Sesión especial', audiencia: 'todos', estado: 'publicada' });
await store.saveSession({ grupo_id: GROUP, fecha: '2026-08-08', hora_inicio: '19:30', hora_fin: '20:30', monitor: 'Pedro', estado: 'programada' });
await store.requestMaterial({ socio_id: MEMBER, material_id: MATERIAL, cantidad: 1 });
await store.updateMaterialOrder(ORDER, 'preparado');
await store.saveEnrollment({ tipo_solicitud: 'adulto', nombre: 'Solicitante', apellidos: 'Prueba', telefono: '600000000', disciplina_id: DISC, grupo_id: GROUP, tarifa_id: TARIFF });
await store.approveEnrollment(ENROLLMENT);
await store.rejectEnrollment(ENROLLMENT, 'Prueba');
await store.registerGraduation({ socio_id: MEMBER, disciplina_id: DISC, grado_id: GRADE, fecha: '2026-08-06' });
await store.createInvitation('monitor@test.local', 'monitor');
await store.markNotificationRead('notification-1');

const expectedRpcs = [
  'app_guardar_disciplina','app_guardar_grado','app_guardar_grupo','app_guardar_socio','app_guardar_tarifa',
  'app_guardar_material','app_guardar_comunicacion','app_guardar_sesion','app_solicitar_material',
  'app_actualizar_pedido_material','app_crear_preinscripcion','app_aprobar_preinscripcion','app_rechazar_preinscripcion',
  'app_registrar_graduacion','crear_invitacion_club','app_marcar_notificacion_leida'
];
for (const rpc of expectedRpcs) {
  if (!calls.some((call) => call.path === `/rest/v1/rpc/${rpc}`)) throw new Error(`No se llamó a ${rpc}.`);
}
const groupCall = calls.find((call) => call.path === '/rest/v1/rpc/app_guardar_grupo');
if (groupCall.body.p_monitor_nombre !== 'Pedro' || groupCall.body.p_horarios?.[0]?.dia_semana !== 2) throw new Error('El grupo y sus horarios no se envían a la RPC transaccional.');
const memberCall = calls.find((call) => call.path === '/rest/v1/rpc/app_guardar_socio');
if (memberCall.body.p_grupo_id !== GROUP || memberCall.body.p_grado_id !== GRADE) throw new Error('El alumno no conserva grupo y progreso inicial.');

const fakeImage = { size: 100, name: 'cartel.png', type: 'image/png' };
const fakePdf = { size: 200, name: 'ficha.pdf', type: 'application/pdf' };
const mediaUrl = await store.uploadPublicMedia(fakeImage, 'comunicaciones');
if (!mediaUrl.includes('/storage/v1/object/public/club-public-media/')) throw new Error('La URL pública de medios no es correcta.');
await store.uploadMemberDocument(MEMBER, fakePdf, { nombre: 'Ficha', tipo: 'documentacion' });
if (!calls.some((call) => call.path.startsWith('/storage/v1/object/member-documents/'))) throw new Error('No se subió el documento privado del socio.');

console.log('OK: producción sin demo, refresh JWT, RPCs operativas, usuarios, grupos, eventos, material, progreso, invitaciones y Storage.');
