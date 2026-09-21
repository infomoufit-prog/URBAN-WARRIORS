import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const locales=['es','en','fr','pt','it','de','th','fil'];
const enabledLocales=new Set(locales);
const resources={};
for(const locale of locales) resources[locale]=(await import(pathToFileURL(path.join(root,`web/js/i18n/locales/${locale}/index.js`)))).default;
const flatten=(o,p='',out={})=>{for(const [k,v] of Object.entries(o||{})){const q=p?`${p}.${k}`:k;if(v&&typeof v==='object')flatten(v,q,out);else out[q]=v}return out};
const placeholders=v=>[...String(v||'').matchAll(/\{\{\s*([\w.-]+)\s*\}\}/g)].map(m=>m[1]).sort();
const master=flatten(resources.es); const masterKeys=Object.keys(master).sort();
const report={generated_at:new Date().toISOString(),master_locale:'es',master_catalog_keys:masterKeys.length,locales:{},errors:[],warnings:[]};
for(const locale of locales){
  const flat=flatten(resources[locale]); const keys=Object.keys(flat).sort();
  const missing=masterKeys.filter(k=>!(k in flat)); const extra=keys.filter(k=>!(k in master));
  const empty=masterKeys.filter(k=>(k in flat)&&(typeof flat[k]!=='string'||!flat[k].trim()));
  const placeholderMismatch=masterKeys.filter(k=>JSON.stringify(placeholders(flat[k]))!==JSON.stringify(placeholders(master[k])));
  const technicalLeaks=masterKeys.filter(k=>/^(?:undefined|null|missing_translation|translation_missing|\{\{key\}\})$/i.test(String(flat[k]||'').trim()));
  report.locales[locale]={translated_catalog_keys:masterKeys.length-missing.length-empty.length,catalog_coverage_percent:Number((((masterKeys.length-missing.length-empty.length)/masterKeys.length)*100).toFixed(2)),missing_keys:missing,extra_keys:extra,empty_keys:empty,placeholder_mismatches:placeholderMismatch,technical_leaks:technicalLeaks};
  const issues={locale,missing,extra,empty,placeholderMismatch,technicalLeaks};
  if(enabledLocales.has(locale)){if(missing.length||extra.length||empty.length||placeholderMismatch.length||technicalLeaks.length) report.errors.push(issues);}
  else if(missing.length||extra.length||empty.length||placeholderMismatch.length||technicalLeaks.length) report.warnings.push({...issues,note:'Supported but disabled locale may fall back to EN/ES until its activation gate.'});
}
// Scan active t('key') references in web JS.
const refs=new Set();
const scan=(dir)=>{for(const ent of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,ent.name);if(ent.isDirectory())scan(p);else if(ent.isFile()&&p.endsWith('.js')){const src=fs.readFileSync(p,'utf8');for(const m of src.matchAll(/\bt\(\s*['"]([^'"]+)['"]/g))refs.add(m[1]);}}};
scan(path.join(root,'web/js'));
report.active_translation_references=refs.size;
report.missing_active_keys_by_locale={};
for(const locale of locales){const flat=flatten(resources[locale]);report.missing_active_keys_by_locale[locale]=[...refs].filter(k=>!(k in flat)||!String(flat[k]||'').trim()).sort();if(report.missing_active_keys_by_locale[locale].length){const issue={locale,missing_active_keys:report.missing_active_keys_by_locale[locale]};if(enabledLocales.has(locale))report.errors.push(issue);else report.warnings.push({...issue,note:'Disabled locale uses EN/ES fallback for newly migrated UI.'});}}
// Regional hardcodes are forbidden outside the single canonical localeTag map.
const regional=[];
const scanRegion=(dir)=>{for(const ent of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,ent.name);if(ent.isDirectory())scanRegion(p);else if(ent.isFile()&&p.endsWith('.js')){const rel=path.relative(root,p).replaceAll('\\','/');if(rel==='web/js/i18n/formatters.js')continue;const src=fs.readFileSync(p,'utf8');if(/["']es-ES["']|["']es_ES["']/.test(src))regional.push(rel);}}};
scanRegion(path.join(root,'web/js')); report.remaining_ui_es_es_hardcodes=regional; if(regional.length)report.errors.push({regional_hardcodes:regional});
// Strong locale-specific sanity checks.
if(!/[\u0E00-\u0E7F]/.test(resources.th.common.actions.save))report.errors.push({locale:'th',unicode:'Thai catalog lacks Thai script in critical UI'});
if(resources.en.auth.login.accessAccount!=='Access your {{club}} account.')report.errors.push({locale:'en',context:'English interpolation sanity check failed'});
for(const [locale,label] of [['fr','Enregistrer'],['pt','Guardar'],['it','Salva'],['de','Speichern'],['fil','I-save']]) if(resources[locale].common.actions.save!==label)report.errors.push({locale,context:'critical action translation sanity check failed'});
const outPath=path.join(root,'docs/i18n/KOMBAX_I18N_VALIDATION.json');fs.mkdirSync(path.dirname(outPath),{recursive:true});fs.writeFileSync(outPath,JSON.stringify(report,null,2)+'\n');
console.log(`i18n validation: ${masterKeys.length} master keys · ${refs.size} active refs · ${locales.length} locales`);
for(const l of locales)console.log(`${l}: ${report.locales[l].catalog_coverage_percent}% (${report.locales[l].translated_catalog_keys}/${masterKeys.length})`);
if(report.errors.length){console.error(JSON.stringify(report.errors,null,2));process.exit(1)}
console.log(`PASS: all 8 enabled locales are strict; ${report.warnings.length} warning group(s). No UI es-ES hardcodes.`);
