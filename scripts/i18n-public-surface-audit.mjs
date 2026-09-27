import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {localizeSystemText} from '../web/js/i18n/legacy-runtime.js';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const files=['web/privacy.html','web/terms.html','web/child-safety.html','web/delete-account.html'];
const spanish=/[áéíóúüñ¿¡]|(?:Condiciones|Privacidad|Eliminar|Seguridad|Cuenta|Datos|Derechos|Responsable|Contacto|Menores|Tratamiento|Solicitar|Acceso|Conservar|Información|Uso|Servicio|Plataforma|Usuario|Correo|Borrar|Cerrar|Soporte|Legal|Protección)/i;
const unresolved=[];let audited=0;
for(const file of files){
  const html=fs.readFileSync(path.join(root,file),'utf8');
  assert.match(html,/public-page\.js\?v=20\d{3}-i18n-rb02/,`${file} must load current public-page i18n`);
  const values=[];let m;const re=/>\s*([^<>]{2,700}?)\s*</g;
  while((m=re.exec(html))){const v=m[1].replace(/&nbsp;/g,' ').replace(/&amp;/g,'&').replace(/\s+/g,' ').trim();if(v&&!v.includes('{{')&&!/^\W*$/.test(v))values.push(v);}
  for(const v of new Set(values)){if(!spanish.test(v))continue;if(/^[^\s]+@kombax\.es$/i.test(v))continue;audited++;if(localizeSystemText(v,'en')===v)unresolved.push({file,value:v});}
}
assert.equal(unresolved.length,0,`Untranslated public-page copy:\n${unresolved.map(x=>`${x.file}: ${x.value}`).join('\n')}`);
const report={generated_at:new Date().toISOString(),files,audited_spanish_system_strings:audited,unresolved:0,status:'PASS'};
fs.writeFileSync(path.join(root,'docs/i18n/remediation/KOMBAX_I18N_PUBLIC_SURFACES_AUDIT_RB02.json'),JSON.stringify(report,null,2)+'\n');
console.log(`Public surfaces audit: PASS · ${files.length} pages · ${audited} Spanish system strings localize to EN · 0 unresolved`);
