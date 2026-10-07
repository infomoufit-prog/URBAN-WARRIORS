import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS={'access-control-allow-origin':'*','access-control-allow-headers':'authorization, x-client-info, apikey, content-type','access-control-allow-methods':'POST, OPTIONS'};
const json=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:{...CORS,'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}});
const esc=(value:unknown)=>String(value??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[c]||c));
const clubRoleLabel=(role:string)=>({coordinacion:'Coordinación',secretaria:'Secretaría',economia:'Economía / Tesorería',comunicacion:'Comunicación',monitor:'Monitor'} as Record<string,string>)[role]||'Miembro del equipo';
const federationRoleLabel=(role:string)=>({presidencia:'Presidencia',secretaria:'Secretaría',tesoreria:'Tesorería',coordinacion:'Coordinación',junta_directiva:'Junta directiva',colaborador:'Colaborador/a'} as Record<string,string>)[role]||'Miembro del equipo federativo';

async function callerRpc(base:string,key:string,bearer:string,name:string,payload:Record<string,unknown>){
  const r=await fetch(`${base}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:key,authorization:bearer,'content-type':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(7000)});
  const text=await r.text();let data:any=null;try{data=text?JSON.parse(text):null}catch{data=text}
  if(!r.ok)throw new Error(typeof data==='object'&&data?.message?String(data.message):`RPC ${name} ${r.status}`);
  return data;
}

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:CORS});
  if(req.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  const bearer=req.headers.get('authorization')||'';
  if(!bearer.toLowerCase().startsWith('bearer '))return json(401,{ok:false,error:'auth_required'});
  let body:any={};try{body=await req.json()}catch{return json(400,{ok:false,error:'invalid_json'})}
  const clubInvitationId=String(body?.invitation_id||'').trim();
  const federationInvitationId=String(body?.federation_invitation_id||'').trim();
  const isFederation=Boolean(federationInvitationId);
  const invitationId=isFederation?federationInvitationId:clubInvitationId;
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(invitationId))return json(400,{ok:false,error:'invalid_invitation_id'});

  const base=(Deno.env.get('SUPABASE_URL')||'').replace(/\/+$/,'');
  const key=Deno.env.get('SUPABASE_ANON_KEY')||'';
  const resend=Deno.env.get('RESEND_API_KEY')||'';
  const from=Deno.env.get('KOMBAX_INVITE_FROM')||'KOMBAX <no-reply@kombax.es>';
  const web=(Deno.env.get('KOMBAX_WEB_URL')||'https://kombax.es').replace(/\/+$/,'');
  if(!base||!key)return json(503,{ok:false,error:'backend_not_configured'});

  let invite:any;
  try{
    invite=isFederation
      ?await callerRpc(base,key,bearer,'app_kombax_federation_invitation_email_payload_v200',{p_invitation_id:invitationId})
      :await callerRpc(base,key,bearer,'app_kombax_invitacion_email_payload_v059',{p_invitacion_id:invitationId});
  }catch(error){return json(403,{ok:false,error:'invite_not_authorized'})}
  const inviteType=String(invite?.tipo||'');
  if(!invite||invite.estado!=='pendiente'||!['equipo','alumno','federation_team'].includes(inviteType))return json(409,{ok:false,error:'invite_not_pending'});
  const updateEmailState=async(status:string,error:string|null)=>isFederation
    ?callerRpc(base,key,bearer,'app_kombax_federation_invitation_email_state_v200',{p_invitation_id:invitationId,p_status:status,p_error:error})
    :callerRpc(base,key,bearer,'app_kombax_invitacion_email_estado_v059',{p_invitacion_id:invitationId,p_estado:status==='sent'?'enviado':status==='error'?'error':'pendiente',p_error:error});
  if(!resend){await updateEmailState('pending','RESEND_API_KEY no configurada').catch(()=>{});return json(503,{ok:false,error:'email_not_configured'});}

  const name=String(invite.nombre||'').trim();
  const greeting=name?`Hola ${esc(name)},`:'Hola,';
  let url='',subject='',heading='',invitationCopy='',bindingCopy='',footer='',label='';
  if(inviteType==='federation_team'){
    label=federationRoleLabel(String(invite.rol||''));
    const params=new URLSearchParams({federation_invite:String(invite.codigo||'')});
    url=`${web}/?${params.toString()}`;
    subject=`${String(invite.federation_name||'Tu Federación')} te invita a su equipo en KOMBAX`;
    heading='Te han invitado al equipo federativo';
    invitationCopy=`<strong style="color:#fff">${esc(invite.federation_name||'Tu Federación')}</strong> te invita a formar parte de su equipo como <strong style="color:#fff">${esc(label)}</strong>.`;
    bindingCopy='La invitación está vinculada a este mismo correo. Inicia sesión o crea tu cuenta KOMBAX con este correo y la invitación aparecerá en Mi Cuenta KOMBAX para que puedas aceptarla o rechazarla.';
    footer='KOMBAX · Acceso seguro al equipo federativo';
  }else{
    const params=new URLSearchParams({club:String(invite.club_slug||''),access_type:inviteType==='equipo'?'equipo':'alumnos',access_code:String(invite.codigo||'')});
    if(inviteType==='equipo')params.set('team_role',String(invite.rol||''));
    url=`${web}/?${params.toString()}`;
    label=clubRoleLabel(String(invite.rol||''));
    subject=`${String(invite.club_nombre||'Tu club')} te invita a KOMBAX`;
    heading=inviteType==='equipo'?'Te han invitado al equipo':'Te han invitado al club';
    invitationCopy=inviteType==='equipo'?`<strong style="color:#fff">${esc(invite.club_nombre||'Tu club')}</strong> te invita a acceder a su equipo como <strong style="color:#fff">${esc(label)}</strong>.`:`<strong style="color:#fff">${esc(invite.club_nombre||'Tu club')}</strong> te invita a unirte a KOMBAX como alumno/a o familia. Si el alumno es menor de 16 años, la cuenta debe crearla su padre, madre o tutor.`;
    bindingCopy=inviteType==='equipo'?'La invitación ya define el rol aprobado por el club. KOMBAX comprobará que accedes con este mismo correo antes de activar el acceso.':'KOMBAX comprobará que el registro se realiza con este mismo correo antes de aceptar la invitación. El código es personal, caduca y solo puede utilizarse una vez.';
    footer=inviteType==='equipo'?'KOMBAX · Acceso seguro al equipo':'KOMBAX · Invitación segura de alumno o familia';
  }

  const html=`<!doctype html><html><body style="margin:0;background:#0b0b0d;color:#f5f5f7;font-family:Arial,Helvetica,sans-serif"><div style="max-width:620px;margin:0 auto;padding:32px 18px"><div style="font-size:13px;letter-spacing:.22em;font-weight:800;color:#e10600;margin-bottom:14px">KOMBAX</div><div style="background:#141416;border:1px solid #2b2b30;border-top:3px solid #e10600;border-radius:18px;padding:28px"><h1 style="font-size:28px;line-height:1.15;margin:0 0 18px">${heading}</h1><p style="color:#c9c9ce;line-height:1.65">${greeting}</p><p style="color:#c9c9ce;line-height:1.65">${invitationCopy}</p><p style="color:#c9c9ce;line-height:1.65">Esta invitación es personal y está vinculada a <strong style="color:#fff">${esc(invite.email)}</strong>. ${bindingCopy}</p><div style="margin:26px 0"><a href="${esc(url)}" style="display:inline-block;background:#e10600;color:#fff;text-decoration:none;font-weight:800;padding:14px 20px;border-radius:12px">Revisar invitación</a></div><div style="background:#0e0e10;border:1px solid #2a2a2e;border-radius:14px;padding:18px;text-align:center"><div style="font-size:12px;color:#8f8f98;letter-spacing:.12em;text-transform:uppercase">Código personal</div><div style="font-size:24px;font-weight:900;letter-spacing:.08em;margin-top:8px">${esc(invite.codigo)}</div></div><p style="font-size:13px;color:#92929a;line-height:1.55;margin-top:22px">No reenvíes este correo ni compartas el código. Si no esperabas esta invitación, puedes ignorar el mensaje.</p></div><p style="font-size:12px;color:#72727a;text-align:center;line-height:1.5;margin:18px 0 0">${footer}</p></div></body></html>`;
  const text=inviteType==='federation_team'
    ?[`${name?`Hola ${name}`:'Hola'},`,`${invite.federation_name||'Tu Federación'} te invita a su equipo como ${label}.`,`Esta invitación está vinculada a ${invite.email}.`,`Código personal: ${invite.codigo}`,`Abrir KOMBAX: ${url}`,'Inicia sesión o crea tu cuenta con este mismo correo. La invitación aparecerá en Mi Cuenta KOMBAX.','No compartas este código.'].join('\n\n')
    :inviteType==='equipo'
      ?[`${name?`Hola ${name}`:'Hola'},`,`${invite.club_nombre||'Tu club'} te invita a acceder a su equipo como ${label}.`,`Esta invitación está vinculada a ${invite.email}.`,`Código personal: ${invite.codigo}`,`Abrir invitación: ${url}`,'No compartas este código.'].join('\n\n')
      :[`${name?`Hola ${name}`:'Hola'},`,`${invite.club_nombre||'Tu club'} te invita a unirte a KOMBAX como alumno/a o familia.`,`Esta invitación está vinculada a ${invite.email}.`,`Código personal: ${invite.codigo}`,`Abrir invitación: ${url}`,'Si el alumno es menor de 16 años, debe completar el alta su padre, madre o tutor.','No compartas este código.'].join('\n\n');

  try{
    const r=await fetch('https://api.resend.com/emails',{method:'POST',headers:{authorization:`Bearer ${resend}`,'content-type':'application/json'},body:JSON.stringify({from,to:[invite.email],subject,html,text}),signal:AbortSignal.timeout(12000)});
    const out=await r.json().catch(()=>({}));if(!r.ok)throw new Error(JSON.stringify(out));
    await updateEmailState('sent',null);
    return json(200,{ok:true,invitation_id:invitationId,email:invite.email,status:'sent',provider_id:out?.id||null,type:inviteType});
  }catch(error){
    const message=(error instanceof Error?error.message:String(error)).slice(0,900);
    await updateEmailState('error',message).catch(()=>{});
    return json(502,{ok:false,error:'email_send_failed'});
  }
});
