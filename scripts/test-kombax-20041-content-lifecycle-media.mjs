import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
const root=resolve(new URL('..',import.meta.url).pathname);
const read=p=>readFileSync(resolve(root,p),'utf8');
const must=(ok,msg)=>{if(!ok)throw new Error(`20041: ${msg}`)};
const migration='supabase/migrations/067_kombax_content_lifecycle_media_20041.sql';
must(existsSync(resolve(root,migration)),'falta migración 067');
const sql=read(migration),repos=read('web/js/core/repositories.js'),social=read('web/js/modules/kombax-social.js'),showcase=read('web/js/modules/showcase.js'),publicProfile=read('web/js/modules/public-profile.js'),clubProfile=read('web/js/modules/club-profile.js'),material=read('web/js/modules/comms-material.js'),appCss=read('web/css/app.css'),premium=read('web/css/kombax-premium.css'),config=read('web/config.js');

const configBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0);must(configBuild>=20041,'config es anterior a build 20041');
// Eliminación de publicaciones Social propias: física + dependencias cascade + multimedia huérfana controlada.
must(sql.includes('kombax.social.eliminar')&&sql.includes('delete from public.kombax_social_publicaciones'),'falta eliminación real de post Social');
must(/not v_media\.en_album/i.test(sql)&&/not exists\(select 1 from public\.kombax_social_publicaciones p where p\.social_media_id=v_media\.id\)/i.test(sql),'multimedia Social no protege álbum/reutilización');
must(repos.includes('deletePost:async')&&social.includes('data-social-delete'),'frontend no permite eliminar publicación Social');
must(!social.includes('data-social-withdraw'),'la UI propia todavía expone Retirar en lugar de Eliminar');

// Contactos: eliminación por participante, no borrado destructivo para la contraparte.
must(/eliminado_remitente_en timestamptz/i.test(sql)&&/eliminado_destinatario_en timestamptz/i.test(sql),'faltan tombstones por participante de Contacto');
must(sql.includes('kombax.contact.delete')&&sql.includes("'scope','participant_copy'"),'falta eliminación privada de conversación');
must(sql.includes('app_kombax_contact_can_access_v067')&&sql.includes('app_kombax_contactos_v067'),'bandeja v067 no oculta copias eliminadas');
must(repos.includes('deleteContact:')&&social.includes('Eliminar conversación'),'frontend no elimina conversaciones');

// Showcase: eliminación real de ficha y limpieza segura de Storage propio.
must(sql.includes('kombax.showcase.elemento.eliminar')&&sql.includes('delete from public.kombax_showcase_elementos'),'falta eliminación real de ficha Showcase');
must(repos.includes('removeOwnedShowcaseImages')&&repos.includes('deleteItem:async'),'falta limpieza de imágenes Showcase propias');
must(showcase.includes('data-showcase-delete')&&showcase.includes('Eliminar ficha de Showcase'),'gestión Showcase no ofrece eliminar');
must(showcase.includes('removeOwnedImages(oldUrls.filter'),'edición Showcase no limpia imágenes sustituidas');
must(showcase.includes("v.quitar_imagen?'':"),'Showcase no permite quitar la imagen principal');

// Tienda / comunicaciones siguen eliminables.
must(material.includes('detail-delete-material')&&material.includes('repos.material.delete'),'material/tienda perdió eliminación');
must(material.includes('delete-comm')&&material.includes('repos.communications.delete'),'comunicaciones perdieron eliminación');
must(clubProfile.includes('removeAlbumMedia'),'álbum del club perdió eliminación');

// Política multimedia: contenido completo, no crop, salvo avatares/logos/miniaturas fotográficas intencionales.
must(/\.kombax-post-media img[\s\S]{0,260}object-fit:contain/.test(premium),'feed Social no conserva proporción');
must(/\.showcase-item-visual>img[\s\S]{0,160}object-fit:contain/.test(appCss),'tarjeta Showcase sigue recortando');
must(/\.showcase-detail-media img[\s\S]{0,220}object-fit:contain/.test(appCss),'detalle Showcase sigue recortando');
must(/\.product-detail-media img[\s\S]{0,220}object-fit:contain/.test(appCss),'detalle tienda sigue recortando');
if(configBuild>=20045) must(/\.kx-public-banner\{[^}]*object-fit:cover/i.test(premium),'20.045+: portada Social pública no llena el banner con cover');
else must(/\.kx-public-banner\{[^}]*object-fit:contain/i.test(premium),'portada Social pública sigue recortando');
must(/\.kx-public-album video\{[^}]*object-fit:contain/i.test(premium),'vídeo de álbum público sigue recortando');
must(premium.includes('.kx-public-showcase-media')&&/\.kx-public-showcase-media img\{[^}]*object-fit:contain/i.test(premium),'imagen Showcase del perfil público no está acotada/adaptada');
must(publicProfile.includes('kx-public-showcase-media'),'perfil público no usa marco Showcase acotado');
if(configBuild>=20045) must(/\.club-public-cover\.has-image\{[^}]*background-size:100% 100%,cover/i.test(appCss),'20.045+: portada del Club no llena el banner con cover');
else must(/\.club-public-cover\.has-image\{[^}]*background-size:100% 100%,contain/i.test(appCss),'portada del perfil público del club no conserva imagen completa');
must(/\.kx-public-avatar img\{[^}]*object-fit:cover/i.test(premium),'avatar dejó de usar recorte intencional');

// Perfil personal público: puede eliminar avatar/portada además de sustituirlos.
must(publicProfile.includes('eliminar_avatar')&&publicProfile.includes('eliminar_banner')&&publicProfile.includes('removeMedia'),'perfil público personal no puede borrar avatar/portada');

console.log('KOMBAX BUILD 20041 CONTENT LIFECYCLE + ADAPTIVE MEDIA: PASS');
