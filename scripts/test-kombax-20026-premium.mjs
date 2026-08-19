import {readFile,access,readdir} from 'node:fs/promises';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const exists=async p=>{try{await access(resolve(root,p));return true}catch{return false}};
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL KOMBAX 20026 PREMIUM: ${msg}`);console.log(`OK KOMBAX 20026 PREMIUM: ${msg}`)};
const [cfg,gradle,manifest,index,sw,pwa,css,baseCss,gateway,icons,platform,app]=await Promise.all([
  read('web/config.js'),read('android/app/build.gradle'),read('android/app/src/main/AndroidManifest.xml'),
  read('web/index.html'),read('web/service-worker.js'),read('web/manifest.webmanifest'),
  read('web/css/kombax-premium.css'),read('web/css/app.css'),read('web/js/modules/gateway.js'),
  read('web/js/ui/icons.js'),read('web/js/core/platform.js'),read('web/js/app.js')
]);
const cfgBuild=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0),androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
assert(cfgBuild>=20026&&androidBuild===cfgBuild,'web y Android conservan la foundation premium desde build 20026');
assert(gradle.includes("applicationId 'com.urbanwarriors.app'")&&manifest.includes('android:label="KOMBAX"'),'applicationId permanece intacto y launcher se presenta como KOMBAX');
assert(/"name"\s*:\s*"KOMBAX"/.test(pwa)&&/"short_name"\s*:\s*"KOMBAX"/.test(pwa),'PWA se instala con identidad KOMBAX');
assert(index.includes(`kombax-premium.css?v=${cfgBuild}`)&&index.includes('<title>KOMBAX · Deportes de contacto</title>'),'entrada carga la foundation premium versionada sin lenguaje técnico de plataforma');
assert(sw.includes(String(cfgBuild)),'service worker invalida caché para el build vigente');
for(const token of ['--kx-black:#050608','--kx-red:','--kx-red-deep:','--kx-white:#f7f7f5'])assert(css.toLowerCase().includes(token),`foundation contiene ${token}`);
assert(!/\bImpact\b/i.test(baseCss+css),'Impact deja de ser identidad tipográfica KOMBAX');
assert(css.includes('prefers-reduced-motion')&&(css+baseCss).includes('safe-area-inset-bottom'),'movimiento reducido y safe areas están contemplados');
assert(css.includes('.kombax-gateway.gateway-premium')&&css.includes('.bottom-nav')&&css.includes('.login-shell'),'gateway, navegación móvil y login tienen composición premium propia');
for(const name of ['fighter','brandMark','federation','spectator','professional','dojo','idCard','network','spotlight'])assert(icons.includes(`${name}:`)||icons.includes(`'${name}'`)||icons.includes(`case '${name}'`),`iconografía incluye ${name}`);
assert(icons.includes('featureIcon')&&icons.includes('viewBox="0 0 64 64"'),'iconos protagonistas se dibujan como SVG vectorial consistente');
assert(gateway.includes("featureIcon('club'")&&gateway.includes("featureIcon('identity'"),'puerta utiliza iconografía protagonista propia');
assert(!gateway.includes("label.slice(0,2).toUpperCase()")&&!/>\s*(CO|MA|FE|ES|PR)\s*</.test(gateway),'no usa abreviaturas provisionales como iconos de perfil');
for(const label of ['Competidor','Marca','Federación','Espectador','Profesional / Representante'])assert(gateway.includes(label),`perfil KOMBAX ${label} permanece representado`);
assert(gateway.includes('+ Solicitar perfil')&&gateway.includes("saveAndSubmitApplication('club'")&&gateway.includes('SOLICITUD DE CLUB'),'la evolución conserva alta/verificación controlada y Club dentro del selector oficial');
assert(gateway.includes('Espectador continúa cerrado')||gateway.includes('Espectador sigue desactivado'),'Espectador sigue cerrado hasta certificación');
assert(platform.includes('kombax-symbol-white.png')&&platform.includes('kombax-symbol-red.png'),'brand kit usa derivados deterministas del símbolo KOMBAX');
assert(app.includes('login-password-toggle')&&app.includes('eyeOff'),'login incorpora mostrar/ocultar contraseña accesible');
assert(app.includes('backend.signIn')&&app.includes('renderClubLogin'),'rediseño conserva flujo de autenticación existente');
for(const p of ['web/assets/icons/icon-192.png','web/assets/icons/icon-512.png','web/assets/icons/icon-maskable-512.png','android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'])assert(await exists(p),`${p} disponible`);
for(const n of [37,38,39,40,41,42]){
  const files=await readdir(resolve(root,'supabase/migrations'));
  assert(files.some(f=>f.startsWith(String(n).padStart(3,'0')+'_')),`migración ${String(n).padStart(3,'0')} sigue empaquetada`);
}
const forbidden=['.env','keystore.properties'];
for(const p of forbidden)assert(!(await exists(p)),`${p} no se incrusta en la raíz del paquete`);
console.log('KOMBAX BUILD 20026 PREMIUM STATIC: PASS');
