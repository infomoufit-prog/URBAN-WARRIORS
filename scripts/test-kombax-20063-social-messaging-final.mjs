import {readFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url);const read=p=>readFile(new URL(p,root),'utf8');
const [cfg,html,sw,gradle,social,showcase,repos,components,app,css,migration,verification,hub,gateway,admin]=await Promise.all([
  read('web/config.js'),read('web/index.html'),read('web/service-worker.js'),read('android/app/build.gradle'),read('web/js/modules/kombax-social.js'),read('web/js/modules/showcase.js'),read('web/js/core/repositories.js'),read('web/js/ui/components.js'),read('web/js/app.js'),read('web/css/kombax-premium.css'),read('supabase/migrations/107_kombax_social_showcase_messaging_20063.sql'),read('supabase/verification/107_kombax_social_showcase_messaging_20063_verification.sql'),read('web/js/modules/club-kombax-hub.js'),read('web/js/modules/gateway.js'),read('web/js/modules/platform-admin.js')
]);
const ok=(v,m)=>{if(!v)throw new Error(`20063: ${m}`);console.log('OK '+m)};
const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]),android=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]),swBuild=Number(sw.match(/rc13-(\d+)/)?.[1]),refs=[...html.matchAll(/\?v=(\d+)/g)].map(x=>Number(x[1]));
ok(build>=20063&&android===build&&swBuild===build&&refs.length>0&&refs.every(v=>v===build),'web/PWA/Android conservan 20063+ y permanecen alineados');
ok(!social.includes('Cerrar chat')&&!social.includes('kx-contact-close-thread')&&social.includes('Eliminar conversación')&&social.includes("#modal-close')?.addEventListener('click',cleanup"),'X conserva el hilo y Cerrar chat desaparece de la UI');
ok(social.includes('renderInlineComments')&&social.includes('kx-inline-comment-composer')&&!social.includes('Añadir comentario'),'comentarios se escriben inline sin segundo modal');
ok(social.includes("'Mi red'")&&social.includes('Añadir a mi red')&&!/Relaciones|Mis relaciones|Solicitar relación|Vincular con/.test(social+hub+gateway+admin),'terminología visible normalizada a Mi red');
ok(components.includes('minLength')&&social.includes('minLength:10,maxLength:500'),'Contact Gate aplica 10–500 caracteres desde frontend');
ok(social.includes('Mensajes KOMBAX')&&social.includes('data-message-filter="showcase"')&&social.includes('kx-message-product'),'bandeja diferencia Social y Showcase y muestra contexto de producto');
ok(showcase.includes('openShowcaseContact')&&showcase.includes('showcase-chat-cta')&&showcase.includes('Consultar en Showcase')&&showcase.includes('showcaseContact'),'Showcase inicia consulta comercial ligada a ficha');
ok(repos.includes('app_kombax_social_network_mutate_v107')&&repos.includes('app_kombax_social_network_mutate_v104')&&repos.includes('app_kombax_contactos_v107')&&repos.includes('app_kombax_contactos_v106')&&repos.includes('app_kombax_header_summary_v107')&&repos.includes('app_kombax_header_summary_v106')&&repos.includes('kombax.showcase.contact.request')&&repos.includes('La mensajería de Showcase necesita activar la actualización 107'),'repositorio usa v107 con fallback seguro a 106/104 y bloquea Showcase si backend 107 aún no está activo');
ok(migration.includes("canal text not null default 'social'")&&migration.includes('showcase_elemento_id')&&migration.includes('showcase_producto_imagen_url')&&migration.includes('uq_kombax_contact_showcase_pair_item_open_v107'),'schema separa canal y un hilo por pareja+producto');
ok(migration.includes('count(distinct c.id)')&&migration.includes('message_unread'),'badge superior cuenta conversaciones no leídas, no mensajes individuales');
ok(app.includes('SOLICITUDES DE MENSAJERÍA')&&app.includes('icono de Mensajes'),'notificaciones KOMBAX no duplican el contenido del chat');
ok(css.includes('.kx-message-card.showcase')&&css.includes('.kx-showcase-chat-product')&&css.includes('.kx-inline-comments'),'tratamiento visual Social/Showcase e inline comments disponible');
ok(verification.includes('app_kombax_header_summary_v107')&&verification.includes('app_kombax_contactos_v107'),'verificación SQL v107 incluida');
console.log('KOMBAX BUILD 20063 · SOCIAL MESSAGING FINAL QA: PASS');
