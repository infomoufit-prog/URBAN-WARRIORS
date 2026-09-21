import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { localizeSystemText } from '../web/js/i18n/legacy-runtime.js';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const args=process.argv.slice(2);
const strict=args.includes('--strict');
const auditAll=args.includes('--all');
const targetNames=new Set(args.filter(x=>!x.startsWith('--')));
const defaultTargets=['web/js/modules/showcase.js','web/js/modules/kombax-events.js','web/js/modules/kombax-social.js','web/js/modules/platform-admin.js','web/js/modules/finance.js','web/js/modules/finance-premium.js','web/js/app.js'];
function walkJs(dir){const out=[];for(const e of fs.readdirSync(path.join(root,dir),{withFileTypes:true})){const rel=path.posix.join(dir,e.name);if(e.isDirectory())out.push(...walkJs(rel));else if(e.isFile()&&e.name.endsWith('.js'))out.push(rel);}return out;}
const allTargets=auditAll?walkJs('web/js').filter(f=>!f.startsWith('web/js/i18n/')&&!f.includes('/vendor/')):[];
const targets=targetNames.size?[...targetNames]:(auditAll?allTargets:defaultTargets);
const fixtureOnlyFiles=new Set(['web/js/core/demo-directory.js','web/js/core/demo-showcase.js']);
const spanish=/[áéíóúüñ¿¡ÁÉÍÓÚÜÑ]|\b(?:Guardar|Cancelar|Cerrar|Buscar|Publicar|Compartir|Comentarios?|Mensajes?|Perfiles?|Eventos?|Entradas?|Comprar|Vendedor|Productos?|Pedidos?|Pendiente|Enviar|Eliminar|Editar|Cargando|Selecciona|Añadir|Agregar|Solicitar|Aceptar|Rechazar|Gestionar|Historial|Ayuda|Soporte|Descargar|Abrir|Volver|Continuar|Privacidad|Álbum|Información|Configuración|Estado|Públic[oa]|Interesad[oa]|Disponible|Activar|Desactivar|Crear|Nuevo|Nueva|Denunciar|Bloquear|Imprimir|Organizador|Ubicación|Compra|Menores?|Tutor|Revisión|Verificación|Cuenta|Clubes?|Federación|Marca|Competidor|Profesional|Cuotas|Ingresos|Gastos|Deuda|Recibo|Alumno|Miembro|Entrenamiento|Competición|Conexión|Solicitud|Nombre|Descripción|Categoría|País|Fecha|Documento|Pago|Combate|Peleador|Cartel|Venta|Acceso)\b/i;
const likelyTechnical=/^(?:club|evento|estado|perfil|pago|venta|marca|profesional|competidor|alumno|organizador|en|de|nombre|mensaje|fecha|descripcion|description|status|state)$/i;
const userFixture=/\b(?:Malik Benítez|Emma León|Leo Martín|Hugo Ríos|Adrián Serrano|Urban Warriors|Salvatierra|Moreno|León vs Rivas)\b/;
const demoFixtureExact=new Set([
  'Cartel oficial · Noche de Impacto','Entradas, recinto y horarios','Álbum oficial · momentos del evento','Cartel oficial · Seminario Pro de Muay Thai','Seminario · trabajo técnico de clinch','Seminario · técnica de rodilla y control','Hero oficial · Menores, juveniles y adultos','Combate estelar · Jiu-Jitsu de alto nivel','Talento joven · categorías menores y juveniles','Álbum oficial · comunidad sobre el tatami','Acción · agarres de pie','Acción · trabajo de guardia','Acción · control y transición','Acción · combate en tatami central','Acción · disputa de agarres','Acción · ataque desde guardia','Acción · intensidad competitiva','Acción · control de distancia'
]);
const codeFragment=/(?:\$\{\[|\.includes\(context\.|=>|===|!==|\?\.|&&|\|\||\.dataset\b|filters\.|entity_type|entity_id|stateTarget|\breturn\b|\bthrow Error\b|\bexport\b|\bfunction\b|\bconst\b|\blet\b|\bif\s*\(|\btry\s*\{|\bcatch\s*\(|\$\{badge|openShowcaseCommercialPlans|pageHeader\(|setMainHtml\(|humanError\()/;
const technicalKey=/^[a-z][a-z0-9_-]*(?:\.[a-z0-9_-]+){1,}$/i;
function shouldSkipAudit(value){return likelyTechnical.test(value)||userFixture.test(value)||demoFixtureExact.has(value)||codeFragment.test(value)||technicalKey.test(value)||/^[^\s]+@kombax\.es$/i.test(value)||/\.(?:nombre|fecha)\b/.test(value)||/^String\(/.test(value)||/^\.[a-z0-9_-]+[,[]/i.test(value)||/\[aria-label=/.test(value);}
function probeValue(value){return String(value).replace(/^(?:\{VAR\}\)\}\s*)+/,'').replace(/\{VAR\}/g,'2');}
function extract(file){
 const txt=fs.readFileSync(path.join(root,file),'utf8');const out=[];
 const quote=/(['"])((?:\\.|(?!\1)[\s\S])*?)\1/g;let m;
 while((m=quote.exec(txt))){const s=m[2].replace(/\\n/g,' ').replace(/\\'/g,"'").replace(/\\"/g,'"').trim();if(s.length>=2&&s.length<=320&&!s.includes('<')&&!s.includes('>')&&!s.includes('${')&&spanish.test(s))out.push(s);}
 const htmlText=/>\s*([^<>`]{2,260}?)\s*</g;while((m=htmlText.exec(txt))){const s=m[1].replace(/\$\{[^}]+\}/g,'{VAR}').replace(/\s+/g,' ').trim();if(s&&spanish.test(s))out.push(s);}
 return [...new Set(out)];
}
let total=0,covered=0,skipped=0;const files={};const unresolved=[];
for(const file of targets){const vals=extract(file);let ft=0,fc=0,fs=0;for(const value of vals){if(fixtureOnlyFiles.has(file)||shouldSkipAudit(value)){skipped++;fs++;continue;}total++;ft++;const probe=probeValue(value);const translated=localizeSystemText(probe,'en');if(translated!==probe){covered++;fc++;}else unresolved.push({file,value});}files[file]={total:ft,covered:fc,skipped:fs,coverage:ft?Math.round(fc/ft*10000)/100:100};}
const report={generated_at:new Date().toISOString(),targets,phrases:total,covered,unresolved:total-covered,coverage:total?Math.round(covered/total*10000)/100:100,skipped,files,unresolved_samples:unresolved};
fs.writeFileSync(path.join(root,'docs/i18n/remediation/KOMBAX_I18N_RUNTIME_COPY_AUDIT_RB02.json'),JSON.stringify(report,null,2)+'\n');
console.log(`runtime copy audit: ${covered}/${total} (${report.coverage}%) covered · ${total-covered} unresolved · ${skipped} technical/user fixtures skipped`);
for(const [f,v] of Object.entries(files))console.log(`${f}: ${v.covered}/${v.total} (${v.coverage}%) · skipped ${v.skipped}`);
if(strict&&unresolved.length)process.exit(1);
