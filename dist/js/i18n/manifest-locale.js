import { getLocale, normalizeLocale } from './index.js';
const MANIFESTS=Object.freeze({
  es:'./manifest.webmanifest?v=20130-r79-i18n-completion',
  en:'./manifest-en.webmanifest?v=20130-r79-i18n-completion',
  fr:'./manifest-fr.webmanifest?v=20130-r79-i18n-completion',
  pt:'./manifest-pt.webmanifest?v=20130-r79-i18n-completion',
  it:'./manifest-it.webmanifest?v=20130-r79-i18n-completion',
  de:'./manifest-de.webmanifest?v=20130-r79-i18n-completion',
  th:'./manifest-th.webmanifest?v=20130-r79-i18n-completion',
  fil:'./manifest-fil.webmanifest?v=20130-r79-i18n-completion'
});
export function manifestForLocale(locale=getLocale()){return MANIFESTS[normalizeLocale(locale)]||MANIFESTS.es;}
export function applyManifestLocale(){
  if(typeof document==='undefined')return;
  const link=document.querySelector('link[rel="manifest"]');if(!link)return;
  const wanted=manifestForLocale();if(link.getAttribute('href')!==wanted)link.setAttribute('href',wanted);
}
applyManifestLocale();
if(typeof window!=='undefined')window.addEventListener('kombax:localechange',applyManifestLocale);
