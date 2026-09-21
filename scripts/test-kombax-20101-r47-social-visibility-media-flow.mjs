import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const social=read('web/js/modules/kombax-social.js');
const repo=read('web/js/core/repositories.js');
const css=read('web/css/kombax-premium.css');
const sql=[
  read('supabase/migrations/237_kombax_social_visibility_core_r47.sql'),
  read('supabase/migrations/238_kombax_social_feed_preferences_r47.sql'),
  read('supabase/migrations/239_kombax_social_mutation_visibility_r47.sql')
].join('\n');
const feed237=sql.split('create or replace function public.app_kombax_social_feed_v237')[1]?.split('create or replace function public.app_kombax_social_mutate_v123')[0]||'';
const checks=[];const ok=(name,cond)=>checks.push([name,Boolean(cond)]);
ok('user-side hide action removed from Social feed',!social.includes('data-social-hide')&&!repo.includes('hidePost:'));
ok('Me interesa / No me interesa share one preference control',social.includes('kx-interest-control')&&social.includes('>Me interesa</b>')&&social.includes('>No me interesa</b>'));
ok('preference is reversible to neutral',social.includes('Sin preferencia')&&social.includes('data-value="0"'));
ok('repository exposes tri-state preference mutation',repo.includes("kombax.social.preferencia")&&repo.includes('preference:(publicacion_id,valor=0)'));
ok('negative preference does not filter the post out',feed237&&!feed237.includes('kombax_social_ocultados_usuario'));
ok('ranking applies positive and negative personal signals',sql.includes('author_disinterest_count')&&sql.includes('when -1 then -2.25')&&sql.includes('when 1 then 1.25'));
ok('positive preference remains compatible with interest counts',sql.includes('insert into public.kombax_social_likes')&&sql.includes('delete from public.kombax_social_likes'));
ok('R46 hidden rows are cleared during R47 transition',sql.includes('delete from public.kombax_social_ocultados_usuario'));
ok('visibility supports selected profiles',sql.includes("'perfiles_seleccionados'")&&sql.includes('kombax_social_post_visibility_profiles_v237'));
ok('visibility supports profile types',sql.includes("'tipos_perfil'")&&sql.includes('kombax_social_post_visibility_types_v237'));
ok('existing club and federation visibility remains',sql.includes("'clubes_seleccionados'")&&sql.includes("'kombax_excepto'")&&sql.includes("'federacion'")&&sql.includes("'clubes_federacion'"));
ok('post owner gets visibility action after publishing',social.includes('data-social-visibility')&&social.includes('openVisibilityEditor'));
ok('existing-post visibility editor reloads persisted configuration',social.includes('repos.kombaxSocial.visibilityConfig(post.id)')&&social.includes('config.club_ids')&&social.includes('config.profile_ids')&&social.includes('config.profile_types'));
ok('existing-post visibility editor persists all advanced selectors',social.includes('repos.kombaxSocial.setVisibility(post.id')&&social.includes('audiencia_excluded_club_ids:[...controls.excludedClubIds]')&&social.includes('audiencia_profile_ids:[...controls.profileIds]')&&social.includes('audiencia_profile_types:[...controls.profileTypes]'));
ok('visibility config is RPC-only',sql.includes('app_kombax_social_visibility_config_v237')&&sql.includes('grant execute on function public.app_kombax_social_visibility_config_v237')&&repo.includes('visibilityConfig:'));
ok('visibility mutation is explicit and idempotent',sql.includes("p_operation in ('kombax.social.preferencia','kombax.social.visibilidad')")&&sql.includes('MUTATION_REQUEST_ID_REUSED')&&repo.includes('setVisibility:'));
ok('publisher sends profile and profile-type audience selections',repo.includes('audiencia_profile_ids')&&repo.includes('audiencia_profile_types')&&social.includes('audienceProfileIds')&&social.includes('audienceProfileTypes'));
ok('quick composer excludes complex audiences that need a picker',social.includes('simpleAudienceOptions')&&social.includes('COMPLEX_AUDIENCE_MODES'));
ok('private visibility preserves restricted-media confidentiality',sql.includes('KOMBAX_RESTRICTED_POST_REQUIRES_PRIVATE_MEDIA')&&sql.includes('KOMBAX_PUBLIC_POST_REQUIRES_PUBLIC_MEDIA'));
ok('repository prefers R47 relevance feed with safe fallbacks',repo.includes("app_kombax_social_feed_v237")&&repo.includes("app_kombax_social_feed_v236")&&repo.includes("app_kombax_social_feed_v085"));
ok('portrait feed media has a defined mobile portrait frame',css.includes('[data-kx-media-orientation="portrait"]{aspect-ratio:4/5')||css.includes('[data-kx-media-orientation="portrait"]{aspect-ratio:9/16'));
ok('square and landscape frames are defined',css.includes('[data-kx-media-orientation="square"]{aspect-ratio:1}')&&css.includes('[data-kx-media-orientation="landscape"]{aspect-ratio:16/9}'));
ok('image and video orientation are detected from real media dimensions',social.includes('naturalWidth')&&social.includes('videoWidth')&&social.includes('bindMediaOrientation'));
ok('video has explicit fullscreen affordance',social.includes('data-social-video-open')&&social.includes('kx-social-expand-media'));
ok('media viewer is immersive full-screen',css.includes('.modal.kx-social-immersive-modal')&&css.includes('height:100dvh!important')&&css.includes('.kx-social-immersive-stage'));
ok('fullscreen uses contain so original is not cropped',css.includes('object-fit:contain!important'));
ok('feed framing is explicit and can preserve the original',css.includes('object-fit:var(--kx-media-fit,contain)!important')||css.includes('object-fit:cover!important'));
ok('audience helper has searchable clubs and profiles plus type selector',social.includes('kx-audience-profile-query')&&social.includes('kx-audience-club-query')&&social.includes('data-kx-audience-type'));
for(const [n,c] of checks)console.log(`${c?'PASS':'FAIL'} · ${n}`);
const fails=checks.filter(x=>!x[1]);
console.log(`\nR47 ${checks.length-fails.length}/${checks.length} PASS`);
if(fails.length)process.exit(1);
