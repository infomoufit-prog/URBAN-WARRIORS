import { normalizeLocale } from './locale-metadata.js';
const localeTag=locale=>({es:'es-ES',en:'en',fr:'fr-FR',pt:'pt-PT',it:'it-IT',de:'de-DE',th:'th-TH',fil:'fil-PH'})[normalizeLocale(locale)]||normalizeLocale(locale);
export function formatNumber(value,{locale='es',...options}={}){return new Intl.NumberFormat(localeTag(locale),options).format(Number(value??0));}
export function formatCurrency(value,{locale='es',currency='EUR',...options}={}){return new Intl.NumberFormat(localeTag(locale),{style:'currency',currency,...options}).format(Number(value??0));}
export function formatDate(value,{locale='es',...options}={}){if(!value)return '—';const d=value instanceof Date?value:new Date(String(value).length<=10?`${String(value).slice(0,10)}T12:00:00`:value);return new Intl.DateTimeFormat(localeTag(locale),options).format(d);}
export function formatDateTime(value,{locale='es',...options}={}){if(!value)return '—';return new Intl.DateTimeFormat(localeTag(locale),{dateStyle:'short',timeStyle:'short',...options}).format(new Date(value));}
export function formatPercent(value,{locale='es',maximumFractionDigits=1,...options}={}){return new Intl.NumberFormat(localeTag(locale),{style:'percent',maximumFractionDigits,...options}).format(Number(value??0));}
export function pluralRules(locale='es',options={}){return new Intl.PluralRules(localeTag(locale),options);}
export { localeTag };
