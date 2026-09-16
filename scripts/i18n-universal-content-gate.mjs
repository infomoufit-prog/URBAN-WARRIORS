import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const exists=(p)=>fs.existsSync(path.join(root,p));
const checks=[];
const check=(name,fn)=>{fn();checks.push(name);console.log(`✓ ${name}`);};

const migration='supabase/migrations/20260915224500_kombax_universal_content_translation_u01.sql';
const edge='supabase/functions/kombax-content-translate/index.ts';
const runtime='web/js/i18n/user-content-translation.js';
const app='web/js/app.js';

check('U01 migration exists and is additive cache-only',()=>{
  assert.ok(exists(migration)); const s=read(migration);
  assert.match(s,/create table if not exists public\.kombax_content_translations_u01/i);
  assert.match(s,/source_hash/i); assert.match(s,/target_locale/i); assert.match(s,/translated_text/i);
  assert.match(s,/enable row level security/i);
  assert.doesNotMatch(s,/drop table\s+(?!if exists public\.kombax_content_translations_u01)/i);
  assert.match(s,/visibility = 'public' and requester_id is null/i);
});
check('U01 Edge translator preserves original and scopes private cache',()=>{
  const s=read(edge);
  assert.match(s,/preserve_original:true/g);
  assert.match(s,/visibility==='private'\?String\(user\.id\):null/);
  assert.match(s,/source_hash/);
  assert.match(s,/target_locale/);
  assert.match(s,/Never censor or rewrite the author's meaning/);
});
check('U02 universal runtime installed globally',()=>{
  const r=read(runtime),a=read(app);
  assert.match(a,/installUniversalContentTranslation/);
  assert.match(a,/installUniversalContentTranslation\(\)/);
  assert.match(r,/MutationObserver/); assert.match(r,/IntersectionObserver/);
  assert.match(r,/viewOriginal/); assert.match(r,/seeTranslation/);
  assert.match(r,/kxContentVisibility==='private'/);
  assert.match(r,/lookupPublicCachedTranslation/);
});
check('Private messages are not auto-translated',()=>{
  const r=read(runtime),s=read('web/js/modules/kombax-social.js');
  assert.match(r,/kxContentVisibility==='private'\)return false/);
  assert.match(s,/contentType:'social_message'[\s\S]{0,180}visibility:'private'[\s\S]{0,80}auto:false/);
});
check('Social posts and comments expose translation metadata',()=>{
  const s=read('web/js/modules/kombax-social.js');
  assert.match(s,/contentType:'social_post'/); assert.match(s,/contentType:'social_comment'/);
});
check('Showcase product content and reviews expose translation metadata',()=>{
  const s=read('web/js/modules/showcase.js');
  assert.match(s,/contentType:'showcase_product_name'/);
  assert.match(s,/contentType:'showcase_product_(summary|description)'/);
  assert.match(s,/contentType:'showcase_product_review'/);
});
check('Events content/community/media expose translation metadata',()=>{
  const s=read('web/js/modules/kombax-events.js');
  assert.match(s,/contentType:'event_(name|description|comment|review|media)'/);
});
check('Profiles, clubs and communities expose authored copy translation',()=>{
  assert.match(read('web/js/modules/public-profile.js'),/contentType:'public_profile_bio'/);
  assert.match(read('web/js/modules/club-profile.js'),/contentType:'club_editorial'/);
  assert.match(read('web/js/modules/community.js'),/contentType:'community_post'/);
});
check('Club communications and material/products expose authored translation metadata',()=>{
  const s=read('web/js/modules/comms-material.js');
  assert.match(s,/contentType:'communication_message'/);
  assert.match(s,/contentType:'club_material_name'/);
  assert.match(s,/contentType:'club_material_description'/);
});
check('Private document metadata is opt-in only',()=>{
  const s=read('web/js/modules/documents.js');
  assert.match(s,/contentType:'document_description'/);
  assert.match(s,/visibility:'private'[\s\S]{0,80}auto:false/);
});
check('Universal prewarm accepts multi-field content batches and all authored content types',()=>{
  const r=read(runtime);
  assert.match(r,/Array\.isArray\(input\)/);
  for(const type of ['social_post','social_comment','social_message','showcase_product_name','showcase_product_review','event_name','event_comment','public_profile_bio','club_editorial','brand_editorial','communication_message','club_material_name','club_tariff','work_scope','document_description']) assert.match(r,new RegExp(`['\"]${type}['\"]`),`missing ${type}`);
});

check('Automatic public-content translation preference is exposed in Settings',()=>{
  const s=read('web/js/modules/admin.js');
  assert.match(s,/kx-auto-content-translation/);
  assert.match(s,/setAutoTranslatePublicEnabled/);
});
check('All 8 locales contain translation controls',()=>{
  for(const loc of ['es','en','fr','pt','it','de','th','fil']){
    const s=read(`web/js/i18n/locales/${loc}/common.js`);
    for(const key of ['seeTranslation','viewOriginal','translating','translated','failed']) assert.match(s,new RegExp(`[\"']?${key}[\"']?\\s*:`),`${loc} missing ${key}`);
  }
});

check('First onboarding interface exposes the 8-language selector before club/profile choice',()=>{
  const g=read('web/js/modules/gateway.js'),u=read('web/js/i18n/ui.js');
  assert.match(g,/gateway-onboarding-language/);
  assert.match(g,/kombax-language-onboarding/);
  assert.match(g,/languageSelectorHtml/);
  assert.match(g,/bindLanguageSelectors\(document,\{onChange:/);
  assert.match(u,/onChange=null/);
  for(const loc of ['es','en','fr','pt','it','de','th','fil']) assert.match(read(`web/js/i18n/locales/${loc}/common.js`),/["\']?onboardingHint["\']?\s*:/,`${loc} missing onboardingHint`);
});


check('Pre-SPA boot screen is multilingual before onboarding renders',()=>{
  const html=read('web/index.html'),boot=read('web/js/i18n/boot-language.js');
  assert.match(html,/data-kx-boot-language/);
  assert.match(html,/boot-language\.js/);
  assert.match(boot,/kombax_locale/);
  for(const loc of ['es','en','fr','pt','it','de','th','fil']) assert.match(boot,new RegExp(`['"]${loc}['"]`),`boot missing ${loc}`);
});

check('Universal translation Edge Function is JWT-protected in Supabase config',()=>{
  const s=read('supabase/config.toml');
  assert.match(s,/\[functions\.kombax-content-translate\][\s\S]*?verify_jwt\s*=\s*true/);
});

check('No source table is overwritten by translation cache migration',()=>{
  const s=read(migration);
  for(const table of ['social','showcase','event','message','comment','product']){
    assert.doesNotMatch(s,new RegExp(`update\\s+public\\.[a-z0-9_]*${table}`,'i'));
  }
});

console.log(`\nKOMBAX universal content translation gate: ${checks.length}/${checks.length} PASS`);
