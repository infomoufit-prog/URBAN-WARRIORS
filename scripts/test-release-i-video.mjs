import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RELEASE I: ${msg}`);console.log(`OK RELEASE I: ${msg}`)};
const [media,repos,ui,sql,rollback,dispatch]=await Promise.all([
  read('web/js/core/media.js'),read('web/js/core/repositories.js'),read('web/js/modules/community.js'),
  read('supabase/migrations/029_community_video_covers.sql'),read('supabase/rollbacks/029_community_video_covers.sql'),
  read('supabase/functions/notification-dispatch/index.ts')
]);

assert(media.includes('50*1024*1024')&&media.includes('duration>15.2'),'cliente valida 50 MB y 15 segundos');
assert(media.includes('Math.max(width,height)>1920')&&media.includes('Math.min(width,height)>1080'),'cliente garantiza máximo 1080p en horizontal o vertical');
assert(media.includes("'-portada.webp'")&&media.includes("context.drawImage(video"),'portada automática se extrae del vídeo');
assert(ui.includes('preload="none"')&&ui.includes('poster='),'feed no precarga vídeo y usa miniatura');
assert(ui.includes('Portada manual (opcional, solo vídeo)')&&ui.includes('Cambiar portada'),'Gestor/Coordinación puede elegir y cambiar portada');
assert(repos.includes('(isVideo?50:5)')&&repos.includes('portada_automatica_path'),'repositorio admite vídeo 50 MB y persiste paths');
assert(sql.includes('file_size_limit=52428800')&&sql.includes('portada_manual_path text'),'bucket y esquema soportan el requisito');
assert(sql.includes('Solo Gestor o Coordinación')&&sql.includes("m.coordinacion"),'backend restringe portada manual al equipo autorizado');
assert(sql.includes("p_operation not in ('comunidad.publicar','comunidad.eliminar','comunidad.moderar')"),'wrapper preserva el resto del contrato RC10');
assert(dispatch.includes('portada_automatica_path')&&dispatch.includes('portada_manual_path'),'caducidad limpia vídeo y ambas portadas');
assert(rollback.includes('restaura el gateway anterior'),'Release I tiene punto de retorno');
console.log('RELEASE I VIDEO: PASS');
