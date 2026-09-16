import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`R62.6 FAIL · ${msg}`);console.log(`✓ ${msg}`);};

const migration=read('supabase/migrations/20260911102242_kombax_r626_social_discovery.sql');
const repo=read('web/js/core/repositories.js');
const mod=read('web/js/modules/kombax-discovery.js');
const social=read('web/js/modules/kombax-social.js');
const profile=read('web/js/modules/public-profile.js');
const hub=read('web/js/modules/managed-profile-hub.js');
const fighter=read('web/js/modules/fighter-discovery.js');
const events=read('web/js/modules/kombax-events.js');
const css=read('web/css/kombax-social.css');

assert(migration.includes('availability_status')&&migration.includes('availability_public'),'estado general de disponibilidad separado y publicable');
assert(migration.includes('kombax_discovery_availability_slots_r626'),'franjas de fecha/hora opcionales separadas');
assert(!migration.includes('kombax_professional_availability_v198'),'Discovery no lee la agenda profesional privada');
assert(!/premium_required|stripe/i.test(mod),'Discovery UI no contiene paywall ni Stripe');
assert(!/premium_required|stripe/i.test(migration),'Discovery backend no contiene paywall ni Stripe');
assert(['app_kombax_discovery_search_r626','app_kombax_discovery_profile_r626','app_kombax_discovery_mutate_r626','app_kombax_discovery_slots_r626','app_kombax_discovery_slot_mutate_r626','app_kombax_discovery_public_profile_r626'].every(x=>migration.includes(x)),'seis RPC R62.6 presentes');
assert(migration.includes('from public,anon,service_role')&&migration.includes('to authenticated'),'RPC Discovery autenticadas y anon revocado');
assert(['fight_count_declared','wins_declared','losses_declared','draws_declared','affiliation_status','accepts_short_notice'].every(x=>migration.includes(x)),'filtros/datos públicos de competidor presentes');
assert(['specialty','work_modes','experience_years','credential_verified'].every(x=>migration.includes(x)),'filtros profesionales presentes');
assert(migration.includes("v_date_from is null or exists")&&mod.includes('fecha opcional'),'horarios opcionales y no requeridos para estado Disponible');
assert(repo.includes("discovery:{")&&repo.includes('app_kombax_discovery_search_r626'),'repositorio común Discovery conectado');
assert(social.includes('data-social-view="discovery"')&&social.includes('renderKombaxDiscovery'),'Discovery es vista de primer nivel en KOMBAX Social');
assert(social.includes('Descubrir competidores y profesionales'),'directorio Social enlaza al motor común');
assert(hub.includes("discovery_availability:'Disponibilidad y Discovery'")&&hub.includes("['competidor','profesional'].includes(profile.tipo)"),'Competidor y Profesional pueden editar Discovery desde su hub');
assert(profile.includes('Disponibilidad y Discovery')&&profile.includes('repos.discovery.publicProfile'),'perfil público muestra disponibilidad declarada si procede');
assert(profile.includes('kx-public-discovery-manage'),'perfil propio ofrece edición de disponibilidad');
assert(mod.includes('repos.kombaxSocial.contact(')&&mod.includes('No se comparte teléfono, email ni dirección'),'contacto reutiliza KOMBAX Social sin exponer PII');
assert(events.includes('Discovery · personas')&&events.includes("openKombaxDiscovery({preset:'all',event})"),'Events reutiliza Discovery general');
assert(events.includes('openFighterDiscovery')&&fighter.includes('Invitar al combate'),'fighter discovery especializado e invitaciones se conservan');
assert(fighter.includes("import('./kombax-discovery.js')"),'editor legacy de competidor delega al nuevo estado R62.6');
assert(css.includes('KOMBAX 20.110 R62.6 · Social Discovery')&&css.includes('.kx-discovery-grid'),'estilos Discovery responsive presentes');
assert(mod.includes('No necesitas franjas horarias para aparecer como Disponible')&&mod.includes('Estado general ≠ agenda.'),'UI explica explícitamente disponibilidad simple vs agenda opcional');

console.log('\nKOMBAX R62.6 SOCIAL DISCOVERY: PASS');
