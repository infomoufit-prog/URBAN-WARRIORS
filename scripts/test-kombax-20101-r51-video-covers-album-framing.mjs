import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const stripLineComments=s=>s.replace(/^\s*\/\/.*$/gm,'');
const files={
  videoCover:read('web/js/ui/video-cover.js'),
  framing:read('web/js/ui/media-framing.js'),
  media:read('web/js/core/media.js'),
  repo:read('web/js/core/repositories.js'),
  social:read('web/js/modules/kombax-social.js'),
  events:read('web/js/modules/kombax-events.js'),
  club:read('web/js/modules/club-profile.js'),
  profile:read('web/js/modules/public-profile.js'),
  gateway:read('web/js/modules/gateway.js'),
  css:read('web/css/app.css'),
  premium:read('web/css/kombax-premium.css'),
  migration:read('supabase/migrations/245_kombax_video_covers_album_framing_r51.sql'),
  edge:read('supabase/functions/event-media-url/index.ts'),
  package:read('package.json')
};
let ok=0,fail=0;
const test=(name,condition)=>{if(condition){console.log('PASS',name);ok++;}else{console.error('FAIL',name);fail++;}};

test('R51 video cover module exists',files.videoCover.includes('captureVideoFrame')&&files.videoCover.includes('openVideoCoverEditor'));
test('video cover supports automatic frame',files.videoCover.includes('data-kx-cover-auto')&&files.videoCover.includes("'auto'"));
test('video cover supports chosen frame',files.videoCover.includes('data-kx-cover-frame')&&files.videoCover.includes("'frame'"));
test('video cover supports custom upload',files.videoCover.includes('data-kx-cover-upload')&&files.videoCover.includes("'upload'"));
test('cover editor states original video is unchanged',files.videoCover.includes('vídeo original permanece intacto'));
test('automatic video preparation returns cover time',files.media.includes('coverTime:Number(video.currentTime||0)'));
test('repository stores cover separately from video asset',files.repo.includes('cover_storage_path')&&files.repo.includes('storeMediaCover'));
test('cover replacement removes previous cover only after save',files.repo.includes('oldPath&&oldPath!==path')&&files.repo.includes('backend.remove(oldBucket,oldPath)'));
test('framing setter merges existing cover metadata',files.repo.includes('const merged={...current,...'));

test('album preset defaults to balanced',files.framing.includes("album:{fit:'balanced'"));
test('framing accepts balanced mode',files.framing.includes("'balanced'"));
test('framing editor offers Completo',files.framing.includes('Mostrar completo'));
test('framing editor offers Equilibrado',files.framing.includes('Equilibrado'));
test('framing editor offers Rellenar',files.framing.includes('Rellenar marco'));
test('balanced uses non-destructive base scale',files.framing.includes('--kx-media-base-scale')&&files.framing.includes("balanced?'0.90':'1'"));
test('CSS applies base scale plus user zoom',files.css.includes('scale(var(--kx-media-base-scale,1)) scale(var(--kx-media-zoom,1))'));
test('album video no longer forced to contain over framing',files.premium.includes('.kx-album-media video:not(.kx-media-frame-img)'));

test('KOMBAX Social video renders poster cover',files.social.includes('media_cover_url')&&files.social.includes('poster='));
test('KOMBAX Social own video exposes cover action',files.social.includes('data-social-cover')&&files.social.includes('Elegir portada del vídeo'));
test('KOMBAX Social uses shared cover editor',files.social.includes('openVideoCoverEditor'));
test('KOMBAX Social resolves cover through media access rules',files.social.includes('cover_storage_path')&&files.social.includes('cover_storage_bucket'));
test('club album frames videos as well as photos',files.club.includes("mediaFrameAttrs(m.media_presentation,'album')")&&files.club.includes("mediaType:item.tipo==='video'?'video':'image'"));
test('member/public profile album frames videos as well as photos',files.profile.includes("mediaFrameAttrs(m.media_presentation,'album')")&&files.profile.includes("mediaType:item.tipo==='video'?'video':'image'"));
test('member album exposes manual video cover selector',files.profile.includes('data-kx-member-video-cover')&&files.profile.includes('openVideoCoverEditor'));
test('club album exposes manual video cover selector',files.club.includes('data-club-video-cover')&&files.club.includes('openVideoCoverEditor'));
test('direct profile album frames video and renders poster',files.gateway.includes("mediaFrameAttrs(m.media_presentation,'album')")&&files.gateway.includes('cover_storage_path')&&files.gateway.includes('poster='));
test('direct profile album exposes framing and video cover selector',files.gateway.includes('data-kx-direct-video-cover')&&files.gateway.includes('openVideoCoverEditor')&&files.gateway.includes("mediaType:media.tipo==='video'?'video':'image'"));
test('club and direct profile repositories can replace video cover',files.repo.includes("setVideoCover:(club_id,media,file")&&files.repo.includes("setVideoCover:(profileId,media,file"));
test('album removal also cleans separate video cover asset',files.repo.includes('async function removeMediaCover')&&files.repo.includes('await removeMediaCover(media?.media_presentation'));
test('R51 album UI no longer advertises historical 15 second limit',![files.club,files.profile,files.gateway].map(stripLineComments).some(x=>/15 s|15 segundos/i.test(x)));
test('R51 album UI advertises 60 second video limit',files.club.includes('máximo 60 s por vídeo')&&files.profile.includes('máximo 60 s por vídeo')&&files.gateway.includes('vídeo máximo 60 s'));

test('KOMBAX Events imports cover editor',files.events.includes("from '../ui/video-cover.js'"));
test('KOMBAX Events video cards carry presentation metadata',files.events.includes('data-kx-video-cover')&&files.events.includes('data-kx-media-presentation'));
test('KOMBAX Events video gets media framing style',files.events.includes("mediaFrameStyle(presentation,'album')")&&files.events.includes("media.className='kx-media-frame-img'"));
test('KOMBAX Events cover resolves as cover variant',files.events.includes("mediaUrl(card.dataset.kxEventMedia,'cover')"));
test('KOMBAX Events offers Ajustar álbum for stored video',files.events.includes('Ajustar álbum')&&files.events.includes('isStoredEventVideo'));
test('KOMBAX Events offers Elegir portada for stored video',files.events.includes('Elegir portada')&&files.events.includes('data-kx-video-cover'));
test('KOMBAX Events cover editor persists via repository',files.events.includes('repos.kombaxEvents.setVideoCover'));
test('KOMBAX Events album filter applies to photo and video cards',files.events.includes("querySelectorAll('[data-kx-event-media]')"));
test('KOMBAX Events bundled detail enriches media presentations',files.repo.includes("const media=await enrichMediaPresentations('event_media',bundled.media||[])"));
test('event repository supports cover URL variant',files.repo.includes("mediaUrl:(media_id,variant='asset')"));

test('R51 migration persists balanced mode',files.migration.includes("'auto','cover','contain','balanced'"));
test('R51 migration validates cover mode',files.migration.includes("'auto','frame','upload'"));
test('R51 migration restricts cover buckets',files.migration.includes("'kombax-public-media','kombax-restricted-media','kombax-events-media'"));
test('R51 migration caps cover time at 60.2 seconds',files.migration.includes('least(60.2'));
test('restricted Social framing metadata remains visibility guarded',files.migration.includes('app_kombax_social_puede_ver_publicacion_v083'));
test('event cover resolver exists',files.migration.includes('app_kombax_evento_media_asset_v251'));
test('event cover resolver accepts only asset or cover',files.migration.includes("v_variant not in ('asset','cover')"));
test('event cover resolver restricts cover to event bucket',files.migration.includes("cover_storage_bucket'='kombax-events-media"));
test('event edge function accepts cover variant',files.edge.includes("variant?:'asset'|'cover'")&&files.edge.includes("p_variant:variant"));
test('event edge keeps public compatibility and signed delivery',files.edge.includes('app_kombax_evento_media_asset_v165')&&files.edge.includes('createSignedUrl'));
test('active runtime naming uses KOMBAX Social not Combat Social',![files.social,files.events,files.videoCover].some(x=>x.includes('Combat Social')));
test('active runtime naming uses KOMBAX Events not Combat Events',![files.social,files.events,files.videoCover].some(x=>x.includes('Combat Events')));
test('R51 npm script registered',files.package.includes('test:20101:r51'));

console.log(`R51 ${ok}/${ok+fail} ${fail?'FAIL':'PASS'}`);
if(fail)process.exit(1);
