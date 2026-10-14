import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {R270_PILOT_COPY,localizeR270PilotText} from '../web/js/i18n/r270-pilot-copy.js';
import {localizeSystemText} from '../web/js/i18n/legacy-runtime.js';
import {has} from '../web/js/core/permissions.js';
let checks=0;const ok=(value,name)=>{assert.ok(value,name);checks++;};
for(const [source,target] of Object.entries(R270_PILOT_COPY)){
 ok(typeof target==='string'&&target.trim()&&source!==target,'real English translation: '+source);
 ok((source.match(/\{VAR\}/g)||[]).length===(target.match(/\{VAR\}/g)||[]).length,'dynamic values retained');
 ok(localizeR270PilotText(source,'es')==='','Spanish remains unchanged');
 for(const locale of ['en','fr','pt','it','de','th','fil'])ok(localizeSystemText(source,locale)===target,'documented pilot fallback '+locale);
}
ok(localizeSystemText('7 licencias activas · 4 históricas','en')==='7 active licenses · 4 historical','actual license counters retained');
ok(localizeSystemText('MOUFIT · 3 entrada(s)','en')==='MOUFIT · 3 ticket(s)','actual brand and ticket quantity retained');
ok(localizeSystemText('Próximo vencimiento: 2026-12-31','en')==='Next expiry: 2026-12-31','actual date retained');
ok(localizeSystemText('Private customer message xyz','en')==='Private customer message xyz','unknown user text is not rewritten');
const app=readFileSync('web/js/app.js','utf8'),line=app.split('\n').find(x=>x.startsWith('const canManagePrivateEvents='));
ok(Boolean(line),'canonical permission helper exists');
const context={state:{session:null},has};vm.createContext(context);vm.runInContext(line+';globalThis.canManage=canManagePrivateEvents;',context);
for(const role of ['direccion','coordinacion','secretaria','economia','monitor','familia','alumno']){
 const session={club_id:'qa',rol:role,roles:['direccion',role]};
 ok(context.canManage(session)===has({roles:[role]},'eventManage'),'navigation respects selected role '+role);
}
ok(!context.canManage({rol:'direccion',roles:['direccion']}),'no club context cannot manage club events');
const showcase=readFileSync('web/js/modules/showcase.js','utf8'),repos=readFileSync('web/js/core/repositories.js','utf8');
ok(showcase.includes('conservará todos sus registros y mensajes'),'retirement notice preserves history');
ok(repos.includes("if(out?.deleted===true)await removeOwnedShowcaseImages"),'retirement does not delete stored media as permanent removal');
console.log(`PASS ${checks} R270 stabilization checks; permission and locale logic executed, no production writes`);
