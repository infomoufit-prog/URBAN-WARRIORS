import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RELEASE B: ${msg}`);console.log(`OK RELEASE B: ${msg}`)};
const [css,activity,html]=await Promise.all([
  read('web/css/app.css'),
  read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),
  read('web/index.html')
]);

assert(html.includes('viewport-fit=cover'),'viewport permite safe areas');
assert(css.includes('--uw-safe-top')&&css.includes('--uw-safe-bottom'),'variables compartidas superior e inferior');
assert(css.includes(".topbar{height:calc(64px + var(--uw-safe-top))"),'cabecera reserva barra de estado');
assert(css.includes(".main-view{padding-bottom:calc(104px + var(--uw-safe-bottom))"),'contenido reserva navegación inferior');
assert(css.includes(".modal-actions{padding-bottom:calc(18px + var(--uw-safe-bottom))"),'acciones de modal quedan accesibles');
assert(activity.includes('WindowInsets.Type.systemBars()')&&activity.includes('WindowInsets.Type.displayCutout()'),'Android obtiene barras y recorte');
assert(activity.includes("--uw-native-safe-top")&&activity.includes("--uw-native-safe-bottom"),'Android comunica insets al frontend');
assert(activity.includes('SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN')&&activity.includes('SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION'),'WebView usa edge-to-edge controlado');
console.log('RELEASE B SAFE AREAS: PASS');
