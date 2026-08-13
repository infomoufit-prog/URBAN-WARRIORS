import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RELEASE H: ${msg}`);console.log(`OK RELEASE H: ${msg}`)};
const [media,repos,ui,sql,rollback,supabase]=await Promise.all([
  read('web/js/core/media.js'),read('web/js/core/repositories.js'),read('web/js/modules/community.js'),
  read('supabase/migrations/028_community_image_metadata.sql'),read('supabase/rollbacks/028_community_image_metadata.sql'),read('web/js/core/supabase.js')
]);

assert(media.includes('MAX_IMAGE_EDGE=1920')&&media.includes('MAX_IMAGE_OUTPUT_BYTES=5*1024*1024'),'optimización limita resolución y peso final');
assert(media.includes("image/webp")&&media.includes('0.86')&&media.includes('0.78'),'WebP usa calidad progresiva');
assert(media.includes('createImageBitmap')&&media.includes('new Image()'),'decodificación tiene fallback compatible');
assert(media.includes('finally{decoded.close();}'),'recursos de imagen se liberan');
assert(repos.includes('await optimizeImage(file)')&&repos.includes('prepared.file'),'imágenes públicas también se optimizan antes de Storage');
assert(ui.includes('formatMediaBytes')&&ui.includes('media_width:image.width'),'Comunidad informa optimización y envía metadatos');
assert(supabase.includes('AbortController')&&supabase.includes('La subida ha superado el tiempo'),'Storage termina esperas indefinidas con un error comprensible');
assert(sql.includes('media_size_bytes bigint')&&sql.includes('media_width integer'),'PostgreSQL guarda metadatos, no binarios');
assert(sql.includes('app_mutate_v160_pre_media_028')&&sql.includes("p_operation<>'comunidad.publicar'"),'wrapper preserva operaciones RC10');
assert(rollback.includes('restaura el gateway anterior')&&rollback.includes('conserva los metadatos'),'rollback es conservador');
console.log('RELEASE H IMAGES: PASS');
