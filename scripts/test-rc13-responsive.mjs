import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC13 RESPONSIVE: ${msg}`);console.log(`OK RC13 RESPONSIVE: ${msg}`)};
const [css,app]=await Promise.all([read('web/css/app.css'),read('web/js/app.js')]);
assert(css.includes('@media(min-width:821px){'),'existe guardia explícita de escritorio');
const desktop=css.slice(css.lastIndexOf('@media(min-width:821px){'));
for(const token of ['.sidebar{position:sticky!important','transform:none!important','.bottom-nav{display:none!important','.table-wrap table{display:table!important','.form-grid{grid-template-columns:1fr 1fr!important'])assert(desktop.includes(token),`escritorio restaura ${token.split('{')[0]}`);
assert(css.includes('@media(max-width:820px)'),'reglas móviles continúan aisladas');
assert(css.includes('@media(min-width:821px) and (max-width:1100px){.content-shell::before{inset:0 0 0 250px}}'),'fondo escritorio compacto respeta sidebar de 250px');
assert(css.includes('@media(min-width:1101px){.content-shell::before{inset:0 0 0 280px}}'),'fondo escritorio ancho respeta sidebar de 280px');
assert(css.includes('@media(max-width:820px){.content-shell::before{inset:0}}'),'móvil elimina desplazamiento lateral del fondo');
const navBlock=app.match(/function mobileNavFor\(session\)[\s\S]*?\n}/)?.[0]||'';
for(const match of navBlock.matchAll(/ids=\[([^\]]+)\]/g)){
  const count=(match[1].match(/'/g)||[]).length/2;
  assert(count<=5,`navegación móvil no supera cinco accesos (${count})`);
}
// Sanidad estructural CSS: ignora llaves dentro de data URIs/cadenas (no presentes en el bloque añadido).
const opens=(css.match(/\{/g)||[]).length,closes=(css.match(/\}/g)||[]).length;
assert(opens===closes,`CSS mantiene llaves equilibradas (${opens}/${closes})`);
console.log('RC13 RESPONSIVE DESKTOP/MOBILE: PASS');
