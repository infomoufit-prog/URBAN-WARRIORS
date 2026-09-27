import fs from 'node:fs';
import path from 'node:path';
import { localizeSystemText } from '../web/js/i18n/legacy-runtime.js';
import { R78_SYSTEM_SOURCE } from '../web/js/i18n/r78-system-source.js';
import { R79_SYSTEM_SOURCE } from '../web/js/i18n/r79-system-source.js';
const root=process.cwd();
const locales=['en','fr','pt','it','de','th','fil'];
const r78=new Set(Object.values(R78_SYSTEM_SOURCE).map(v=>String(v).replace(/\u00a0/g,' ').replace(/\s+/g,' ').trim()));
const r79=new Set(Object.values(R79_SYSTEM_SOURCE).map(v=>String(v).replace(/\u00a0/g,' ').replace(/\s+/g,' ').trim()));
const spanish=/[áéíóúüñ¿¡ÁÉÍÓÚÜÑ]|\b(?:Guardar|Cancelar|Cerrar|Buscar|Publicar|Compartir|Comentarios?|Mensajes?|Perfiles?|Eventos?|Entradas?|Comprar|Vendedor|Productos?|Pedidos?|Pendiente|Enviar|Eliminar|Editar|Cargando|Selecciona|Añadir|Agregar|Solicitar|Aceptar|Rechazar|Gestionar|Historial|Ayuda|Soporte|Descargar|Abrir|Volver|Continuar|Privacidad|Álbum|Información|Configuración|Estado|Públic[oa]|Interesad[oa]|Disponible|Activar|Desactivar|Crear|Nuevo|Nueva|Denunciar|Bloquear|Imprimir|Organizador|Ubicación|Compra|Menores?|Tutor|Revisión|Verificación|Cuenta|Clubes?|Federación|Marca|Competidor|Profesional|Cuotas|Ingresos|Gastos|Deuda|Recibo|Alumno|Miembro|Entrenamiento|Competición|Conexión|Solicitud|Nombre|Descripción|Categoría|País|Fecha|Documento|Pago|Combate|Peleador|Cartel|Venta|Acceso|Importar|Migraciones?|Finanzas?|Tesorería|Administrador|Moderación|Permisos?|Roles?|Usuarios?|Factura|Cobro|Reembolso)\b/i;
const likelyTechnical=/^(?:club|evento|estado|perfil|pago|venta|marca|profesional|competidor|alumno|organizador|en|de|nombre|mensaje|fecha|descripcion|description|status|state|tipo|rol|role|error|success|pending)$/i;
const userFixture=/\b(?:Malik Benítez|Emma León|Leo Martín|Hugo Ríos|Adrián Serrano|Urban Warriors|Salvatierra|Moreno|León vs Rivas)\b/;
const codeFragment=/(?:\.includes\(|=>|===|!==|\?\.|&&|\|\||\.dataset\b|filters\.|entity_type|entity_id|stateTarget|\breturn\b|\bthrow Error\b|\bexport\b|\bfunction\b|\bconst\b|\blet\b|\bif\s*\(|\btry\s*\{|\bcatch\s*\(|open[A-Z]|render[A-Z]|setMainHtml\(|humanError\(|\.map\(|\.filter\(|\.reduce\(|await\s|supabase\.|rpc\(|from\(|select\(|insert\(|update\(|delete\(|querySelector|addEventListener|classList|innerHTML|textContent|dataset\.)/;
const technicalKey=/^[a-z][a-z0-9_-]*(?:\.[a-z0-9_-]+){1,}$/i;
const urlish=/^(?:https?:|mailto:|tel:|\/|\.\/|\.\.\/|[.#][a-z0-9_-]+)/i;
const classish=/^[a-z0-9_-]+(?:\s+[a-z0-9_-]+){0,4}$/i;
const demoFixtureExact=new Set(['Cartel oficial · Noche de Impacto','Entradas, recinto y horarios','Álbum oficial · momentos del evento','Confidentialité']);
function norm(v){return String(v??'').replace(/\u00a0/g,' ').replace(/\s+/g,' ').trim();}
function probe(v){return String(v).replace(/^(?:\{VAR\}\)\}\s*)+/,'').replace(/\{VAR\}/g,'2');}
function skip(v){return v.startsWith("'+icon(")||!v||v.length<2||v.length>1200||likelyTechnical.test(v)||userFixture.test(v)||demoFixtureExact.has(v)||codeFragment.test(v)||technicalKey.test(v)||urlish.test(v)||/^\'+icon\(/.test(v)||/^kx-[a-z0-9-]+$/i.test(v)||/^id="kx-[^"]+"$/i.test(v)||/^[^\s]+@[^\s]+$/.test(v)||/^String\(/.test(v)||/^\$?\{/.test(v)||(/^\w+(?:\s+\w+){0,2}$/.test(v)&&classish.test(v)&&!spanish.test(v));}
function walk(dir){const out=[];for(const e of fs.readdirSync(dir,{withFileTypes:true})){const abs=path.join(dir,e.name);if(e.isDirectory()){if(['i18n','vendor','node_modules'].includes(e.name))continue;out.push(...walk(abs));}else if(e.isFile()&&['.js','.html'].includes(path.extname(e.name)))out.push(abs);}return out;}
function extract(abs){const txt=fs.readFileSync(abs,'utf8');const out=[];let m;const quote=/(['"])((?:\\.|(?!\1)[\s\S])*?)\1/g;while((m=quote.exec(txt))){let s=m[2].replace(/\\n/g,' ').replace(/\\'/g,"'").replace(/\\"/g,'"');s=norm(s);if(s.includes('${')||s.includes('<')||s.includes('>'))continue;if(spanish.test(s)&&!skip(s))out.push(s);}const htmlText=/>\s*([^<>`]{2,700}?)\s*</g;while((m=htmlText.exec(txt))){const s=norm(m[1].replace(/\$\{[^}]+\}/g,'{VAR}'));if(spanish.test(s)&&!skip(s))out.push(s);}return [...new Set(out)];}
const unresolved=[];let candidates=0,coveredR78=0,coveredR79=0,coveredLegacy=0;
for(const abs of walk(path.join(root,'web'))){const rel=path.relative(root,abs).replaceAll('\\','/');for(const value of extract(abs)){candidates++;const n=norm(value);if(r79.has(n)){coveredR79++;continue;}if(r78.has(n)){coveredR78++;continue;}const p=probe(n);const missing=[];for(const loc of locales){if(localizeSystemText(p,loc)===p)missing.push(loc);}if(!missing.length){coveredLegacy++;continue;}unresolved.push({file:rel,value:n,missing});}}
const byFile={};for(const row of unresolved){byFile[row.file]=(byFile[row.file]||0)+1;}
const report={generated_at:new Date().toISOString(),candidates,covered_r79:coveredR79,covered_r78:coveredR78,covered_legacy_all7:coveredLegacy,unresolved:unresolved.length,by_file:Object.fromEntries(Object.entries(byFile).sort((a,b)=>b[1]-a[1])),unresolved_rows:unresolved};
fs.mkdirSync(path.join(root,'docs/i18n'),{recursive:true});fs.writeFileSync(path.join(root,'docs/i18n/R79_FULL_PRODUCT_AUDIT.json'),JSON.stringify(report,null,2)+'\n');
console.log(`R79 full product audit: ${candidates} candidates · ${coveredR79} R79 · ${coveredR78} R78 · ${coveredLegacy} legacy 7/7 · ${unresolved.length} unresolved`);for(const [file,count] of Object.entries(report.by_file).slice(0,30))console.log(`${count}\t${file}`);if(process.argv.includes('--strict')&&unresolved.length)process.exit(1);
