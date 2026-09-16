import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const files={
  social:['web/js/modules/kombax-social.js','web/js/modules/social-network.js','web/js/modules/social-post-management.js'],
  showcase:['web/js/modules/showcase.js'],
  events_ticketing:['web/js/modules/events.js','web/js/modules/kombax-events.js','web/js/modules/event-connections.js'],
  assist_migrations:['web/js/modules/customer-operations.js','web/js/ui/conversation-ui.js'],
  legal:['web/js/modules/help-legal.js']
};
const spanish=/[áéíóúñÁÉÍÓÚÑ]|\b(?:Guardar|Cancelar|Cerrar|Buscar|Publicar|Compartir|Comentarios?|Mensajes?|Perfil(?:es)?|Evento(?:s)?|Entrada(?:s)?|Comprar|Vendedor|Producto(?:s)?|Pedido(?:s)?|Pendiente|Vencido|Cobrado|Enviar|Eliminar|Editar|Cargando|Todavía|Selecciona|Añadir|Agregar|Solicitar|Aceptar|Rechazar|Gestionar|Historial|Ayuda|Soporte|Descargar|Abrir|Volver|Continuar|Privacidad|Álbum|Información|Configuración|Estado|Públic[oa]|Interesad[oa]|Disponible|Activar|Desactivar|Crear|Nuevo|Nueva|Denunciar|Bloquear|Imprimir|Organizador|Ubicación|Compra|Cancelaciones|Menores?|Tutor|Revisión|Verificación)\b/i;
const report={generated_at:new Date().toISOString(),method:'Conservative source-line candidate scan. Counts are NOT verified visible-string counts and include some demo/user-content literals.',areas:{}};
for(const [area,rels] of Object.entries(files)){
  const candidates=[];
  for(const rel of rels){const lines=fs.readFileSync(path.join(root,rel),'utf8').split('\n');lines.forEach((line,i)=>{const s=line.trim();if(!s||s.startsWith('//')||s.startsWith('*'))return;if(!/[\"'`]/.test(line)||!spanish.test(line))return;candidates.push({file:rel,line:i+1,sample:s.slice(0,220)})})}
  report.areas[area]={candidate_lines:candidates.length,samples:candidates.slice(0,25)};
}
fs.writeFileSync(path.join(root,'docs/i18n/KOMBAX_I18N_B03_SCOPE_AUDIT.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(Object.fromEntries(Object.entries(report.areas).map(([k,v])=>[k,v.candidate_lines])),null,2));
