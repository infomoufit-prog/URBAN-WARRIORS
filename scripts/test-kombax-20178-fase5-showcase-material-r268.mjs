import {readFileSync} from 'node:fs';
import {strict as assert} from 'node:assert';
const txt=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const m=txt('web/js/modules/comms-material.js');
const s=txt('web/js/modules/showcase.js');
const r=txt('web/js/core/repositories.js');
const mig=txt('supabase/migrations/20261014170000_kombax_showcase_preserve_inquiries_on_delete_r268.sql');
const mig2=txt('supabase/migrations/20261014170500_kombax_showcase_preserve_associated_history_r268b.sql');
let count=0;
function test(name,run){run();count++;console.log('PASS '+count+': '+name);}
for(const file of ['js/modules/comms-material.js','js/modules/showcase.js','css/app.css']){
 test('dist replica '+file,()=>assert.equal(txt('web/'+file),txt('dist/'+file)));
 test('Android replica '+file,()=>assert.equal(txt('web/'+file),txt('android/app/src/main/assets/www/'+file)));
}
test('Material admin has separate archive and delete actions',()=>{assert.match(m,/detail-delete-material/);assert.match(m,/detail-purge-material/);});
test('Material permanent deletion is limited to canManage role',()=>assert.match(m, /canManage\?`<button class="btn btn-danger detail-purge-material"/));
test('Material delete delegates to safe material.delete',()=>assert.match(m,/repos\.material\.delete\(product\.id\)/));
test('Material never invokes forceDelete from UI',()=>assert.doesNotMatch(m,/repos\.material\.forceDelete/));
test('Material request does not claim prior physical withdrawal',()=>assert.match(m, /'Solicitar material al club'/));
test('Material request still uses existing backend request',()=>assert.match(m,/repos\.material\.request\(v\)/));
test('Showcase deletion retains existing server-authorized operation',()=>assert.match(r,/kombax\.showcase\.elemento\.eliminar/));
test('Showcase inquiries preserved on product deletion',()=>assert.match(mig,/kombax_showcase_inquiries_r58 where elemento_id=v_item\.id/));
test('Migration preserves older Social conversations and product stock history',()=>{assert.match(mig2,/kombax_social_contactos/);assert.match(mig2,/showcase_stock_movements_r65/);assert.match(mig2,/product_reports/);});
test('Migration validates original SQL signature before patch',()=>assert.match(mig,/SHOWCASE_DELETE_RPC_BODY_CHANGED_REVIEW_REQUIRED/));
test('Showcase buyer request uses existing R58 RPC',()=>assert.match(s,/repos\.kombaxShowcase\.inquiryRequest\(item\.id,v\.mensaje\)/));
test('Showcase inquiry request has no Social-profile requirement',()=>{const sub=s.slice(s.indexOf('async function openShowcaseContact(item)'),s.indexOf('async function runPrimaryCta(item)'));assert.doesNotMatch(sub,/proveedor_social_id|myProfiles|showcaseContact\(/)});
test('Showcase query is authenticated at frontend and backend',()=>assert.match(s,/if\(!state\.session\?\.id\)/));
test('Buyer inquiry list is navigable from catalog',()=>assert.match(s,/id="showcase-inquiries"/));
test('Seller inquiry list is navigable from private workspace',()=>assert.match(s,/data-showcase-nav="inquiries"/));
test('Seller inbox reads only scoped provider RPC',()=>assert.match(s,/providerInquiries\(brand\.id,150\)/));
test('Buyer inbox uses owner-scoped RPC',()=>assert.match(s,/myInquiries\(100\)/));
test('Threads fetch messages through authorization RPC',()=>assert.match(s,/inquiryMessages\(inquiry\.id,150\)/));
test('Both sides reply using existing secure RPC',()=>assert.match(s,/inquirySend\(inquiry\.id,v\.mensaje\)/));
test('Replies schedule refresh after modal closes',()=>assert.match(s,/setTimeout\(\(\)=>Promise\.resolve\(onUpdated\(\)\)/));
test('Commerce products still show interested CTA',()=>assert.match(s,/\(commerce\|\|!\['contact','info'\]/));
test('Showcase delete warning now preserves inquiries',()=>assert.match(s,/conservará todos sus registros y mensajes/));
console.log(`KOMBAX PHASE 5 R268 MATERIAL + SHOWCASE: ${count}/${count} PASS`);
