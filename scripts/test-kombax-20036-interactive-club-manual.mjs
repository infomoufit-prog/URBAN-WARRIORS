import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const exists=p=>fs.existsSync(path.join(root,p));
const help=read('web/js/modules/help-legal.js');
const admin=read('web/js/modules/admin.js');
const app=read('web/js/app.js');
const css=read('web/css/app.css');
const cfg=read('web/config.js');
const gradle=read('android/app/build.gradle');
const topicCount=(help.match(/id:'[^']+',group:/g)||[]).length;
const legacyRefs=['manual-usuario','manual-equipo','Manual_Equipo_Urban_Warriors','Manual_Usuario_Urban_Warriors','Cartel_Guia_Rapida_Usuarios'];
const checks=[
 ['22+ audited manual topics',topicCount>=22],
 ['interactive search and group filter',help.includes('manual-search')&&help.includes('manual-group-filter')&&help.includes('bindInteractiveManual')],
 ['how-it-works modal',help.includes('Cómo funciona')&&help.includes('Paso a paso')&&help.includes('Reglas importantes')],
 ['deep links to real functions',help.includes('data-manual-route')&&help.includes('location.hash=`#${b.dataset.manualRoute}`')],
 ['roles and access explained',help.includes('Quién puede usarlo')&&help.includes('canOpen(item)')],
 ['social documented',help.includes('Combat Social / KOMBAX Social')&&help.includes('corazón')&&help.includes('comentarios')],
 ['finance groups sessions documented',help.includes('Finanzas, cuotas y cobros')&&help.includes("title:'Grupos'")&&help.includes('Sesiones y recurrencia')],
 ['showcase non-ecommerce documented',help.includes('Showcase no es ecommerce')],
 ['club access codes documented',help.includes('Códigos del club e invitaciones')&&help.includes('4 o 5 dígitos')],
 ['generic poster packaged',exists('web/assets/docs/Cartel_Descarga_KOMBAX_Club.png')&&help.includes('Cartel_Descarga_KOMBAX_Club.png')&&admin.includes('Cartel_Descarga_KOMBAX_Club.png')],
 ['legacy visual manuals removed',legacyRefs.every(x=>!help.includes(x)&&!admin.includes(x))&&!exists('web/assets/docs/manual-usuario')&&!exists('web/assets/docs/manual-equipo')],
 ['manual has no hardcoded Urban Warriors tenant',!help.includes('Urban Warriors')],
 ['install copy generic KOMBAX',admin.includes("pageHeader('Instalar KOMBAX'")&&admin.includes('portal de tu club')],
 ['manual premium responsive CSS',css.includes('.kx-manual-shell')&&css.includes('.kx-manual-grid')&&css.includes('@media(max-width:680px)')],
 ['route label updated',app.includes("help:'Manual interactivo'")],
 ['build 20036+',Number((cfg.match(/build:\s*(\d+)/)||[])[1]||0)>=20036&&Number((gradle.match(/versionCode\s+(\d+)/)||[])[1]||0)>=20036]
];
const failed=checks.filter(([,ok])=>!ok);
for(const [name,ok] of checks)console.log(`${ok?'PASS':'FAIL'} ${name}`);
if(failed.length)process.exit(1);
console.log(`KOMBAX 20036 INTERACTIVE CLUB MANUAL: PASS · ${topicCount} topics`);
