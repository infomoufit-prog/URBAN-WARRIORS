import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC13 EVENTS: ${msg}`);console.log(`OK RC13 EVENTS: ${msg}`)};
const [sql,preflight,verify,rollback,repos,ui,app,permissions]=await Promise.all([
  read('supabase/migrations/033_events_competitions.sql'),read('supabase/verification/preflight_033_events.sql'),read('supabase/verification/verify_033_events.sql'),read('supabase/rollbacks/033_events_competitions.sql'),read('web/js/core/repositories.js'),read('web/js/modules/events.js'),read('web/js/app.js'),read('web/js/core/permissions.js')
]);

assert(sql.includes('create table if not exists public.eventos_competicion'),'eventos tienen entidad propia');
assert(sql.includes('create table if not exists public.evento_participantes'),'inscritos tienen entidad propia');
assert(sql.includes('create table if not exists public.evento_combates'),'combates manuales tienen entidad propia');
const participantTable=sql.match(/create table if not exists public\.evento_participantes[\s\S]*?\n\);/)?.[0]||'';
assert(participantTable.includes('externo boolean')&&participantTable.includes('socio_id uuid'),'participante puede ser socio o externo');
for(const forbidden of ['telefono','email','direccion','documento_identidad'])assert(!new RegExp(`\\b${forbidden}\\b`,'i').test(participantTable),`participante externo no almacena ${forbidden}`);
assert(sql.includes("check ((externo and socio_id is null) or (not externo and socio_id is not null))"),'modelo impide mezclar externo con socio interno');
assert(sql.includes('foreign key(disciplina_id) references public.disciplinas(id) on delete set null'),'eliminar una disciplina no intenta poner club_id a NULL');
assert(sql.includes('foreign key(ganador_participante_id) references public.evento_participantes(id) on delete set null'),'eliminar un participante no intenta poner club_id del combate a NULL');
assert(sql.includes("m.rol in ('direccion','secretaria','monitor')")&&sql.includes('coalesce(m.coordinacion,false)'),'gestión de eventos queda restringida a equipo autorizado');
assert(sql.includes("estado<>'borrador' or public.app_puede_gestionar_eventos_v033"),'borradores no son visibles para miembros ordinarios');
assert(sql.includes('app_evento_participantes_visibles_v033')&&sql.includes('app_evento_combates_visibles_v033'),'lectura operativa usa RPCs seguras');
assert(sql.includes('revoke all on public.evento_participantes from public,anon,authenticated')&&!sql.includes('grant select on public.evento_participantes to authenticated'),'participantes no tienen SELECT directo');
assert(sql.includes('revoke all on public.evento_combates from public,anon,authenticated')&&!sql.includes('grant select on public.evento_combates to authenticated'),'combates no tienen SELECT directo');
assert(sql.includes("ep.estado='confirmado'")&&sql.includes('public.puede_ver_socio(ep.socio_id)'),'miembros ven confirmados y cada familia conserva sus propias solicitudes');
assert(sql.includes('then ep.peso else null')&&sql.includes('then ep.edad else null'),'peso y edad de terceros quedan enmascarados');
assert(sql.includes("p_operation='evento.inscripcion.solicitar'")&&sql.includes("v_event.estado<>'abierto'"),'inscripción normal exige evento abierto');
assert(sql.includes('fecha_limite_inscripcion')&&sql.includes('current_date>v_event.fecha_limite_inscripcion'),'fecha límite se hace cumplir para inscripciones normales');
assert(sql.includes('if public.app_puede_gestionar_eventos_v033(v_club) then')&&sql.includes('evento finalizado o cancelado'),'el equipo puede completar inscritos tras el cierre, pero no en eventos finalizados/cancelados');
assert(sql.includes('public.puede_ver_socio(v_socio.id)'),'familia/alumno solo puede inscribir alumnos vinculados');
assert(sql.includes("v_a.estado<>'confirmado' or v_b.estado<>'confirmado'"),'solo confirmados pueden entrar en un combate');
assert(sql.includes("v_status not in ('pendiente','en_curso','finalizado','cancelado')"),'estado de combate se valida explícitamente');
assert(sql.includes('Cancela o elimina primero los combates activos'),'no se puede invalidar un participante que mantiene combate activo');
assert(sql.includes('v_winner<>v_a.id')&&sql.includes('v_winner<>v_b.id'),'ganador debe pertenecer al enfrentamiento');
assert(sql.includes('estado=v_status')&&sql.includes("p_operation='evento.guardar'"),'editar evento conserva también su estado seleccionado');

assert(repos.includes("backend.readRpc('app_evento_participantes_visibles_v033'")&&repos.includes("backend.readRpc('app_evento_combates_visibles_v033'"),'repositorio consume RPCs seguras');
for(const op of ['evento.guardar','evento.participante.externo','evento.inscripcion.solicitar','evento.inscripcion.estado','evento.inscripcion.baja','evento.combate.guardar','evento.combate.eliminar'])assert(repos.includes(`'${op}'`),`repositorio enruta ${op} por gateway`);
assert(ui.includes('No necesita cuenta ni instalar Urban Warriors'),'externos no necesitan app');
assert(ui.includes('Añadir y confirmar')&&!ui.includes('setTimeout(()=>registrationForm'),'alta de alumno por el equipo usa un único formulario sin temporizadores frágiles');
assert(ui.includes("portal()&&event.estado==='abierto'"),'autoinscripción se limita a familia/alumno con evento abierto');
assert(ui.includes('Emparejamiento manual')&&ui.includes('No se generan cuadros automáticamente'),'MVP mantiene combates manuales sin bracket automático');
assert(ui.includes('Requisitos')&&ui.includes('Inscritos')&&ui.includes('Combates'),'ficha de evento organiza requisitos, inscritos y combates');
assert(app.includes("events:renderEvents")&&app.includes("events:'Eventos'"),'Eventos está conectado al router');
for(const roleLine of ['direccion','secretaria','economia','comunicacion','monitor'])assert(app.includes(roleLine),'navegación conserva rol esperado');
assert(permissions.includes("eventManage:['direccion','coordinacion','secretaria','monitor']"),'permiso frontend coincide con gestión del MVP');
assert(preflight.includes('gateway_032')&&verify.includes('participantes_sin_select_directo'),'preflight/verificación cubren cadena y privacidad');
assert(rollback.includes('app_evento_participantes_visibles_v033'),'rollback cierra RPCs seguras sin borrar datos');
console.log('RC13 EVENTS + COMPETITIONS: PASS');
