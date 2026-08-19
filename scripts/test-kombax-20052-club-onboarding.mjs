import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const fail=m=>{console.error('FAIL 20052 CLUB ONBOARDING:',m);process.exit(1)};
const ok=(c,m)=>{if(!c)fail(m)};
const gateway=read('web/js/modules/gateway.js');
const repos=read('web/js/core/repositories.js');
const admin=read('web/js/modules/platform-admin.js');
const migration=read('supabase/migrations/097_kombax_club_onboarding_20052.sql');
const rollback=read('supabase/rollbacks/097_kombax_club_onboarding_20052_rollback.sql');
const cfg=read('web/config.js');
const sw=read('web/service-worker.js');
const idx=read('web/index.html');
const gradle=read('android/app/build.gradle');

ok(gateway.includes("{id:'club',label:'Club',icon:'club'")&&gateway.includes("const available=directTypes.filter(x=>!x.disabled);"),'Club aparece al mismo nivel del selector oficial');
ok(gateway.includes("b.dataset.kxPick==='club'?saveAndSubmitApplication('club'")&&!gateway.includes('id="kx-new-club-application"'),'alta Club usa el selector común sin botón duplicado');
ok(gateway.includes('repos.kombaxProfiles.clubs()')&&gateway.includes('data-kx-club-enter')&&gateway.includes('data-kx-club-public')&&gateway.includes('data-kx-club-security'),'Club aprobado aparece en Mis identidades con gestión, perfil público y seguridad');
ok(gateway.includes("featureIcon('club',{size:44})"),'Club usa iconografía KOMBAX propia');
ok(gateway.includes("name:'descripcion',label:'Presentación pública'")&&gateway.includes("name:'ciudad',label:'Ciudad'")&&gateway.includes("name:'instagram',label:'Instagram público'")&&gateway.includes("name:'cif',label:'CIF / identificación fiscal · privado'"),'formulario Club prepara perfil público y datos privados separados');

ok(repos.includes("clubs:()=>backend.globalReadRpc('app_kombax_mis_clubes_v097'")&&repos.includes("createClub:(payload)=>kombaxGlobalMutation('app_kombax_platform_mutate_v097','kombax.platform.club.create'"),'repositorios conectan lectura y alta admin v097');
ok(admin.includes('id="kx-platform-create-club"')&&admin.includes("title:'Crear club KOMBAX'")&&admin.includes('Crear y activar club'),'Administrador KOMBAX dispone de + Crear club real');
ok(admin.includes('Verificar crea el Club real')&&admin.includes('provisiona el tenant'),'revisión explica el efecto real de Verificar Club');

ok(migration.includes('add column if not exists club_id uuid references public.clubes(id)'),'solicitud queda enlazada al tenant creado');
ok(migration.includes('app_kombax_create_club_core_v097')&&migration.includes('insert into public.clubes('),'provisionamiento crea public.clubes');
ok(migration.includes("values(v_club,p_manager_perfil_id,'direccion',true,true)"),'solicitante queda como Dirección/Coordinación gestora');
ok(migration.includes('update public.perfiles_club_publicos pc set')&&migration.includes('insert into public.disciplinas'),'provisionamiento completa perfil público y disciplinas');
ok(migration.includes('trg_kombax_club_application_provision_v097')&&migration.includes("new.estado='verified'")&&migration.includes('app_kombax_application_validate_v072(new.id)'),'solo aprobación verificada dispara provisionamiento validado');
ok(migration.includes("if not public.app_kombax_es_platform_admin_v055()")&&migration.includes('app_kombax_platform_mutate_v097'),'alta directa exige Administrador KOMBAX');
ok(migration.includes('revoke all on function public.app_kombax_create_club_core_v097')&&migration.includes('grant execute on function public.app_kombax_mis_clubes_v097() to authenticated')&&migration.includes('grant execute on function public.app_kombax_platform_mutate_v097(text,jsonb,uuid) to authenticated'),'RPCs internos/públicos tienen grants explícitos');
ok(rollback.includes('drop trigger if exists trg_kombax_club_application_provision_v097'),'rollback 097 incluido');

const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0),android=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),swBuild=Number(sw.match(/rc13-(\d+)/)?.[1]||0);
const refs=[...idx.matchAll(/\?v=(\d+)/g)].map(x=>Number(x[1]));
ok(build>=20052&&android===build&&swBuild===build&&refs.length>0&&refs.every(v=>v===build),'web/PWA/Android conservan build 20052 o posterior de forma coherente');
console.log('KOMBAX BUILD 20052 · Club onboarding: PASS');
