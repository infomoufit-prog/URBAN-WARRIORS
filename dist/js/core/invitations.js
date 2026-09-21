const cfg=window.UW_CONFIG||{};

export const TEAM_INVITE_ROLES=[
  {value:'coordinacion',label:'Coordinación'},
  {value:'secretaria',label:'Secretaría'},
  {value:'economia',label:'Economía / Tesorería'},
  {value:'comunicacion',label:'Comunicación'},
  {value:'monitor',label:'Monitor'}
];

export function teamInviteRoleLabel(role=''){
  return TEAM_INVITE_ROLES.find(x=>x.value===String(role||'').toLowerCase())?.label||'Miembro del equipo';
}

export function clubInviteUrl({clubSlug='',type='',code='',role=''}){
  const base=String(cfg.release?.webUrl||'').replace(/\/+$/,'');
  if(!base)return '';
  const params=new URLSearchParams();
  if(clubSlug)params.set('club',clubSlug);
  if(type)params.set('access_type',type);
  if(code)params.set('access_code',code);
  if(role)params.set('team_role',role);
  return `${base}/?${params.toString()}`;
}

export function studentInviteText({clubName='Tu club',code=''}){
  return `${clubName} te invita a unirte a KOMBAX como alumno/a o familia. Código de acceso: ${code}. Abre KOMBAX, selecciona el club y usa “Tengo código del club”.`;
}

export function teamInviteText({clubName='Tu club',code='',role=''}){
  const label=teamInviteRoleLabel(role);
  return `${clubName} te invita a solicitar acceso a su equipo como ${label}. Código de equipo: ${code}. El acceso queda pendiente de aprobación del Gestor del club.`;
}

export async function copyInvitation(text,url=''){
  const payload=[String(text||'').trim(),String(url||'').trim()].filter(Boolean).join('\n');
  if(!payload)return false;
  if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(payload);return true;}
  window.prompt('Copia la invitación',payload);
  return true;
}

export async function shareInvitation({title='KOMBAX',text='',url=''}){
  if(navigator.share){
    try{await navigator.share({title,text,url:url||undefined});return 'shared';}
    catch(error){if(error?.name==='AbortError')return 'cancelled';throw error;}
  }
  await copyInvitation(text,url);
  return 'copied';
}
