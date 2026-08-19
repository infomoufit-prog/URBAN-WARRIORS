import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
const root=resolve(new URL('..',import.meta.url).pathname);
const read=p=>readFileSync(resolve(root,p),'utf8');
const must=(ok,msg)=>{if(!ok)throw new Error(`20042: ${msg}`)};
const gateway=read('web/js/modules/gateway.js'),premium=read('web/css/kombax-premium.css'),config=read('web/config.js'),platform=read('web/js/core/platform.js'),index=read('web/index.html'),sw=read('web/service-worker.js'),gradle=read('android/app/build.gradle');

const configBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0);
const versionCode=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
must(configBuild>=20042,'config es anterior a build 20042');
must(versionCode>=20042,'Android versionCode es anterior a 20042');
must(index.includes(`v=${configBuild}`),'cache-busting web no coincide con el build actual');
must(sw.includes(String(configBuild)),'service worker no coincide con el build actual');

// Branding source: reutiliza el símbolo oficial ya existente y no incrusta la imagen de referencia externa.
must(platform.includes("symbolRed:'./assets/brand/kombax-symbol-red.png'"),'falta asset oficial rojo de KOMBAX');
must(gateway.includes('gateway-brand-watermark')&&gateway.includes('KOMBAX_BRAND.symbolRed'),'gateway no monta la marca ambiental oficial');
must(gateway.includes('gateway-brand-stage'),'hero no activa el escenario de marca');
must(gateway.includes('gateway-brand-watermark-word')&&gateway.includes('gateway-brand-watermark-tagline'),'falta wordmark/tagline ambiental');

// Jerarquía y accesibilidad: el fondo es decorativo, no roba interacción.
must(/gateway-brand-watermark[^>]*aria-hidden="true"/.test(gateway),'marca de fondo no está ocultada a lectores de pantalla');
must(/\.gateway-brand-watermark\{[^}]*pointer-events:none/i.test(premium),'marca de fondo podría interceptar interacción');
must(/\.gateway-brand-stage>:not\(\.gateway-brand-watermark\)\{[^}]*z-index:2/i.test(premium),'contenido interactivo no está por encima del fondo');

// Desktop/PWA: marca fuerte y logo de esquina ampliado.
must(/@media\(min-width:901px\)[\s\S]*?\.gateway-brand-symbol\{width:60px;height:60px/i.test(premium),'logo desktop no aumenta de tamaño');
must(/@media\(min-width:901px\)[\s\S]*?\.gateway-brand img\{width:42px;height:42px/i.test(premium),'símbolo desktop no aumenta de tamaño');
must(/\.gateway-brand-watermark\{[^}]*width:clamp\(330px,43vw,610px\)/i.test(premium),'watermark desktop no tiene escala editorial');

// Tablet/móvil: adaptación específica, no mera reducción del desktop.
must(/@media\(max-width:900px\)[\s\S]*?\.gateway-brand-watermark\{[^}]*opacity:\.135/i.test(premium),'tablet no reduce presencia de marca');
must(/@media\(max-width:620px\)[\s\S]*?\.gateway-brand-watermark-word,\.gateway-brand-watermark-tagline\{display:none\}/i.test(premium),'móvil no oculta wordmark gigante');
must(/@media\(max-width:620px\)[\s\S]*?\.gateway-brand-watermark\{[^}]*opacity:\.10/i.test(premium),'móvil no suaviza símbolo ambiental');

// Las dos rutas de acceso siguen intactas.
must(gateway.includes('id="gateway-club"')&&gateway.includes('Entrar con mi club'),'se perdió acceso por club');
must(gateway.includes('id="gateway-direct"')&&gateway.includes('Crear o acceder a un perfil KOMBAX'),'se perdió acceso por identidad KOMBAX');

console.log('KOMBAX BUILD 20042 GATEWAY BRAND STAGE: PASS');
