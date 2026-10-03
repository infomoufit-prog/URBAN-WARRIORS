export function normalizeBirthDate(value){
  const raw=String(value||'').trim();
  if(!/^\d{4}-\d{2}-\d{2}$/.test(raw))throw new Error('Indica tu fecha de nacimiento.');
  const [year,month,day]=raw.split('-').map(Number);
  const d=new Date(Date.UTC(year,month-1,day,12,0,0));
  if(d.getUTCFullYear()!==year||d.getUTCMonth()!==month-1||d.getUTCDate()!==day)throw new Error('Indica una fecha de nacimiento válida.');
  const now=new Date();
  const today=Date.UTC(now.getUTCFullYear(),now.getUTCMonth(),now.getUTCDate(),12,0,0);
  if(d.getTime()>today||year<1900)throw new Error('Indica una fecha de nacimiento válida.');
  return raw;
}

export function ageFromBirthDate(value){
  const raw=normalizeBirthDate(value);
  const [year,month,day]=raw.split('-').map(Number);
  const now=new Date();
  let age=now.getUTCFullYear()-year;
  const currentMonth=now.getUTCMonth()+1,currentDay=now.getUTCDate();
  if(currentMonth<month||(currentMonth===month&&currentDay<day))age--;
  return age;
}

export function validateBirthDate(value,{minAge=null,maxAge=125,minimumMessage=''}={}){
  const normalized=normalizeBirthDate(value);
  const age=ageFromBirthDate(normalized);
  if(Number.isFinite(Number(maxAge))&&age>Number(maxAge))throw new Error('Indica una fecha de nacimiento válida.');
  if(minAge!=null&&age<Number(minAge))throw new Error(minimumMessage||`Debes tener al menos ${Number(minAge)} años para crear esta cuenta.`);
  return {value:normalized,age};
}
