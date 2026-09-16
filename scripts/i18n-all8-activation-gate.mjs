import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {resources} from '../web/js/i18n/resources.js';
import {SUPPORTED_LOCALES,ENABLED_LOCALES,setLocale} from '../web/js/i18n/index.js';
import {localizeSystemText} from '../web/js/i18n/legacy-runtime.js';
import {humanError} from '../web/js/core/utils.js';
import {LEGACY_FR_COMPLETE} from '../web/js/i18n/legacy-copy-fr-complete.js';
import {LEGACY_PT_COMPLETE} from '../web/js/i18n/legacy-copy-pt-complete.js';
import {LEGACY_IT_COMPLETE} from '../web/js/i18n/legacy-copy-it-complete.js';
import {LEGACY_DE_COMPLETE} from '../web/js/i18n/legacy-copy-de-complete.js';
import {LEGACY_TH_COMPLETE} from '../web/js/i18n/legacy-copy-th-complete.js';
import {LEGACY_FIL_COMPLETE} from '../web/js/i18n/legacy-copy-fil-complete.js';
import {PUBLIC_LEGAL_TRANSLATIONS} from '../web/js/i18n/public-legal-translations.js';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const LOCALES=['es','en','fr','pt','it','de','th','fil'];
const NEW=['fr','pt','it','de','th','fil'];
const LEGACY={fr:LEGACY_FR_COMPLETE,pt:LEGACY_PT_COMPLETE,it:LEGACY_IT_COMPLETE,de:LEGACY_DE_COMPLETE,th:LEGACY_TH_COMPLETE,fil:LEGACY_FIL_COMPLETE};
const flat=(o,p='',out={})=>{for(const[k,v]of Object.entries(o||{})){const q=p?`${p}.${k}`:k;if(v&&typeof v==='object'&&!Array.isArray(v))flat(v,q,out);else if(Array.isArray(v))v.forEach((x,i)=>typeof x==='string'?out[`${q}.${i}`]=x:flat(x,`${q}.${i}`,out));else out[q]=v}return out};
const placeholders=s=>[...String(s??'').matchAll(/\{\{\s*[\w.-]+\s*\}\}|\{[A-Z0-9_]+\}|\$\{[^}]+\}/g)].map(m=>m[0].replace(/\s/g,'')).sort();
const report={generated_at:new Date().toISOString(),status:'PASS',enabled_locales:ENABLED_LOCALES,catalog:{},legacy:{},legal:{},checks:[]};
const ok=(name,fn)=>{fn();report.checks.push({name,status:'PASS'});console.log(`✓ ${name}`)};

ok('all eight supported locales are publicly enabled',()=>{assert.deepEqual(SUPPORTED_LOCALES,LOCALES);assert.deepEqual(ENABLED_LOCALES,LOCALES)});
const es=flat(resources.es);const masterKeys=Object.keys(es).sort();
ok('all eight direct catalogs match the current master and preserve the 1077-key activation baseline',()=>{
  assert.ok(masterKeys.length>=1077,`master catalog regressed below activation baseline: ${masterKeys.length}`);
  for(const l of LOCALES){const m=flat(resources[l]);const keys=Object.keys(m).sort();assert.deepEqual(keys,masterKeys,`${l}: key drift`);let empty=0,ph=0;for(const k of masterKeys){if(typeof m[k]!=='string'||!m[k].trim())empty++;if(JSON.stringify(placeholders(m[k]))!==JSON.stringify(placeholders(es[k])))ph++;}assert.equal(empty,0,`${l}: empty translations`);assert.equal(ph,0,`${l}: placeholder drift`);report.catalog[l]={keys:keys.length,coverage:100,empty,placeholder_mismatches:ph};}
});
ok('critical UI copy is directly localized in each non-Spanish locale',()=>{
  const expected={
    en:{save:'Save',search:'Search',ticket:'Buy ticket'},
    fr:{save:'Enregistrer',search:'Rechercher',ticket:'Acheter un billet'},
    pt:{save:'Guardar',search:'Pesquisar',ticket:'Comprar bilhete'},
    it:{save:'Salva',search:'Cerca',ticket:'Acquista biglietto'},
    de:{save:'Speichern',search:'Suchen',ticket:'Ticket kaufen'},
    th:{save:'บันทึก',search:'ค้นหา',ticket:'ซื้อตั๋ว'},
    fil:{save:'I-save',search:'Maghanap',ticket:'Bumili ng ticket'}
  };
  for(const [l,x] of Object.entries(expected)){assert.equal(resources[l].common.actions.save,x.save);assert.equal(resources[l].common.actions.search,x.search);assert.equal(resources[l].ticketing.buyTicket,x.ticket);}
  assert.match(resources.th.common.actions.save,/[ก-๿]/,'Thai critical UI must use Thai script');
});
const legacyBase=Object.keys(LEGACY.fr).sort();
ok('six newly activated locales have complete direct legacy-copy maps',()=>{
  assert.equal(legacyBase.length,2580);
  for(const l of NEW){const map=LEGACY[l];const keys=Object.keys(map).sort();assert.deepEqual(keys,legacyBase,`${l}: legacy key drift`);let empty=0,ph=0,same=0;for(const source of keys){const dst=String(map[source]??'');if(!dst.trim())empty++;if(source.trim()===dst.trim())same++;if(JSON.stringify(placeholders(source))!==JSON.stringify(placeholders(dst)))ph++;}assert.equal(empty,0,`${l}: empty legacy translation`);assert.equal(ph,0,`${l}: legacy placeholder drift`);assert.ok(same/keys.length<0.10,`${l}: suspicious untranslated legacy copy ${same}/${keys.length}`);report.legacy[l]={phrases:keys.length,empty,placeholder_mismatches:ph,identical_to_spanish:same};}
});
ok('public legal pages have 133 direct translations in each activated non-Spanish locale',()=>{
  for(const l of ['en',...NEW]){const map=PUBLIC_LEGAL_TRANSLATIONS[l]||{};const keys=Object.keys(map);assert.equal(keys.length,133,`${l}: public legal coverage`);let empty=0,ph=0;for(const src of keys){const dst=String(map[src]??'');if(!dst.trim())empty++;if(JSON.stringify(placeholders(src))!==JSON.stringify(placeholders(dst)))ph++;}assert.equal(empty,0,`${l}: empty legal translation`);assert.equal(ph,0,`${l}: legal placeholder drift`);report.legal[l]={strings:keys.length,empty,placeholder_mismatches:ph};}
});

ok('public legal HTML resolves directly in every active non-Spanish locale',()=>{
  const files=['web/privacy.html','web/terms.html','web/child-safety.html','web/delete-account.html'];
  const spanish=/[áéíóúüñ¿¡]|\b(?:Condiciones|Privacidad|Eliminar|Seguridad|Cuenta|Datos|Derechos|Responsable|Contacto|Menores|Tratamiento|Solicitar|Acceso|Conservar|Información|Uso|Servicio|Plataforma|Usuario|Correo|Borrar|Cerrar|Soporte|Legal|Protección)\b/i;
  const values=[];
  for(const file of files){const html=fs.readFileSync(path.join(root,file),'utf8');let m;const re=/>\s*([^<>]{2,700}?)\s*</g;while((m=re.exec(html))){const v=m[1].replace(/&nbsp;/g,' ').replace(/&amp;/g,'&').replace(/\s+/g,' ').trim();if(v&&!v.includes('{{')&&!/^\W*$/.test(v)&&spanish.test(v)&&!/^[^\s]+@kombax\.es$/i.test(v))values.push(v)}}
  const unique=[...new Set(values)];assert.ok(unique.length>=90);
  for(const l of ['en',...NEW])for(const source of unique){const translated=localizeSystemText(source,l);assert.ok(String(translated).trim(),`${l}: blank public translation`);const direct=PUBLIC_LEGAL_TRANSLATIONS[l]||{};assert.ok(Object.prototype.hasOwnProperty.call(direct,source),`${l}: public legal source missing direct map: ${source}`);}
});
ok('global client errors localize in all eight locales',()=>{
  const expected={es:'El correo o la contraseña no son correctos.',en:'The email or password is incorrect.',fr:'L’e-mail ou le mot de passe est incorrect.',pt:'O e-mail ou a palavra-passe estão incorretos.',it:'L’e-mail o la password non sono corretti.',de:'E-Mail oder Passwort ist falsch.',th:'อีเมลหรือรหัสผ่านไม่ถูกต้อง',fil:'Mali ang email o password.'};
  for(const [l,value] of Object.entries(expected)){setLocale(l,{allowSupported:true,persist:false});assert.equal(humanError(new Error('invalid login credentials')),value,l)}setLocale('es',{allowSupported:true,persist:false});
});

ok('PWA manifests exist for every enabled locale',()=>{for(const l of NEW.concat('en'))assert.ok(fs.existsSync(path.join(root,`web/manifest-${l}.webmanifest`)),l);assert.ok(fs.existsSync(path.join(root,'web/manifest.webmanifest')))});
ok('all six Supabase Auth templates branch explicitly for all eight locales',()=>{for(const name of ['confirmation','recovery_otp','magic_link_otp','invite','reauthentication_otp','password_changed']){const s=fs.readFileSync(path.join(root,`supabase/auth_templates/${name}_20124_i18n.html`),'utf8');for(const l of ['en',...NEW])assert.match(s,new RegExp(`eq \\.Data\\.preferred_locale "${l}"`),`${name}:${l}`)}});
ok('legacy runtime uses direct locale maps for FR/PT/IT/DE/TH/FIL without English auto fallback',()=>{const s=fs.readFileSync(path.join(root,'web/js/i18n/legacy-runtime.js'),'utf8');for(const l of NEW)assert.match(s,new RegExp(`${l}:LEGACY_${l.toUpperCase()}_COMPLETE`));assert.match(s,/if\(locale==='en'\)\{const auto=autoTranslateLegacyEnglish/)});
ok('Thai finance PDF has direct Unicode support with safe network fallback',()=>{const s=fs.readFileSync(path.join(root,'supabase/functions/finance-report/index.ts'),'utf8');assert.match(s,/@pdf-lib\/fontkit/);assert.match(s,/NotoSansThai/);assert.match(s,/KOMBAX_THAI_FONT_URL/);assert.match(s,/documentLocale:'th'/);assert.match(s,/fontMode:'noto_sans_thai'/)});
ok('user-authored content boundaries remain protected from runtime translation',()=>{const s=fs.readFileSync(path.join(root,'web/js/i18n/legacy-runtime.js'),'utf8');for(const token of ['data-user-content','kx-social-post-text','kx-comment p','kx-seller-response','kx-public-event-copy'])assert.match(s,new RegExp(token.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')))});

const out=path.join(root,'docs/i18n/activation/KOMBAX_I18N_ALL8_ACTIVATION_GATE.json');fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log(`\nALL-8 ACTIVATION GATE: PASS · ${masterKeys.length} direct catalog keys × 8 · 2580 legacy phrases × 6 · 133 legal strings × 7 non-ES locales`);
