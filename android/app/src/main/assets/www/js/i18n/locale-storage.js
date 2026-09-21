import { MASTER_LOCALE, normalizeLocale } from './locale-metadata.js';
const STORAGE_KEY='kombax_locale';
export function readLocalLocale(){try{return normalizeLocale(localStorage.getItem(STORAGE_KEY)||'')}catch{return MASTER_LOCALE}}
export function writeLocalLocale(locale){try{localStorage.setItem(STORAGE_KEY,normalizeLocale(locale))}catch{}return normalizeLocale(locale)}
export function browserLocale(){try{return normalizeLocale(navigator.languages?.[0]||navigator.language||MASTER_LOCALE)}catch{return MASTER_LOCALE}}
export function resolveInitialLocale({accountLocale=null}={}){
  const account=String(accountLocale||'').trim();if(account)return normalizeLocale(account);
  try{const saved=localStorage.getItem(STORAGE_KEY);if(saved)return normalizeLocale(saved)}catch{}
  return browserLocale();
}
export { STORAGE_KEY };
