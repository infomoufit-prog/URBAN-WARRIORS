import { getLocale, normalizeLocale } from './index.js';
const MANIFESTS=Object.freeze({
  es:'./manifest.webmanifest?v=20133-r81-tap-to-pay',
  en:'./manifest-en.webmanifest?v=20133-r81-tap-to-pay',
  fr:'./manifest-fr.webmanifest?v=20133-r81-tap-to-pay',
  pt:'./manifest-pt.webmanifest?v=20133-r81-tap-to-pay',
  it:'./manifest-it.webmanifest?v=20133-r81-tap-to-pay',
  de:'./manifest-de.webmanifest?v=20133-r81-tap-to-pay',
  th:'./manifest-th.webmanifest?v=20133-r81-tap-to-pay',
  fil:'./manifest-fil.webmanifest?v=20133-r81-tap-to-pay'
});
export function manifestForLocale(locale=getLocale()){return MANIFESTS[normalizeLocale(locale)]||MANIFESTS.es;}
export function applyManifestLocale(){
  if(typeof document==='undefined')return;
  const link=document.querySelector('link[rel="manifest"]');if(!link)return;
  const wanted=manifestForLocale();if(link.getAttribute('href')!==wanted)link.setAttribute('href',wanted);
}
applyManifestLocale();
if(typeof window!=='undefined')window.addEventListener('kombax:localechange',applyManifestLocale);
