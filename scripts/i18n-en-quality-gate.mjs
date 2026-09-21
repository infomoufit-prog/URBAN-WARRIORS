import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { LEGACY_AUTO_EN_SOURCES } from '../web/js/i18n/legacy-auto-en-sources.js';
import { LEGACY_EN_RB02_EXACT } from '../web/js/i18n/legacy-copy-en-rb02-exact.js';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const rows=fs.readFileSync(path.join(root,'docs/i18n/remediation/RB02_EN_EXACT.tsv'),'utf8').split(/\r?\n/).filter(Boolean);
const exactEntries=new Map(rows.map((line,index)=>{
  const tab=line.indexOf('\t');
  assert.ok(tab>0,`RB02_EN_EXACT.tsv line ${index+1} must be TAB-separated`);
  return [line.slice(0,tab),line.slice(tab+1)];
}));
const source=[...LEGACY_AUTO_EN_SOURCES];
assert.equal(exactEntries.size,source.length,'Every audited legacy source must have one exact English translation');
for(const s of source){assert.ok(exactEntries.has(s),`Missing exact English: ${s}`);assert.equal(LEGACY_EN_RB02_EXACT[s],exactEntries.get(s),`Generated exact map drift: ${s}`);}

const vars=s=>[...String(s).matchAll(/\{VAR\}/g)].length;
for(const [s,t] of exactEntries){assert.ok(vars(t)<=vars(s),`{VAR} placeholder count increased: ${s}`);if(vars(s)>0)assert.ok(vars(t)>0,`All dynamic placeholders lost: ${s}`);assert.ok(String(t).trim(),`Empty English target: ${s}`);}

// Strong Spanish UI markers. Technical fragments and public email addresses are intentionally excluded.
const strong=/\b(?:Guardar|Cargando|Solicitud(?:es)?|Alumno(?:s)?|Federaci[oó]n|Publicaci[oó]n|Documentaci[oó]n|Cuotas?|Cobros?|Pendientes?|Privacidad|Configuraci[oó]n|Perfiles?|Eventos?|Combates?|Sesi[oó]n(?:es)?|Matr[ií]cula(?:s)?|Asistencia|Hist[oó]rico|Soporte|Gesti[oó]n|Autorizaci[oó]n|Seguimiento|Portada|Correo|Contrase[nñ]a|Acceso|Equipo|Grupo|Familia|Tutor|Licencia|Inscripci[oó]n|Cuenta|Notificaci[oó]n|Avisos?|Comunidad|Normas|Condiciones|Borrar|Abrir|Cerrar|Eliminar|Editar|Selecciona|A[nñ]adir|Denunciar|Bloquear|Entrenamiento|Competici[oó]n|Ubicaci[oó]n|Vendedor|Productos?|Pedidos?|Deuda|Recibo|Miembro|Estado|Descripci[oó]n|Categor[ií]a|Pa[ií]s|Peleador|Cartel|Venta)\b/i;
const technical=/(?:\.nombre\b|\.fecha\b|\$\{|\.includes\(|perfil_directo|federacion|competidor|profesional|espectador|@kombax\.es$)/i;
const residue=[];
for(const [s,t] of exactEntries){if(strong.test(t)&&!technical.test(t))residue.push({source:s,target:t});}
assert.equal(residue.length,0,`Strong Spanish residue in exact EN targets:\n${residue.slice(0,20).map(x=>`- ${x.target}`).join('\n')}`);

const report={generated_at:new Date().toISOString(),audited_sources:source.length,exact_translations:exactEntries.size,placeholder_drift:0,strong_spanish_residue:0,status:'PASS'};
fs.writeFileSync(path.join(root,'docs/i18n/remediation/KOMBAX_I18N_EN_QUALITY_GATE_RB02.json'),JSON.stringify(report,null,2)+'\n');
console.log(`English quality gate: PASS · ${source.length}/${source.length} exact audited phrases · 0 placeholder drift · 0 strong Spanish residue`);
