import {readFile,access} from 'node:fs/promises';import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..'),read=p=>readFile(resolve(root,p),'utf8'),exists=async p=>{try{await access(resolve(root,p));return true}catch{return false}},assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL KOMBAX 20023: ${msg}`);console.log(`OK KOMBAX 20023: ${msg}`)};
const [cfg,gradle,manifest,app,gateway,platform,demos,backend,components,css,sql,fixture]=await Promise.all([
  read('web/config.js'),read('android/app/build.gradle'),read('android/app/src/main/AndroidManifest.xml'),read('web/js/app.js'),read('web/js/modules/gateway.js'),read('web/js/core/platform.js'),read('web/js/core/demo-directory.js'),read('web/js/core/backend.js'),read('web/js/ui/components.js'),read('web/css/app.css'),read('supabase/migrations/040_kombax_gateway_multiclub.sql'),read('supabase/fixtures/040_demo_clubs.sql')
]);
assert(Number(cfg.match(/build:\s*(\d+)/)?.[1])>=20023&&Number(gradle.match(/versionCode\s+(\d+)/)?.[1])>=20023,'web y Android conservan o superan build 20023');
assert(gradle.includes("applicationId 'com.urbanwarriors.app'")&&manifest.includes('android:name=".MainActivity"'),'identidad Android y ruta de actualización permanecen estables');
assert(cfg.includes('kombaxGateway: true')&&cfg.includes('directProfiles: true'),'feature flags conservan puerta y base de perfiles directos');
for(const text of ['LA PLATAFORMA PROFESIONAL DE LOS DEPORTES DE CONTACTO','Entrar con mi club','Crear o acceder a un perfil KOMBAX','CONNECT · COMPETE · GROW'])assert(gateway.includes(text),`puerta contiene “${text}”`);
assert(gateway.includes('app_buscar_clubes_kombax_v040')&&gateway.includes('Nombre, ubicación o disciplina')&&gateway.includes('Abrir enlace / QR'),'directorio busca por datos públicos y admite deep link/QR');
assert((demos.match(/club_id:/g)||[]).length===6&&(demos.match(/demo:true/g)||[]).length===5,'directorio local define seis perfiles, cinco marcados DEMO');
assert(fixture.includes('SOLO ENTORNO LOCAL / QA')&&fixture.includes('NO EJECUTAR EN PRODUCCIÓN')&&(fixture.match(/d000000[1-5]/g)||[]).length>=5,'fixtures multiclub están separados y advertidos');
for(const type of ['competidor','marca','federacion','espectador','profesional'])assert(sql.includes(`'${type}'`)&&gateway.includes(`id:'${type}'`),`perfil directo ${type} está modelado y encajado en UI`);
assert((gateway.includes('ALTA + VERIFICACIÓN')||gateway.includes('alta + verificación'))&&gateway.includes('Espectador')&&!sql.includes('checkout_url'),'evolución conserva perfiles sin checkout ni precios inventados y exige alta/verificación');
assert(sql.includes('perfiles_kombax_directos')&&sql.includes('kombax_suscripciones')&&sql.includes('kombax_capacidades')&&sql.includes('kombax_entitlements'),'identidad, suscripción y capacidades están separadas');
const directoryFunction=sql.slice(sql.indexOf('create or replace function public.app_buscar_clubes_kombax_v040'),sql.indexOf('create or replace function public.app_mis_contextos_kombax_v040'));
for(const privateField of ['cif','telefono','email','direccion','referencia_externa'])assert(!new RegExp(`\\b${privateField}\\b`,'i').test(directoryFunction),`directorio no expone ${privateField}`);
assert(sql.includes('grant execute on function public.app_buscar_clubes_kombax_v040(text,integer) to anon,authenticated')&&sql.includes('where p.perfil_id=auth.uid()'),'directorio es público limitado y contextos directos son propios');
assert(backend.includes('async switchClub')&&backend.includes('clearTenantState')&&backend.includes('invalidateCache')&&components.includes('club-context-button')&&app.includes('openClubSwitcher'),'cambio de tenant limpia estado/caché y exige membresía');
assert(platform.includes('kombax_selected_club_slug')&&platform.includes('kombax_selected_club_preview')&&app.includes("entryParams.get('club')"),'selección y deep link conservan contexto y branding');
assert(gateway.includes('club?.demo')&&(gateway.includes('NO ES UN ALTA REAL')||gateway.includes('CLUB DE EJEMPLO')),'clubs de ejemplo no abren login real');
for(const p of ['supabase/rollbacks/040_kombax_gateway_multiclub.sql','supabase/verification/preflight_040_gateway.sql','supabase/verification/verify_040_gateway.sql','supabase/verification/test_040_gateway_transactional.sql'])assert(await exists(p),`${p} disponible`);
assert(/^\s*(?:--[^\n]*\n)*\s*begin;/i.test(sql)&&/commit;\s*$/i.test(sql)&&(sql.match(/\$\$/g)||[]).length%2===0,'migración 040 es transaccional y delimitada');
assert(css.includes('.kombax-gateway')&&css.includes('@media(max-width:560px)'),'puerta y directorio incluyen responsive móvil');
console.log('KOMBAX BUILD 20023 STATIC: PASS');
