import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const has=(txt,frag,msg=frag)=>assert.ok(txt.includes(frag),`Missing ${msg}`);
const not=(txt,frag,msg=frag)=>assert.ok(!txt.includes(frag),`Unexpected ${msg}`);
const tests=[];const test=(name,fn)=>tests.push([name,fn]);

const events=read('web/js/modules/kombax-events.js');
const repos=read('web/js/core/repositories.js');
const css=read('web/css/kombax-premium.css');
const migration=read('supabase/migrations/20260914083811_kombax_r69_event_center_operations.sql');
const pricing=read('web/js/core/commercial-pricing.js');
const config=read('web/config.js');
const gradle=read('android/app/build.gradle');
const mainActivity=read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java');
const sw=read('web/service-worker.js');
const health=read('supabase/functions/health/index.ts');

test('R71 build identity is 20122 across Web Android SW and health',()=>{
  has(config,"version: '2.0.0-rc.13-r71-sidebar-product-accordions'");has(config,'build: 20122');
  has(gradle,'versionCode 20122');has(gradle,"versionName '2.0.0-rc.13-r71-sidebar-product-accordions'");
  has(mainActivity,'KOMBAXRevision/r71-sidebar-product-accordions');has(mainActivity,'KOMBAXApp/2.0.0-rc.13/20122');
  has(sw,'kombax-build-20122');has(health,'build:20122');
});

test('Organizer navigation exposes Mis Eventos without replacing the existing editor',()=>{
  has(events,'Mis Eventos</button>');has(events,'renderMyEventsCenter');
  has(events,'Gestionar evento ≠ Centro del evento');
  has(events,'Constructor del evento');has(events,'Centro del evento');
});

test('Private managed-event repository uses the R71 manager RPC',()=>{
  has(repos,"myManagedEvents:(limit=100)=>backend.globalReadRpc('app_kombax_event_center_list_r69'");
});

test('R71 private event-center RPC includes drafts/private events only when user can manage them',()=>{
  has(migration,'from public.kombax_eventos_publicos e');
  has(migration,'where public.app_kombax_evento_puede_gestionar_v160(e.id)');
  not(migration,"where e.estado='publicado'");
  not(migration,"where e.visibilidad='publica'");
  has(migration,"if v_uid is null then raise exception 'AUTH_REQUIRED'");
});

test('R71 RPC explicitly denies anon/public execution and grants authenticated',()=>{
  has(migration,'revoke all on function public.app_kombax_event_center_list_r69(integer) from public,anon;');
  has(migration,'grant execute on function public.app_kombax_event_center_list_r69(integer) to authenticated;');
});

test('Mis Eventos exposes operational summary cards and per-event center entry',()=>{
  for(const frag of ['Eventos gestionables','Publicados','Próximos','Ticketing activo','Centro del evento','Gestionar evento','Ver ficha'])has(events,frag);
  has(events,'eventCenterCard');has(events,'eventCenterOccupancy');
});

test('Center keeps basic publication statistics available without Ticketing',()=>{
  has(events,"eventOpsTool('stats','Estadísticas'");has(events,'openEventBasicStats');
  has(events,'Vistas · 30 días');has(events,'Siguiendo evento');
  has(events,'El evento puede publicarse y medirse sin Ticketing');
});

test('Ticketing-dependent operational tools remain visible but locked when inactive',()=>{
  for(const id of ['sales','attendees','access','finance','refunds','communications','history','staff'])has(events,`eventOpsTool('${id}'`);
  has(events,"locked:!ticketingOps");has(events,"reason:'ticketing'");
  has(events,"Esta herramienta se habilita al activar Ticketing para este evento.");
});

test('Ticketing activation is visibly separated into service config contracts and Stripe',()=>{
  for(const label of ['Servicio','Configuración','Condiciones','Stripe'])has(events,label);
  has(events,'contractsReady');has(events,'stripeReady');has(events,'checkoutReady');
  has(events,"ticketingManageStatus(event.id)");
});

test('Existing operational backends are reused for sales access finance communications and BI',()=>{
  for(const fn of ['openEventTicketSales','openEventAccessScanner','openEventFinance','openEventCommunications','openEventAccessHistory','openEventTicketStaff','openEventBI'])has(events,fn);
  for(const repo of ['ticketSales','ticketDashboard','finance','communications','businessIntelligence','checkinHistory','ticketStaff'])has(repos,repo);
});

test('Organizer can inspect attendees derived from existing paid-ticket ledger',()=>{
  has(events,'async function openEventAttendees(event)');has(events,'repos.kombaxEvents.ticketSales(event.id,500)');
  has(events,'Asistentes y entradas');has(events,'check-in');has(events,'pendientes');has(events,'reembolsadas');
});

test('Event management menu now links to Center without removing editor/ticketing/access',()=>{
  has(events,'data-kx-manage="operations"');has(events,"operations:()=>{closeModal();void renderEventOperationsCenter(event.id,event);}");
  for(const action of ['builder:()=>openEventBuilder(event)','ticketing:()=>openEventTicketingManager(event)','access:()=>openEventAccessScanner(event)','edit:()=>openEventEditor(event)'])has(events,action);
});

test('R71 center has responsive Events-specific styling',()=>{
  for(const frag of ['/* R69 · Mis Eventos + Centro del evento */','.kx-my-events-list{','.kx-event-ops-kpis{','.kx-event-ops-activation{','.kx-event-ops-tools{','@media(max-width:620px)'])has(css,frag);
});

test('R64.4 Events pricing and buyer/platform fees remain unchanged',()=>{
  for(const frag of ['event_publication:{7:500,15:800,30:1200,60:1800}','content_promotion:{7:300,15:500,30:800','50:1000','100:1500','200:2500','500:4500','1000:7500','ticketing_buyer_fee_minor:0'])has(pricing,frag);
});

test('R71 does not conflate publication with Ticketing',()=>{
  has(events,'Gestionar evento ≠ Centro del evento');
  has(events,'Activación independiente por evento');
  has(events,'El evento puede publicarse y medirse sin Ticketing');
  not(migration,"ticketing_enabled',true");
});

let passed=0;
for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(error){console.error(`✗ ${name}`);console.error(error.message);}}
console.log(`\nR71 EVENTS OPERATIONS CENTER: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exit(1);
