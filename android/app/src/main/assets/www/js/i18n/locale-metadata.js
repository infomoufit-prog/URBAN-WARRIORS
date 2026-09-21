export const MASTER_LOCALE='es';
export const FALLBACK_ORDER=Object.freeze(['selected_locale','en','es']);
export const SUPPORTED_LOCALES=Object.freeze(['es','en','fr','pt','it','de','th','fil']);
export const ENABLED_LOCALES=Object.freeze(['es','en','fr','pt','it','de','th','fil']);
export const LOCALE_METADATA=Object.freeze({
  es:{code:'es',name:'Español',nativeName:'Español',dir:'ltr'},
  en:{code:'en',name:'English',nativeName:'English',dir:'ltr'},
  fr:{code:'fr',name:'Français',nativeName:'Français',dir:'ltr'},
  pt:{code:'pt',name:'Português',nativeName:'Português',dir:'ltr'},
  it:{code:'it',name:'Italiano',nativeName:'Italiano',dir:'ltr'},
  de:{code:'de',name:'Deutsch',nativeName:'Deutsch',dir:'ltr'},
  th:{code:'th',name:'Thai',nativeName:'ไทย',dir:'ltr'},
  fil:{code:'fil',name:'Filipino',nativeName:'Filipino',dir:'ltr'}
});
export function normalizeLocale(value){
  const raw=String(value||'').trim().toLowerCase().replace('_','-');
  if(!raw)return MASTER_LOCALE;
  if(SUPPORTED_LOCALES.includes(raw))return raw;
  const base=raw.split('-')[0];
  if(base==='tl')return 'fil';
  return SUPPORTED_LOCALES.includes(base)?base:MASTER_LOCALE;
}
export const isSupportedLocale=value=>SUPPORTED_LOCALES.includes(normalizeLocale(value));
export const isEnabledLocale=value=>ENABLED_LOCALES.includes(normalizeLocale(value));
