import {readFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url);const read=p=>readFile(new URL(p,root),'utf8');
const assert=(c,m)=>{if(!c)throw new Error(`20034 premium neon: ${m}`)};
const [css,platform,admin,clubProfile,publicProfile,repos,index,config,gradle,sw,mig]=await Promise.all([
  read('web/css/app.css'),read('web/js/core/platform.js'),read('web/js/modules/admin.js'),read('web/js/modules/club-profile.js'),read('web/js/modules/public-profile.js'),read('web/js/core/repositories.js'),read('web/index.html'),read('web/config.js'),read('android/app/build.gradle'),read('web/service-worker.js'),read('supabase/migrations/061_kombax_premium_neon_theme_public_profiles.sql')
]);
for(const t of ['theme-combat-dark','theme-performance-pro','theme-champion-gold','theme-dojo-heritage'])assert(css.includes(t),`falta ${t}`);
for(const token of ['--theme-accent-2','--theme-glow-strong','--theme-surface-2','--theme-accent-line'])assert(css.includes(token),`falta token ${token}`);
assert(css.includes('.kombax-social-page')&&css.includes('var(--theme-accent)'),'KOMBAX Social no hereda el acento del club');
assert(css.includes('.club-public-profile[class*="theme-"]'),'perfil público del club sin tematización');
assert(css.includes('@media (prefers-reduced-motion:reduce)'),'falta reduced motion');
assert(platform.includes('Combat Dark Neon')&&platform.includes('Electric Blue Pro')&&platform.includes('Gold Luxe')&&platform.includes('Dojo Heritage Glow'),'nombres/descripciones premium no actualizados');
assert(admin.includes('Tema premium del club')&&admin.includes('VISTA PREVIA GLOBAL'),'Configuración no comunica alcance global');
assert(clubProfile.includes('themeDefinition')&&clubProfile.includes('data-club-theme'),'perfil club no aplica theme_id');
assert(publicProfile.includes("type==='club'?themeDefinition(p.theme_id)"),'perfil KOMBAX club no aplica theme_id');
assert(repos.includes("app_perfil_club_publico_v061"),'repositorio no consume RPC 061');
assert(mig.includes('app_perfil_club_publico_v061')&&mig.includes("'{theme_id}'"),'migración 061 incompleta');
const cfgBuild=Number((config.match(/build:\s*(\d+)/)||[])[1]||0);
const androidBuild=Number((gradle.match(/versionCode\s+(\d+)/)||[])[1]||0);
const swBuild=Math.max(...[...sw.matchAll(/20\d{3}/g)].map(m=>Number(m[0])),0);
const indexBuild=Math.max(...[...index.matchAll(/v=(20\d{3})/g)].map(m=>Number(m[1])),0);
assert(cfgBuild>=20034&&androidBuild>=20034&&swBuild>=20034&&indexBuild>=20034,'trazabilidad 20034+ inconsistente');
console.log('KOMBAX 20034 PREMIUM NEON GLOBAL: PASS');
