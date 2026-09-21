import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const files={
 plan:read('docs/06_HISTORY/PLANS/PHASE_20101_R21_IMPLEMENTATION_PLAN.md'),
 migration:read('supabase/migrations/187_kombax_global_media_framing_20101_r21.sql'),
 completion:read('supabase/migrations/188_kombax_global_media_framing_completion_20101_r21.sql'),
 repo:read('web/js/core/repositories.js'),
 framing:read('web/js/ui/media-framing.js'),
 events:read('web/js/modules/kombax-events.js'),
 showcase:read('web/js/modules/showcase.js'),
 social:read('web/js/modules/kombax-social.js'),
 profile:read('web/js/modules/public-profile.js'),
 club:read('web/js/modules/club-profile.js'),
 community:read('web/js/modules/community.js'),
 material:read('web/js/modules/comms-material.js'),
 gateway:read('web/js/modules/gateway.js'),
 admin:read('web/js/modules/admin.js'),
 portal:read('web/js/modules/portal.js'),
 sports:read('web/js/modules/sports-profile.js'),
 backend:read('web/js/core/backend.js'),
 components:read('web/js/ui/components.js'),
 css:read('web/css/app.css'),
 premium:read('web/css/kombax-premium.css'),
 eventsCss:read('web/css/kombax-events.css'),
 index:read('web/index.html'),sw:read('web/service-worker.js')
};
const checks=[
 ['R21 plan has all mandatory protocol sections',Array.from({length:13},(_,i)=>files.plan.includes(`${i+1}.`)).every(Boolean)&&files.plan.includes('multiclub')&&files.plan.toLowerCase().includes('seed')],
 ['global helper preserves presentation instead of rewriting originals',(files.framing.includes('La fotografía original no se modifica')||files.framing.includes('El archivo original no se modifica'))&&files.framing.includes("fit:'contain'")&&files.framing.includes("fighter:{fit:'cover'")&&files.framing.includes('focus_x')&&files.framing.includes('zoom')],
 ['migration is additive across Events Social Profile Club Community Showcase Material and communications',['kombax_evento_participantes_publicos','kombax_evento_media','kombax_social_media','kombax_perfil_media','kombax_club_media','publicaciones_comunidad','kombax_showcase_elementos','material_catalogo','comunicaciones'].every(t=>files.migration.includes(t))],
 ['write RPC is authenticated and scope guarded',files.migration.includes('app_kombax_media_presentation_set_v187')&&files.migration.includes('AUTH_REQUIRED')&&files.migration.includes('grant execute on function public.app_kombax_media_presentation_set_v187')&&!files.migration.includes('grant execute on function public.app_kombax_media_presentation_set_v187(text,uuid,jsonb) to anon')],
 ['repository enriches legacy reads without replacing their contracts',files.repo.includes('readMediaPresentations')&&files.repo.includes('enrichMediaPresentations')&&files.repo.includes('app_kombax_media_presentations_v187')],
 ['Events separates training family from competition',files.events.includes("const TRAINING_TYPES=new Set(['seminario','clinic','masterclass','stage','campus'])")&&files.events.includes("eventFamily=event=>isTrainingEvent(event)?'training':'competition'")],
 ['training events do not force Main Event or Fight Card',files.events.includes("if(isTrainingEvent(event))return ''")&&files.events.includes("const competitionSections=training?'':")&&files.events.includes("training?'Programa e información':'Información'")],
 ['Event Creator adapts to formation with presenters and fewer steps',files.events.includes("EVENT CREATOR · R")&&files.events.includes("${training?'FORMACIÓN':'COMPETICIÓN'}")&&files.events.includes("training?'Ponentes':'Peleadores'")&&files.events.includes('no fuerza Main Event ni Fight Card')],
 ['fighter and album media have editable framing',files.events.includes("preset:'fighter'")&&files.events.includes("preset:'album'")&&files.events.includes("mediaFraming.set('event_participant'")&&files.events.includes("mediaFraming.set('event_media'")],
 ['Events mobile overflow hardening present',files.eventsCss.includes('MOBILE OVERFLOW HARDENING')&&files.eventsCss.includes('overflow-x:hidden')&&files.eventsCss.includes('min-width:0')],
 ['Showcase defaults to full product visibility and editor',files.showcase.includes('imagen_presentacion')&&files.showcase.includes("preset:'product'")&&files.showcase.includes("mediaFraming.set('showcase_item'")],
 ['Material catalogue defaults to full article visibility and editor',files.material.includes("mediaFrameAttrs(x.media_presentation,\"material\")")&&files.material.includes("mediaFraming.set('material_item'")],
 ['Club communications have framing',files.material.includes("mediaFraming.set('communication'")&&files.material.includes('frame-comm')],
 ['Social feed uses conventional full-image viewer and editor',files.social.includes('kx-social-image-button')&&files.social.includes('openSocialMediaViewer')&&files.social.includes("mediaFraming.set('social_media'")],
 ['Mi Perfil album, avatar and public Showcase use the same framing system',files.profile.includes('Ajustar avatar')&&files.profile.includes('Ajustar miniatura')&&files.profile.includes("mediaFrameAttrs(x.imagen_presentacion,'product')")],
 ['direct KOMBAX profile content supports avatar banner and album framing',files.gateway.includes('data-kx-media-frame')&&files.gateway.includes("mediaFraming.set('profile_media'")],
 ['club album supports adjustable thumbnails',files.club.includes('Ajustar miniatura')&&files.club.includes("mediaFraming.set('club_media'")],
 ['Community supports full image view and adjustable feed framing',files.community.includes('community-image-open')&&files.community.includes('community-frame')&&files.community.includes("mediaFraming.set('community_post'")],
 ['CSS respects user presentation variables',files.css.includes('.kx-media-frame-img')&&files.css.includes('--kx-media-fit')&&files.premium.includes('.kx-social-image-button')&&files.css.includes('.community-image-open')],
 ['R21-or-newer cache bust is explicit',revisionAtLeast(files.index,21)&&revisionAtLeast(files.sw,21,'media-r')],
 ['completion migration covers remaining visible multimedia surfaces',['perfiles','perfiles_deportivos','clubes','perfiles_club_publicos','galeria_presentacion'].every(t=>files.completion.includes(t))&&files.completion.includes('app_kombax_media_presentation_set_v188')&&files.completion.includes('app_kombax_media_presentations_v188')],
 ['v188 setter remains authenticated-only and reuses existing authorization guards',files.completion.includes('revoke all on function public.app_kombax_media_presentation_set_v188(text,uuid,jsonb) from public,anon')&&files.completion.includes('to authenticated')&&files.completion.includes('app_puede_editar_perfil_deportivo_v032')&&files.completion.includes('app_puede_publicar_branding_v039')&&files.completion.includes('app_kombax_showcase_puede_gestionar_v045')],
 ['private avatar has visible framing action in both profile entry points',files.admin.includes('Ajustar foto')&&files.admin.includes("mediaFraming.set('private_avatar'")&&files.portal.includes('Ajustar foto')&&files.portal.includes("mediaFraming.set('private_avatar'")],
 ['sports profile photo has visible editor and persistent framing',files.sports.includes('Ajustar foto')&&files.sports.includes("mediaFraming.set('sports_profile'")&&files.sports.includes('foto_presentation')],
 ['club branding logo and cover both expose visible adjustment actions',files.admin.includes('Ajustar logo')&&files.admin.includes('Ajustar portada')&&files.admin.includes("mediaFraming.set('club_brand_logo'")&&files.admin.includes("mediaFraming.set('club_brand_cover'")],
 ['public club profile logo and cover both expose visible adjustment actions',files.club.includes('Ajustar logo')&&files.club.includes('Ajustar portada')&&files.club.includes("mediaFraming.set('club_public_logo'")&&files.club.includes("mediaFraming.set('club_public_cover'")],
 ['Showcase secondary gallery supports individual slot framing',files.showcase.includes('Ajustar galería')&&files.showcase.includes('showcase_gallery_')&&files.repo.includes('galeria_presentacion')],
 ['session avatar and shell club logo render persisted framing',files.backend.includes('avatar_presentation')&&files.components.includes('logo_presentation')],
 ['document attachments remain outside presentation framing by design',!files.framing.includes('payment_proof')&&!files.framing.includes('verification_document')],
 ['R20 seed and R19 Showcase migrations remain preserved',fs.existsSync(path.join(root,'supabase/migrations/186_kombax_urban_warriors_muay_thai_seminar_20101_r20.sql'))&&fs.existsSync(path.join(root,'supabase/migrations/185_kombax_showcase_urban_warriors_demo_products_20101_r19.sql'))]
];
let bad=0;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);
console.log(`OK KOMBAX 20.101 R21 · ${checks.length}/${checks.length}`);
