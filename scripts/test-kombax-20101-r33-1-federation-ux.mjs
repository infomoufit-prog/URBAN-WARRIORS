import {readFile,access} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(fileURLToPath(new URL('..',import.meta.url)));let pass=0;
function ok(cond,msg){if(!cond)throw new Error(`FAIL R33.1: ${msg}`);pass++;console.log(`PASS ${pass}: ${msg}`)}
async function txt(p){return readFile(resolve(root,p),'utf8')}
async function exists(p){try{await access(resolve(root,p));return true}catch{return false}}
const app=await txt('web/js/app.js');
const fed=await txt('web/js/modules/federation-licenses.js');
const hub=await txt('web/js/modules/managed-profile-hub.js');
const components=await txt('web/js/ui/components.js');
const icons=await txt('web/js/ui/icons.js');
const css=await txt('web/css/kombax-premium.css');
const index=await txt('web/index.html');
const sw=await txt('web/service-worker.js');
const migration=await txt('supabase/migrations/210_kombax_managed_profile_modules_r33_1.sql');
const plan=await txt('PLAN_IMPLEMENTACION_R33_1.md');
const pkg=JSON.parse(await txt('package.json'));

ok(await exists('PLAN_IMPLEMENTACION_R33_1.md')&&/INTEGRACIÓN UX FEDERATIVA EN TODOS LOS PERFILES/i.test(plan),'plan R33.1 documenta cierre UX transversal');
ok(/renderClubFederationAdmin/.test(app)&&/'federation-admin'/.test(app),'Mi Club tiene ruta visible a Federaciones y licencias');
ok(/'my-licenses'/.test(app)&&/renderSelfLicenses\(null/.test(app),'Mi Club/Mi Cuenta tiene ruta de Mis licencias personales');
ok(/\['direccion','coordinacion','secretaria'\]\.includes\(role\)/.test(app)&&/federation-admin/.test(app),'administración federativa del Club se limita en navegación a roles autorizados');
ok((/const accountAnchor=ids\.indexOf\('help'\);ids\.splice\([^;]+,'my-licenses'\)/.test(app)||(/id="kx-club-my-licenses"/.test(fed)&&/'my-licenses':\(\)=>renderSelfLicenses/.test(app))),'Mis licencias mantiene acceso de cuenta; R39 puede agruparlo dentro de Federaciones y licencias');
ok((/'federation-admin':'Administración'/.test(components)||/'federation-admin':'Federaciones y licencias'/.test(components))&&(/'my-licenses':'Mi cuenta'/.test(components)||/id="kx-club-my-licenses"/.test(fed)),'sidebar/área federativa mantiene agrupación coherente de licencias');
ok(/'federation-admin':'federation'/.test(icons)&&/'my-licenses':'idCard'/.test(icons),'sidebar tiene iconografía para ambos accesos');
ok(/function requiredIdentityModules/.test(hub),'hub de identidades tiene matriz UX federativa explícita');
ok(/type==='federacion'.*federation_admin.*federates.*licenses.*affiliated_clubs.*federation_team/.test(hub.replace(/\n/g,' ')),'Mi Federación expone administración, federados, licencias, clubes y equipo');
ok(/type==='competidor'.*my_licenses/.test(hub.replace(/\n/g,' ')),'Mi Competidor expone Mis licencias');
ok(/type==='profesional'.*my_licenses/.test(hub.replace(/\n/g,' ')),'Mi actividad expone sus propias licencias');
ok(/authorized_licenses.*professional\.licenses\.read_authorized/.test(hub.replace(/\n/g,' ')),'licencias de terceros en Profesional siguen condicionadas por capability');
ok(/accountLicenseTool\(type\).*federacion.*marca.*espectador/.test(hub.replace(/\n/g,' ')),'Federación, Marca y Espectador reciben herramienta de licencias personales de cuenta');
ok(/no concede permisos federativos/.test(hub),'UX aclara que Mis licencias personales no concede poderes a la identidad activa');
ok(/renderSelfLicenses\(profileId,\{onBack,embedded=false,contextLabel='MI CUENTA',subjectLabel='Mis licencias'\}/.test(fed),'renderer de licencias soporta identidad o cuenta y modo embebido');
ok(/embedded\?accountShell/.test(fed),'Mis licencias preserva el shell de Mi Club cuando se abre desde sidebar');
ok(/if\(embedded\)[\s\S]{0,300}Error al cargar licencias/.test(fed),'error de Mis licencias embebidas no destruye el shell del Club');
ok(/renderFederationAdmin\(profileId,\{onBack,focus='overview'\}/.test(fed),'Mi Federación acepta foco de navegación por módulo');
ok(/focus==='federation_team'.*kx-fed-team/.test(fed.replace(/\n/g,' '))&&/focus==='affiliated_clubs'.*kx-fed-clubs/.test(fed.replace(/\n/g,' ')),'Mi Federación enfoca Equipo o Clubes relacionados desde tarjetas');
ok(/\['federates','licenses'\]\.includes\(focus\).*kx-fed-licenses/.test(fed.replace(/\n/g,' ')),'Mi Federación enfoca Federados/Licencias desde tarjetas');
ok(/when 'federacion'.*federation_admin.*federates.*licenses.*affiliated_clubs.*federation_team/.test(migration.replace(/\n/g,' ')),'backend workspace R33.1 anuncia módulos federativos');
ok(/when 'competidor'.*my_licenses/.test(migration.replace(/\n/g,' '))&&/when 'profesional'.*my_licenses.*authorized_licenses/.test(migration.replace(/\n/g,' ')),'backend workspace anuncia licencias de Competidor y Profesional');
ok(/'version','r33\.1-v197'/.test(migration),'RPC workspace identifica versión R33.1');
ok(/revoke all on function public\.app_kombax_managed_profile_hub_v197\(uuid\) from public,anon/.test(migration)&&/grant execute .* to authenticated/.test(migration),'migración no abre RPC a anon y conserva authenticated');
ok((/20101r331/.test(index)||/historical-cache-marker:20101r331/.test(index))&&(/media-r331/.test(sw)||/historical cache marker: media-r331/.test(sw)),'cache R33.1 permanece preservada en la cadena PWA');
ok(/\.kx-managed-account-tools/.test(css),'herramienta transversal de cuenta tiene tratamiento responsive propio');
ok((pkg.scripts.test||'').includes('test-kombax-20101-r33-1-federation-ux.mjs'),'regresión completa incluye el test R33.1');
console.log(`R33.1 FEDERATION UX ALL PROFILES: PASS ${pass}/${pass}`);
