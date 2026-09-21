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
const css=read('web/css/kombax-premium.css');
const config=read('web/config.js');
const gradle=read('android/app/build.gradle');
const mainActivity=read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java');
const sw=read('web/service-worker.js');
const health=read('supabase/functions/health/index.ts');

test('R72 continuity runs on R75 build 20133 across Web Android SW and health',()=>{
  has(config,"version: '2.0.0-rc.13-r81-tap-to-pay'");has(config,'build: 20133');
  has(gradle,'versionCode 20133');has(gradle,"versionName '2.0.0-rc.13-r81-tap-to-pay'");
  has(mainActivity,'KOMBAXRevision/r81-tap-to-pay');has(mainActivity,'KOMBAXApp/2.0.0-rc.13/20133');
  has(sw,'kombax-build-20133');has(health,'build:20133');
});

test('Events and Showcase are rendered as product accordions, not flat private links',()=>{
  has(components,"const productAccordion=({key,parentId,privateId,exploreLabel,privateLabel,accent})=>");
  has(components,"key:'events',parentId:'kombax-events',privateId:'my-events'");
  has(components,"key:'showcase',parentId:'showcase',privateId:'my-showcase'");
  has(components,'data-product-nav');
  not(components,"const privateCenterIds=new Set(['my-events','my-showcase'])");
});

test('Events accordion contains public Explore and private Mis Eventos child',()=>{
  has(components,"exploreLabel:'Explorar Eventos'");has(components,"privateLabel:'Mis Eventos'");
  has(components,"data-nav=\"${esc(parentId)}\"");
  has(components,"data-nav=\"${esc(privateId)}\"");
});

test('Showcase accordion contains public Explore and private Mi Showcase child',()=>{
  has(components,"exploreLabel:'Explorar Showcase'");has(components,"privateLabel:'Mi Showcase'");
});

test('Private children stay permission-gated by navFor',()=>{
  has(app,"if(canManagePrivateEvents(session)){const eventsIndex=ids.indexOf('kombax-events');ids.splice(eventsIndex+1,0,'my-events');}");
  has(app,"if(canManagePrivateShowcase(session)){const showcaseIndex=ids.indexOf('showcase');ids.splice(showcaseIndex+1,0,'my-showcase');}");
});

test('Accordions auto-open for active public/private route and persist user preference',()=>{
  has(components,"const isActive=active===parentId||active===privateId");
  has(components,"localStorage.getItem(`uw2_${key}_nav_open`)");
  has(app,"document.querySelectorAll('[data-product-nav]')");
  has(app,"localStorage.setItem(`uw2_${nav.dataset.productNav}_nav_open`,nav.open?'1':'0')");
});

test('Accordions reuse Mi Club interaction language with dedicated Events/Showcase accents',()=>{
  has(components,'club-nav-accordion product-nav-accordion');
  has(css,'/* R71 · KOMBAX Events / Showcase product accordions in global sidebar */');
  has(css,'.events-product-nav{');has(css,'.showcase-product-nav{');
  has(css,'.product-nav-panel{');has(css,'.product-private-item');
});

test('Direct public/private routes are unchanged',()=>{
  has(app,"showcase:renderShowcase,'my-showcase':renderMyShowcase");
  has(app,"'kombax-events':renderKombaxEvents,'my-events':renderMyEventsCenter");
});

test('Mobile nav remains public-product-first and Mi Club more menu remains intact',()=>{
  has(app,"if(platformFeatures().events)ids.push('kombax-events')");
  has(app,"if(platformFeatures().showcase)ids.push('showcase')");
  has(app,"const map={more:{id:'more',label:'Mi Club'");
});

let passed=0;
for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(error){console.error(`✗ ${name}`);console.error(error.message);}}
console.log(`\nR72 SIDEBAR PRODUCT ACCORDIONS: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exit(1);
