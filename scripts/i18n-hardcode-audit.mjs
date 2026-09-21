import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const sourceRoot=path.join(root,'web');
const targetFiles=new Set([
  'web/js/modules/gateway.js',
  'web/js/public-product-overview.js',
  'web/js/ui/components.js',
  'web/js/modules/finance.js',
  'web/js/modules/finance-premium.js',
  'web/js/modules/platform-admin.js',
  'web/js/modules/public-profile.js',
  'web/js/modules/sports-profile.js',
  'web/js/modules/kombax-social.js',
  'web/js/modules/social-network.js'
]);
const extensions=new Set(['.js','.html','.webmanifest']);
const skipDirs=new Set(['i18n','assets','vendor']);
const spanish=/[áéíóúñÁÉÍÓÚÑ¿¡]|\b(?:Guardar|Cancelar|Cerrar|Buscar|Publicar|Compartir|Comentarios?|Mensajes?|Perfil(?:es)?|Evento(?:s)?|Entrada(?:s)?|Comprar|Vendedor|Producto(?:s)?|Pedido(?:s)?|Pendiente|Vencido|Cobrado|Enviar|Eliminar|Editar|Cargando|Todavía|Selecciona|Añadir|Agregar|Solicitar|Aceptar|Rechazar|Gestionar|Historial|Ayuda|Soporte|Descargar|Abrir|Volver|Continuar|Privacidad|Álbum|Información|Configuración|Estado|Públic[oa]|Interesad[oa]|Disponible|Activar|Desactivar|Crear|Nuevo|Nueva|Denunciar|Bloquear|Imprimir|Organizador|Ubicación|Compra|Menores?|Tutor|Revisión|Verificación|Cuenta|Clubes|Federación|Marca|Competidor|Profesional|Cuotas|Ingresos|Gastos|Deuda|Recibo|Alumno|Miembro|Entrenamiento|Competición|Conexión|Solicitud)\b/i;
const technicalLine=/\b(?:console\.|throw new Error\(|estado===|status===|includes\(|case\s+['"]|id:|code:|slug:|enum|fixture|legacy|compatibilidad|taxonomía|contrato legacy)\b/i;
const userContentLine=/\b(?:texto|descripcion|description|comentario|comment|mensaje|message|nombre_publico|nombre_evento|evento_nombre|producto_nombre|title_from_user|user_content)\b/i;

const files=[];
function walk(dir){
  for(const ent of fs.readdirSync(dir,{withFileTypes:true})){
    if(ent.isDirectory()&&skipDirs.has(ent.name))continue;
    const abs=path.join(dir,ent.name);
    if(ent.isDirectory())walk(abs);
    else if(ent.isFile()&&extensions.has(path.extname(ent.name)))files.push(abs);
  }
}
walk(sourceRoot);

const candidates=[];
for(const abs of files){
  const rel=path.relative(root,abs).replaceAll('\\','/');
  const lines=fs.readFileSync(abs,'utf8').split('\n');
  lines.forEach((line,index)=>{
    const s=line.trim();
    if(!s||s.startsWith('//')||s.startsWith('*')||s.startsWith('/*'))return;
    if(!spanish.test(line))return;
    let classification='SYSTEM_UI_CANDIDATE';
    if(technicalLine.test(line))classification='TECHNICAL_OR_DIAGNOSTIC';
    if(userContentLine.test(line)&&!/label:|title:|subtitle:|placeholder:|help:|aria-label|<button|<strong|<span|<p>|<h[1-6]/i.test(line))classification='USER_CONTENT_BOUNDARY';
    candidates.push({file:rel,line:index+1,classification,target_block_1:targetFiles.has(rel),sample:s.slice(0,320)});
  });
}
const target=candidates.filter(x=>x.target_block_1&&x.classification==='SYSTEM_UI_CANDIDATE');
const allUi=candidates.filter(x=>x.classification==='SYSTEM_UI_CANDIDATE');
const byFile={};
for(const row of candidates){byFile[row.file]??={system_ui:0,technical:0,user_content:0,target_block_1:row.target_block_1};if(row.classification==='SYSTEM_UI_CANDIDATE')byFile[row.file].system_ui++;else if(row.classification==='TECHNICAL_OR_DIAGNOSTIC')byFile[row.file].technical++;else byFile[row.file].user_content++;}
const report={
  generated_at:new Date().toISOString(),
  policy:'All KOMBAX-generated visible copy must use i18n. User-created content remains original and may be translated on demand in a later feature.',
  files_scanned:files.length,
  system_ui_candidates:allUi.length,
  target_block_1_system_ui_candidates:target.length,
  target_files:[...targetFiles],
  by_file:byFile,
  candidates
};
fs.mkdirSync(path.join(root,'docs/i18n'),{recursive:true});
fs.writeFileSync(path.join(root,'docs/i18n/KOMBAX_I18N_HARDCODE_AUDIT.json'),JSON.stringify(report,null,2)+'\n');
console.log(`i18n hardcode audit: ${files.length} files · ${allUi.length} SYSTEM_UI candidates · ${target.length} in remediation block 1 targets`);
if(process.argv.includes('--strict-targets')&&target.length){
  console.error(`FAIL: ${target.length} high-confidence UI candidates remain in remediation block 1 target files.`);
  for(const row of target.slice(0,80))console.error(`${row.file}:${row.line} ${row.sample}`);
  process.exit(1);
}
