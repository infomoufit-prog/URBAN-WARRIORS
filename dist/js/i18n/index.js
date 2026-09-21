import { resources } from './resources.js';
import { MASTER_LOCALE, FALLBACK_ORDER, SUPPORTED_LOCALES, ENABLED_LOCALES, LOCALE_METADATA, normalizeLocale, isEnabledLocale } from './locale-metadata.js';
import { resolveInitialLocale, writeLocalLocale } from './locale-storage.js';
import { formatNumber as fmtNumber,formatCurrency as fmtCurrency,formatDate as fmtDate,formatDateTime as fmtDateTime,formatPercent as fmtPercent,pluralRules as fmtPluralRules } from './formatters.js';
let currentLocale=MASTER_LOCALE;const listeners=new Set();
const readPath=(obj,path)=>String(path||'').split('.').reduce((acc,key)=>acc&&Object.prototype.hasOwnProperty.call(acc,key)?acc[key]:undefined,obj);
const interpolate=(value,vars={})=>String(value).replace(/\{\{\s*([\w.-]+)\s*\}\}/g,(_,key)=>vars[key]??'');
export function translationChain(locale=currentLocale){const selected=normalizeLocale(locale);return [...new Set([selected,'en','es'])];}
export function t(key,vars={},locale=currentLocale){for(const code of translationChain(locale)){const value=readPath(resources[code],key);if(typeof value==='string'&&value.trim())return interpolate(value,vars);}const esValue=readPath(resources.es,key);if(typeof esValue==='string'&&esValue.trim())return interpolate(esValue,vars);const safeFallback=readPath(resources.es,'errors.missingTranslation');return typeof safeFallback==='string'&&safeFallback.trim()?safeFallback:'Texto no disponible';}
export function getLocale(){return currentLocale;}
export function initializeLocale({accountLocale=null}={}){const requested=resolveInitialLocale({accountLocale});currentLocale=isEnabledLocale(requested)?requested:MASTER_LOCALE;writeLocalLocale(currentLocale);applyDocumentLocale();return currentLocale;}
export function setLocale(locale,{allowSupported=false,persist=true}={}){const next=normalizeLocale(locale);if(!allowSupported&&!ENABLED_LOCALES.includes(next))return currentLocale;if(!SUPPORTED_LOCALES.includes(next))return currentLocale;if(next===currentLocale){if(persist)writeLocalLocale(next);return next;}currentLocale=next;if(persist)writeLocalLocale(next);applyDocumentLocale();for(const fn of listeners)try{fn(next)}catch(error){console.warn('i18n listener',error)};if(typeof window!=='undefined')window.dispatchEvent(new CustomEvent('kombax:localechange',{detail:{locale:next}}));return next;}
export function subscribeLocale(fn){listeners.add(fn);return()=>listeners.delete(fn);}
export function applyDocumentLocale(){if(typeof document==='undefined')return;const meta=LOCALE_METADATA[currentLocale]||LOCALE_METADATA.es;document.documentElement.lang=currentLocale;document.documentElement.dir=meta.dir||'ltr';document.title=`KOMBAX · ${t('common.app.clubFallback')}`;}
export const formatNumber=(value,options={})=>fmtNumber(value,{locale:currentLocale,...options});
export const formatCurrency=(value,options={})=>fmtCurrency(value,{locale:currentLocale,...options});
export const formatDate=(value,options={})=>fmtDate(value,{locale:currentLocale,...options});
export const formatDateTime=(value,options={})=>fmtDateTime(value,{locale:currentLocale,...options});
export const formatPercent=(value,options={})=>fmtPercent(value,{locale:currentLocale,...options});
export const pluralRules=(options={})=>fmtPluralRules(currentLocale,options);
export const pluralCategory=(value,options={})=>fmtPluralRules(currentLocale,options).select(Number(value??0));
export { MASTER_LOCALE,FALLBACK_ORDER,SUPPORTED_LOCALES,ENABLED_LOCALES,LOCALE_METADATA,normalizeLocale };
initializeLocale();
