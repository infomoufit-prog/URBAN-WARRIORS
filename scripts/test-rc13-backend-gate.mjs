import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC13 BACKEND GATE: ${msg}`);console.log(`OK RC13 BACKEND GATE: ${msg}`)};
const [cfg,backend,m32,m33,m34,m35,m36]=await Promise.all([
  read('web/config.js'),read('web/js/core/backend.js'),read('supabase/migrations/032_social_profiles_likes.sql'),read('supabase/migrations/033_events_competitions.sql'),
  read('supabase/migrations/034_notifications_actionable.sql'),read('supabase/migrations/035_club_public_profile.sql'),read('supabase/migrations/036_social_access_safety_age.sql')
]);
const requiredBlock=cfg.match(/requiredOperations:\s*\[([\s\S]*?)\]/)?.[1]||'';
const required=[...requiredBlock.matchAll(/'([^']+)'/g)].map(x=>x[1]);
const social=['perfil_deportivo.guardar','perfil_deportivo.foto','perfil_deportivo.moderar','comunidad.like'];
const events=['evento.guardar','evento.estado','evento.participante.externo','evento.inscripcion.solicitar','evento.inscripcion.estado','evento.inscripcion.baja','evento.combate.guardar','evento.combate.eliminar'];
const notifications=['notificacion.revisar'];
const clubPublic=['club_publico.guardar'];
const safety=['comunidad_general.activar','comunidad.denunciar','comunidad.bloquear','comunidad.denuncia.estado','comunidad_general.moderar_acceso'];
assert(required.length===19,'RC13 build 20020 exige exactamente las 19 capacidades nuevas acumuladas');
for(const op of [...social,...events,...notifications,...clubPublic,...safety])assert(required.includes(op),`contrato cliente exige ${op}`);
assert(backend.includes('missingOperations')&&backend.includes('Operaciones RC13 ausentes'),'login/restauración falla de forma explícita si Supabase no tiene RC13 completo');
for(const op of social)assert(m32.includes(`'${op}'`),`032 publica ${op} en contrato runtime`);
for(const op of events)assert(m33.includes(`'${op}'`),`033 publica ${op} en contrato runtime`);
for(const op of notifications)assert(m34.includes(`'${op}'`),`034 publica ${op} en contrato runtime`);
for(const op of clubPublic)assert(m35.includes(`'${op}'`),`035 publica ${op} en contrato runtime`);
for(const op of safety)assert(m36.includes(`'${op}'`),`036 publica ${op} en contrato runtime`);
console.log('RC13 BUILD 20020 BACKEND CAPABILITY GATE: PASS');
