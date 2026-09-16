import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20101 R6: ${msg}`);console.log(`OK 20101 R6: ${msg}`)};
const [events,migration,packageJson]=await Promise.all([
  read('web/js/modules/kombax-events.js'),
  read('supabase/migrations/179_kombax_events_urban_warriors_pilot_20101.sql'),
  read('package.json')
]);
assert(events.includes("let filters={query:'',tipo:'',estado:''}")&&!events.includes("export async function renderKombaxEvents(){\n  resetEventFilters();"),'Events conserva filtros al reentrar en la ruta desde R26 para continuidad de navegación');
assert(events.includes('Todos los tipos')&&events.includes('Cartelera completa'),'existe reset explícito de tipo de evento');
assert(events.includes('Mostrar todos los eventos')&&events.includes('kx-events-reset-filters'),'estado vacío filtrado permite recuperar la cartelera');
assert(events.includes("if((b.dataset.kxState||'')===''){resetEventFilters();void loadDiscovery({append:false});return;}")||events.includes("if((b.dataset.kxState||'')===''){resetEventFilters({render:true});return;}"),'tab Todos limpia estado, tipo y búsqueda y refresca la fuente vigente');
assert(events.includes("id=\"kx-events-create\"")&&events.includes('openEventEditor()'),'botón Crear evento conserva editor real');
assert(events.includes('kx-events-create-unavailable')&&events.includes('candidate.motivo'),'identidades sin entitlement reciben explicación en vez de silencio');
assert(migration.includes("events.public.organize")&&migration.includes("lower(trim(c.nombre))='urban warriors'"),'migración piloto habilita solo Urban Warriors sin ID generado hardcodeado');
assert(migration.includes("origen='promocion'")&&migration.includes("termina_en=null"),'entitlement piloto queda activo e idempotente');
assert(packageJson.includes('test:20101:r6'),'package expone test específico R6');
console.log('PASS 20101 R6 Events Discovery + Club Create');
