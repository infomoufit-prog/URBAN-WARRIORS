import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const has=(txt,frag,msg=frag)=>assert.ok(txt.includes(frag),`Missing ${msg}`);
const not=(txt,frag,msg=frag)=>assert.ok(!txt.includes(frag),`Unexpected ${msg}`);
const tests=[];const test=(name,fn)=>tests.push([name,fn]);
const app=read('web/js/app.js');
const components=read('web/js/ui/components.js');
const showcase=read('web/js/modules/showcase.js');
const events=read('web/js/modules/kombax-events.js');
const icons=read('web/js/ui/icons.js');
const css=read('web/css/kombax-premium.css');
const config=read('web/config.js');
const gradle=read('android/app/build.gradle');
const mainActivity=read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java');
const sw=read('web/service-worker.js');
const health=read('supabase/functions/health/index.ts');

test('R70 build identity is 20121 across Web Android SW and health',()=>{
  has(config,"version: '2.0.0-rc.13-r70-sidebar-private-centers'");has(config,'build: 20121');
  has(gradle,'versionCode 20121');has(gradle,"versionName '2.0.0-rc.13-r70-sidebar-private-centers'");
  has(mainActivity,'KOMBAXRevision/r70-sidebar-private-centers');has(mainActivity,'KOMBAXApp/2.0.0-rc.13/20121');
  has(sw,'kombax-build-20121');has(health,'build:20121');
});

test('Sidebar global order nests private centers under their public product areas',()=>{
  has(components,"const globalIds=[personalId,'social','kombax-events','my-events','showcase','my-showcase']");
  has(components,"const privateCenterIds=new Set(['my-events','my-showcase'])");
  has(components,"nav-private-center");has(components,'data-private-center="true"');
});

test('KOMBAX Events and Mis Eventos have distinct direct routes',()=>{
  has(app,"'kombax-events':renderKombaxEvents,'my-events':renderMyEventsCenter");
  has(app,"'kombax-events':'KOMBAX Events','my-events':'Mis Eventos'");
  has(events,'export async function renderMyEventsCenter()');
});

test('KOMBAX Showcase and Mi Showcase have distinct direct routes',()=>{
  has(app,"showcase:renderShowcase,'my-showcase':renderMyShowcase");
  has(app,"showcase:'KOMBAX Showcase','my-showcase':'Mi Showcase'");
  has(showcase,'export async function renderMyShowcase()');
  has(showcase,"sessionStorage.setItem('kombax_showcase_view','manage')");
});

test('Private center links are only added for club roles capable of managing those areas',()=>{
  has(app,"const PRIVATE_SHOWCASE_ROLES=new Set(['direccion','coordinacion','secretaria','comunicacion'])");
  has(app,"const PRIVATE_EVENTS_ROLES=new Set(['direccion','coordinacion','secretaria','comunicacion'])");
  has(app,'if(canManagePrivateEvents(session))');has(app,"ids.splice(eventsIndex+1,0,'my-events')");
  has(app,'if(canManagePrivateShowcase(session))');has(app,"ids.splice(showcaseIndex+1,0,'my-showcase')");
  not(app,"PRIVATE_SHOWCASE_ROLES=new Set(['familia'");
});

test('Direct private routes remain protected by the same nav allowlist',()=>{
  has(app,'const allowed=new Set(navFor(state.session).map(x=>x.id))');
  has(app,'if(!allowed.has(id))id=\'dashboard\'');
});

test('Parent public product remains visually contextual when a private child is active',()=>{
  has(components,"n.id==='kombax-events'&&active==='my-events'");
  has(components,"n.id==='showcase'&&active==='my-showcase'");
  has(components,'has-active-private-child');
  has(css,'.nav-global .nav-primary.has-active-private-child');
});

test('Private center links have dedicated icons and indented sidebar styling',()=>{
  has(icons,"'my-events':'calendar'");has(icons,"'my-showcase':'shoppingBag'");
  has(css,'/* R70 · Persistent private centers in global sidebar */');
  has(css,'.nav-global .nav-private-center{');
});

test('Spectator/member roles do not receive private center links from navFor role gates',()=>{
  has(app,"else ids=['dashboard','groups','finance','communications','community','events','material','notifications','requests','help','install','profile']");
  not(app,"else ids=['my-showcase'");not(app,"else ids=['my-events'");
});

let passed=0;
for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(error){console.error(`✗ ${name}`);console.error(error.message);}}
console.log(`\nR70 SIDEBAR PRIVATE CENTERS: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exit(1);
