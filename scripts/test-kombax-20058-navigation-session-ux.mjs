import {readFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url);
const read=p=>readFile(new URL(p,root),'utf8');
const [app,ui,icons,css,supabase,utils,cfg,sw,index,gradle]=await Promise.all([
  read('web/js/app.js'),read('web/js/ui/components.js'),read('web/js/ui/icons.js'),read('web/css/kombax-premium.css'),
  read('web/js/core/supabase.js'),read('web/js/core/utils.js'),read('web/config.js'),read('web/service-worker.js'),read('web/index.html'),read('android/app/build.gradle')
]);
const ok=(v,m)=>{if(!v)throw new Error(m);console.log('OK '+m)};
ok(app.includes("ids.unshift('personal-profile')")&&app.includes("?'Perfil del club':LABEL[id]"),'Dirección/Coordinación separan Mi perfil personal del Perfil del club');
ok(app.includes("const ids=[profileId]")&&app.includes("ids.push('social')")&&app.includes("ids.push('showcase')")&&app.includes("label:'Mi Club'"),'navegación móvil prioriza Mi perfil, Social, Showcase y Mi Club');
ok(ui.includes('nav-section-global')&&ui.includes('club-nav-accordion')&&ui.includes('<b>Mi Club</b>'),'sidebar implementa jerarquía global + acordeón Mi Club');
ok(ui.includes("const excluded=new Set([...globalIds,'notifications','platform-admin'])"),'Notificaciones del Club salen del menú lateral sin perder su ruta');
ok(ui.includes('aria-label="Notificaciones del Club"')&&ui.includes('topbar-action-marker'),'cabecera identifica explícitamente el centro de avisos del Club');
ok(app.includes("localStorage.setItem('uw2_club_nav_open'")&&app.includes("clubNav.open=true")&&ui.includes('activeInClub'),'acordeón recuerda estado, abre Mi Club móvil y no oculta la ruta activa');
ok(icons.includes("'personal-profile':'idCard'"),'Mi perfil personal conserva iconografía específica');
ok(css.includes('20.058 · navigation hierarchy + session UX')&&css.includes('.nav-primary')&&css.includes('.club-nav-accordion')&&css.includes('.menu-toggle-dot'),'capa visual 20.058 añade jerarquía, affordance y áreas táctiles');
ok(supabase.includes('refreshFailure=')&&supabase.includes('refresh_token_not_found')&&supabase.includes('this.clear();throw new AuthExpiredError()'),'refresh token inválido limpia sesión y se convierte en expiración controlada');
ok(utils.includes("error?.code==='AUTH_EXPIRED'")&&utils.includes('Tu sesión ha caducado. Vuelve a iniciar sesión.')&&utils.includes('Comprueba tu conexión a Internet'),'errores de sesión/red se traducen a mensajes humanos');
ok(app.includes("e?.code==='AUTH_EXPIRED'")&&app.includes("toast(humanError(e),'error')"),'sesión caducada vuelve al login con mensaje humano');
ok((await read('web/js/core/backend.js')).includes('isTransientNetworkError')&&(await read('web/js/core/backend.js')).includes('persistSession(saved);return saved'),'una pérdida puntual de red conserva la sesión local en vez de expulsar al usuario');
const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]);const androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]);const swBuild=Number(sw.match(/rc13-(\d+)/)?.[1]);const refs=[...index.matchAll(/\?v=(\d+)/g)].map(x=>Number(x[1]));
ok(build>=20058&&androidBuild===build&&swBuild===build&&refs.length>0&&refs.every(v=>v===build),'web/PWA/Android conservan 20.058 y permanecen sincronizados en el build actual');
console.log('KOMBAX BUILD 20058 · Navigation + session UX: PASS');
