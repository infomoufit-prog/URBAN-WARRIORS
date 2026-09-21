import { getLocale as kxGetLocale } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
const n=v=>Number(v||0);
export const FINANCE_SCOPE={CLUB:'club',PROFESSIONAL:'professional'};
export function financeMoney(value,currency='EUR'){
  try{return new Intl.NumberFormat(kxLocaleTag(kxGetLocale()),{style:'currency',currency:currency||'EUR',maximumFractionDigits:2}).format(n(value));}
  catch{return `${n(value).toFixed(2)} ${currency||'EUR'}`;}
}
export function normalizeProfessionalFinance(snapshot={},notifications=[]){
  const k=snapshot?.kpis||{};
  const charges=Array.isArray(snapshot?.charges)?snapshot.charges:[];
  return {
    scope:FINANCE_SCOPE.PROFESSIONAL,
    profileId:snapshot?.profile_id||null,
    flags:{processesMoney:false,fiscalInvoicing:false,fakeClub:false,...(snapshot?.flags||{})},
    kpis:{generated:n(k.generated),collected:n(k.collected),pending:n(k.pending),expenses:n(k.expenses),net:n(k.net)},
    services:Array.isArray(snapshot?.services)?snapshot.services:[],
    charges:charges.map(c=>({...c,importe:n(c.importe),pagado:n(c.pagado),saldo:n(c.saldo)})),
    payments:(Array.isArray(snapshot?.payments)?snapshot.payments:[]).map(p=>({...p,importe:n(p.importe)})),
    expenses:(Array.isArray(snapshot?.expenses)?snapshot.expenses:[]).map(e=>({...e,importe:n(e.importe)})),
    monthly:(Array.isArray(snapshot?.monthly)?snapshot.monthly:[]).map(m=>({...m,generated:n(m.generated),collected:n(m.collected),expenses:n(m.expenses),net:n(m.net)})),
    reminders:Array.isArray(snapshot?.reminders)?snapshot.reminders:[],
    notifications:Array.isArray(notifications)?notifications:[],
    raw:snapshot
  };
}
export function chargeCanReceivePayment(charge){return charge&&charge.estado!=='anulado'&&n(charge.saldo)>0;}
export function chargeCanCancel(charge){return charge&&charge.estado!=='anulado'&&n(charge.pagado)===0;}
