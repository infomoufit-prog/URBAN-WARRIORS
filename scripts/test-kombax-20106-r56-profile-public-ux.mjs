import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const read=async p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const [profile,css,cfg,sw,gradle,main,debug,aab,social,showcase,events,repos]=await Promise.all([
  read('web/js/modules/public-profile.js'),read('web/css/kombax-premium.css'),read('web/config.js'),read('web/service-worker.js'),
  read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('scripts/android-debug-qa.mjs'),read('scripts/android-play-bundle.mjs'),
  read('web/js/modules/kombax-social.js'),read('web/js/modules/showcase.js'),read('web/js/modules/kombax-events.js'),read('web/js/core/repositories.js')
]);
const ok=(name,value)=>{assert.ok(value,name);console.log('PASS',name)};
const sha=x=>createHash('sha256').update(x).digest('hex');
const currentBuild=Number((cfg.match(/build:\s*(\d+)/)||[])[1]||0);
const ownPage=(profile.match(/export async function renderOwnKombaxProfilePage[\s\S]*$/)||[''])[0];
const galleryBlock=(profile.match(/function gallery\(profile\)\{[\s\S]*?\n\}/)||[''])[0];
ok('R56 profile UX survives current build',currentBuild>=20106);
ok('R56 profile UX survives versioned service worker',/uw2-build-20\d{3}/.test(sw));
ok('R56 profile UX survives current Android release identity',/versionCode\s+20\d{3}/.test(gradle)&&main.includes('KOMBAXApp/2.0.0-rc.13/'));
ok('R56 profile UX survives Android artifact pipeline',debug.includes(`KOMBAX_${currentBuild}_`)&&/_DEBUG\.apk/.test(debug)&&aab.includes(`KOMBAX_${currentBuild}_`)&&/_GOOGLE_PLAY\.aab/.test(aab));
ok('public album preview hard limit is five',profile.includes('const PUBLIC_ALBUM_PREVIEW_LIMIT=5')&&galleryBlock.includes('rows.slice(0,PUBLIC_ALBUM_PREVIEW_LIMIT)'));
ok('profile album offers full album only when needed',galleryBlock.includes('rows.length>PUBLIC_ALBUM_PREVIEW_LIMIT')&&galleryBlock.includes('Ver álbum completo'));
ok('full album is a separate on-demand view',profile.includes('function openPublicAlbum(p)')&&profile.includes('body:fullAlbumMarkup(p)')&&profile.includes("#kx-public-album-more")&&profile.includes('openPublicAlbum(p)'));
ok('full album preserves Todo/Fotos/Vídeos filters',profile.includes('function fullAlbumMarkup(profile)')&&profile.includes('data-kx-album-filter="all"')&&profile.includes('data-kx-album-filter="photo"')&&profile.includes('data-kx-album-filter="video"'));
ok('own profile exposes one contextual management entry in hero',profile.includes("p.own?`<button type=\"button\" class=\"kx-profile-manage-trigger\"")&&profile.includes('id="kx-public-manage-profile"'));
ok('own profile no longer renders management grid before banner',!ownPage.includes("profileActions(p,{legal:true})")&&!ownPage.includes('kx-canonical-profile-notice')&&!ownPage.includes('Una identidad, un perfil'));
ok('own profile successful render starts directly with public profile hero',ownPage.includes('setMainHtml(`${profileArticle(p,{usage})}${extraHtml}`)')&&!ownPage.includes("pageHeader('Mi perfil','Vista de tu perfil público"));
ok('profile manager retains existing member controls',profile.includes('Gestionar álbum')&&profile.includes('Editar mi perfil')&&profile.includes('Compartir afiliación'));
ok('profile manager retains security/privacy/media controls',profile.includes('Ajustar avatar')&&profile.includes('Ajustar banner')&&profile.includes('Gestionar publicaciones')&&profile.includes('Seguridad y acceso')&&profile.includes('Privacidad y condiciones'));
ok('privacy remains available in every own-profile management context',profile.includes('<button class=\"btn btn-ghost\" id=\"kx-public-legal\">Privacidad y condiciones</button>')&&!profile.includes("${legal?'<button class=\"btn btn-ghost\" id=\"kx-public-legal\""));
ok('club management remains available',profile.includes('Gestionar perfil del club')&&profile.includes('kx-public-club-manage'));
ok('third-party public profile actions remain intact',profile.includes('Añadir a mi red')&&profile.includes('Contactar')&&profile.includes('Denunciar')&&profile.includes('>Compartir</button>'));
ok('Social profile preview remains five posts + progressive older posts',profile.includes('arr(profile.posts).slice(0,5)')&&profile.includes('Ver todas las publicaciones')&&profile.includes('profilePosts(p.id,postCursor,10)'));
ok('Showcase profile preview remains four products',profile.includes("i>=4?'data-kx-showcase-extra hidden':''")&&profile.includes('Ver todo su Showcase'));
ok('management entry is generic for every own identity',profile.includes("${p.own?`<button")&&!/type==='miembro'.{0,120}kx-profile-manage-trigger/s.test(profile));
ok('R56 management and album preview have responsive styling',css.includes('.kx-profile-manage-trigger')&&css.includes('.kx-profile-manage-grid')&&css.includes('.kx-public-album-preview{grid-template-columns:repeat(5')&&css.includes('@media(max-width:620px)'));
ok('Social retains R56 publication/profile contract',social.includes('function quickComposer()')&&social.includes('Ver normas de publicación')&&social.includes('competitorFoundersPromo'));
ok(currentBuild>=20108?'Showcase preserves deliberate R58+ evolution':'Showcase module is unchanged from R55',currentBuild>=20108?(showcase.includes("media:'Media / Creador'")&&(showcase.includes('Consultar en Showcase')||showcase.includes('Me interesa'))):sha(showcase)==='af769c24f454393515da9822077d62159953d263405178a7952edd6b8f0edbae');
ok(currentBuild>=20110?'Events preserves deliberate R60 navigation/media evolution':'Events module is unchanged from R55',currentBuild>=20110?(events.includes('openEvent')&&events.includes('invalidateEventDetail')&&events.includes('eventDetailInflight')):sha(events)==='2bc0f20a14f84e2d8164d250de1ca03eeba484ebe31fff73a5df0624d3345549');
ok(currentBuild>=20108?'Repositories preserve R58+ membership evolution':'Repositories are unchanged from R55',currentBuild>=20109?(repos.includes('app_kombax_mis_membresias_r58')&&repos.includes('app_kombax_preinscripcion_aprobar_r59')):currentBuild>=20108?repos.includes('app_kombax_mis_membresias_r58'):sha(repos)==='dfd0474ed65336208a66b620f85f842419fee19de54418edf072e9b2e6f3c4c4');
const migrations=await readdir(new URL('../supabase/migrations/',import.meta.url));
ok('R56 is frontend-only with no new database migration',!migrations.some(x=>/r56/i.test(x)));
console.log('R56 public profile UX/freeze candidate: 25/25 PASS');
