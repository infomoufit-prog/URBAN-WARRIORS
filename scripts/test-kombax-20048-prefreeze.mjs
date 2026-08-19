import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const fail=m=>{console.error('FAIL 20048 PREFREEZE:',m);process.exit(1)};
const ok=(c,m)=>{if(!c)fail(m)};

const mig94=read('supabase/migrations/094_kombax_canonical_member_profile_20048.sql');
const mig95=read('supabase/migrations/095_kombax_club_social_directory_20048.sql');
const repos=read('web/js/core/repositories.js');
const portal=read('web/js/modules/portal.js');
const profile=read('web/js/modules/public-profile.js');
const community=read('web/js/modules/community.js');
const club=read('web/js/modules/club-profile.js');
const legal=read('web/js/modules/help-legal.js');
const css=read('web/css/app.css');
const premium=read('web/css/kombax-premium.css');
const cfg=read('web/config.js');
const idx=read('web/index.html');
const sw=read('web/service-worker.js');
const gradle=read('android/app/build.gradle');

// Canonical Member data model and conservative migration.
ok(mig94.includes('add column if not exists apodo_deportivo')&&mig94.includes('disciplinas_publicas')&&mig94.includes('trayectoria_declarada'),'094 añade campos deportivos públicos a la identidad canónica');
ok(mig94.includes('coalesce(nullif(i.apodo_deportivo')&&mig94.includes('coalesce(nullif(i.bio_publica'),'backfill legacy no pisa valores Social existentes');
ok(mig94.includes('from public.perfiles_deportivos pd'),'094 importa legado únicamente como fuente de transición');
const sync=(mig94.match(/create or replace function public\.app_kombax_social_sync_miembro_v041\(\)[\s\S]*?\$\$;/)||[])[0]||'';
ok(sync&&!sync.includes('perfiles_deportivos'),'sincronizador actual Miembro ya no depende del perfil deportivo legacy');
ok(sync.includes('app_kombax_social_switch_competitor_v072'),'sincronizador conserva continuidad Miembro→Competidor');
ok(mig94.includes('app_kombax_identity_mutate_v094'),'gateway canónico 094 existe');
ok(mig94.includes("if p_operation not in ('kombax.identity.member.activate','kombax.identity.member.profile.update')")&&mig94.includes("if p_operation='kombax.identity.member.activate'"),'094 implementa activación y edición Miembro sin perfil legacy');
ok(mig94.includes('app_kombax_perfil_publico_v094')&&mig94.includes("'{sports}'"),'perfil público 094 enriquece la misma ficha con sports');
ok(mig94.includes("return v-'relations'"),'perfil público 094 mantiene Relaciones privadas');
ok(mig94.includes('revoke all on function public.app_kombax_perfil_publico_v094(uuid) from public,anon')&&mig94.includes('grant execute on function public.app_kombax_perfil_publico_v094(uuid) to authenticated'),'perfil público 094 no se abre a anon');

// Same-club directory resolves canonical Social IDs without exposing Relations/private records.
ok(mig95.includes('app_kombax_club_social_directory_v095'),'directorio canónico 095 existe');
ok(mig95.includes('social_id uuid')&&mig95.includes('socio_id uuid'),'095 conecta socio interno con Social ID canónico');
ok(mig95.includes('es_miembro_club(p_club_id)'),'095 exige pertenencia al club');
ok(!mig95.includes('kombax_relaciones'),'095 no expone Relaciones');
ok(mig95.includes('revoke all on function public.app_kombax_club_social_directory_v095(uuid,text,integer) from public,anon'),'095 no se abre a anon');

// Runtime is canonical Social, not legacy sports profile.
ok(repos.includes("app_kombax_identity_mutate_v094")&&repos.includes("app_kombax_perfil_publico_v094")&&repos.includes("app_kombax_club_social_directory_v095"),'repositorio usa contratos 094/095');
ok(portal.includes('renderOwnKombaxProfilePage')&&portal.includes('Tu perfil KOMBAX será tu única ficha pública'),'Mi perfil del alumno usa ficha KOMBAX canónica');
ok(!portal.includes('sports-profile.js')&&!portal.includes('Perfil deportivo compartido'),'Portal no presenta perfil deportivo separado');
ok(community.includes('openKombaxPublicProfile')&&community.includes('data-author-social')&&community.includes('clubDirectory'),'Comunidad del Club abre identidad KOMBAX del autor');
ok(!community.includes('openSportsProfile')&&!community.includes('loadSportsProfiles'),'Comunidad ya no usa perfil deportivo legacy');
ok(club.includes('clubDirectory')&&club.includes('data-social-id')&&club.includes("import('./public-profile.js')"),'directorio del Club abre Social ID canónico');
ok(!club.includes('openSportsProfile')&&!club.includes('sportsProfiles'),'directorio Club no usa foto/perfil legacy');
ok(profile.includes('Información deportiva')&&profile.includes('Gestionar álbum')&&profile.includes('Editar mi perfil'),'Miembro conserva ficha enriquecida y editable');
ok(profile.includes('photos.length>=10')&&profile.includes('videos.length>=3')&&profile.includes('máximo 15 s'),'límites de álbum Miembro se conservan');
ok(legal.includes('Mi perfil KOMBAX')&&legal.includes('no existe un segundo perfil deportivo visible'),'manual explica arquitectura de un solo perfil');
ok(!legal.includes('perfil deportivo interno'),'centro legal ya no describe una capa deportiva pública separada');

// Club shell brand background: black + blurred logo, never cover image.
const shell=(css.match(/\.content-shell::before\{[^}]+\}/)||[])[0]||'';
const store=(css.match(/\.store-hero::after\{[^}]+\}/)||[])[0]||'';
ok(shell.includes('var(--uw-logo-image)')&&!shell.includes('var(--uw-cover-image)'),'shell global usa logo, no portada');
ok(shell.includes('blur(10px)')&&shell.includes('grayscale(1)')&&shell.includes('opacity:.055'),'marca de agua shell está difuminada y atenuada');
ok(css.includes('.content-shell{')&&css.includes('background:#050608'),'shell mantiene negro dominante');
ok(store.includes('var(--uw-logo-image)')&&!store.includes('var(--uw-cover-image)')&&store.includes('blur(7px)'),'hero de tienda usa misma marca de agua difuminada');
ok(premium.includes('20.048 · Perfil Miembro canónico'),'estilos del perfil canónico están incluidos');

// Security/privacy/product invariants.
ok(profile.includes('La insignia KOMBAX')&&profile.includes('Competidor verificado'),'Miembro sigue diferenciado de Competidor');
ok(profile.includes('Privacidad y condiciones')&&profile.includes('openPrivacyConditions'),'legal se abre desde Mi perfil real');
ok(!community.includes('data-author-socio'),'clic de autor ya no abre identidad legacy por socio_id');

// Version/caches.
const currentBuild=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0);
const currentAndroid=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
ok(currentBuild>=20048,'config conserva build 20048 o posterior');
ok(currentAndroid>=20048,'Android conserva versionCode 20048 o posterior');
ok(idx.includes(`?v=${currentBuild}`),'web cache busting coincide con build actual');
ok(sw.includes(`uw2-2.0.0-rc13-${currentBuild}`),'service worker coincide con build actual');
console.log('KOMBAX BUILD 20048 · canonical profile + club visual prefreeze: PASS');
