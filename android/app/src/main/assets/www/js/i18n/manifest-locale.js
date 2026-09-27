import { getLocale, normalizeLocale } from './index.js';
const MANIFESTS=Object.freeze({
  es:'./manifest.webmanifest?v=20150-r89-inventory-lifecycle',
  en:'./manifest-en.webmanifest?v=20150-r89-inventory-lifecycle',
  fr:'./manifest-fr.webmanifest?v=20150-r89-inventory-lifecycle',
  pt:'./manifest-pt.webmanifest?v=20150-r89-inventory-lifecycle',
  it:'./manifest-it.webmanifest?v=20150-r89-inventory-lifecycle',
  de:'./manifest-de.webmanifest?v=20150-r89-inventory-lifecycle',
  th:'./manifest-th.webmanifest?v=20150-r89-inventory-lifecycle',
  fil:'./manifest-fil.webmanifest?v=20150-r89-inventory-lifecycle'
});
export function manifestForLocale(locale=getLocale()){return MANIFESTS[normalizeLocale(locale)]||MANIFESTS.es;}
export function applyManifestLocale(){
  if(typeof document==='undefined')return;
  const link=document.querySelector('link[rel="manifest"]');if(!link)return;
  const wanted=manifestForLocale();if(link.getAttribute('href')!==wanted)link.setAttribute('href',wanted);
}
applyManifestLocale();
if(typeof window!=='undefined')window.addEventListener('kombax:localechange',applyManifestLocale);
