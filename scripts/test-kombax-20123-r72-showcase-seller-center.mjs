import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const has=(txt,frag,msg=frag)=>assert.ok(txt.includes(frag),`Missing ${msg}`);
const not=(txt,frag,msg=frag)=>assert.ok(!txt.includes(frag),`Unexpected ${msg}`);
const tests=[];const test=(name,fn)=>tests.push([name,fn]);
const showcase=read('web/js/modules/showcase.js');
const premium=read('web/css/kombax-premium.css');
const pricing=read('web/js/core/commercial-pricing.js');
const migration=read('supabase/migrations/20260914080534_kombax_r68_showcase_seller_activation_basic_access.sql');
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

test('Showcase catalog exposes Mi Showcase for managed sellers',()=>{
  has(showcase,'Mi Showcase</button>');has(showcase,"activeView='manage'");has(showcase,'MI SHOWCASE · CENTRO DE VENDEDOR');
});

test('Club Basic seller account remains accessible without Commerce',()=>{
  has(showcase,'Cuenta vendedor por activar');has(showcase,'Activar cuenta vendedor');
  has(showcase,'Commerce no activo');has(showcase,'Activar Commerce · 12 €/30 días');
  has(showcase,'Tu espacio privado de vendedor: catálogo y estadísticas siempre disponibles');
});

test('Seller verification and commercial plan rights are separate backend states',()=>{
  for(const frag of ["'seller_account'","'activation_required',true","'activation_status',v_activation_status","'active',v_seller_active","'commercial_access'","'seller_center_access',true","'catalog_management',true","'commerce_allowed',v_commerce_allowed","'checkout_available',v_seller_active and v_commerce_allowed","'commerce_activation_required'"])has(migration,frag);
});

test('Seller activation definition requires verification policies and Stripe',()=>{
  has(migration,"'activation_definition','identity_verified + seller_verified + policies_accepted + stripe_ready'");
  has(migration,'kombax_marketplace.seller_ready_r627(p_provider_id)');
});

test('Seller Center explicitly explains active account vs Commerce',()=>{
  has(showcase,'Cuenta de vendedor ACTIVA');has(showcase,'independiente del plan Commerce');
  has(showcase,'Commerce es un derecho comercial separado');has(showcase,'Checkout');
});

test('Basic catalog creation remains available while checkout fields are locked',()=>{
  has(showcase,'function itemEditor(brand,item=null,{commerceAllowed=true,sellerAccountActive=true}={})');
  has(showcase,'const commerceLocked=!commerceAllowed');has(showcase,'disabled:checkoutLocked');has(showcase,'disabled:commerceLocked');
  has(showcase,'const directCommerce=service?false:(checkoutLocked?false:v.commerce_enabled===true)');
});

test('Seller workspace exposes products and statistics independent from Commerce',()=>{
  has(showcase,"tool('products','Productos'");has(showcase,"tool('stats',t('showcase.analytics.title')");
  has(showcase,"tool('seller',sellerAccountActive?'Cuenta vendedor activa':'Activar cuenta vendedor'");
  has(showcase,'showcase-products-section');has(showcase,'showcase-seller-dashboard');
});

test('Orders stock finance and communications are visible but gated by checkout',()=>{
  for(const id of ['orders','stock','finance','communications'])has(showcase,`tool('${id}'`);
  has(showcase,'locked:!checkoutAvailable');has(showcase,"reason:lockReason");
  has(showcase,"if(reason==='commerce')");has(showcase,"if(reason==='activation')");
});

test('Enterprise BI remains plan gated',()=>{
  has(showcase,"planCode==='enterprise'||planCode==='brand_enterprise'");has(showcase,"reason:'enterprise'");
});

test('R72 preserves responsive seller workspace styling',()=>{
  for(const frag of ['.kx-seller-workspace{','.kx-seller-tools{','.kx-seller-tool{','.kx-seller-commerce-cta{','@media(max-width:620px)'])has(premium,frag);
});

test('R64.4 pricing baseline is unchanged',()=>{
  for(const frag of ["plan_code:'club'",'showcase_model_limit:15',"commerce_temporary:{30:{price_minor:1200,renewable:true}","plan_code:'premium'",'showcase_model_limit:25',"plan_code:'enterprise'",'content_promotion:{7:300,15:500,30:800'])has(pricing,frag);
});

test('R72 preserves separation: seller verification does not turn Commerce on',()=>{
  not(migration,"commerce_allowed',v_seller_active");
  has(migration,'v_commerce_allowed := kombax_commercial.provider_commerce_allowed_r64(p_provider_id)');
});

let passed=0;
for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(error){console.error(`✗ ${name}`);console.error(error.message);}}
console.log(`\nR72 SHOWCASE SELLER CENTER CONTINUITY: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exit(1);
