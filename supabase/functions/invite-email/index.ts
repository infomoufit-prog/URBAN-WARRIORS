import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS={'access-control-allow-origin':'*','access-control-allow-headers':'authorization, x-client-info, apikey, content-type','access-control-allow-methods':'POST, OPTIONS'};
const json=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:{...CORS,'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}});
const esc=(value:unknown)=>String(value??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[c]||c));
const SUPPORTED_LOCALES=new Set(['es','en','fr','pt','it','de','th','fil']);
function normalizeLocale(value:unknown){const raw=String(value||'').trim().toLowerCase().replace('_','-');const base=raw.split('-')[0];return SUPPORTED_LOCALES.has(raw)?raw:SUPPORTED_LOCALES.has(base)?base:'es';}
const COPY:Record<string,any>={
 es:{hello:'Hola',review:'Revisar invitación',personal:'Código personal',personalNotice:'No reenvíes este correo ni compartas el código. Si no esperabas esta invitación, puedes ignorar el mensaje.',sameEmail:'Esta invitación es personal y está vinculada a',federationHeading:'Te han invitado al equipo federativo',teamHeading:'Te han invitado al equipo',clubHeading:'Te han invitado al club',federationSubject:'te invita a su equipo en KOMBAX',clubSubject:'te invita a KOMBAX',federationInvite:'te invita a formar parte de su equipo como',teamInvite:'te invita a acceder a su equipo como',studentInvite:'te invita a unirte a KOMBAX como alumno/a o familia. Si el alumno es menor de 16 años, la cuenta debe crearla su padre, madre o tutor.',federationBinding:'Inicia sesión o crea tu cuenta KOMBAX con este mismo correo y la invitación aparecerá en Mi Cuenta KOMBAX para que puedas aceptarla o rechazarla.',teamBinding:'La invitación ya define el rol aprobado por el club. KOMBAX comprobará que accedes con este mismo correo antes de activar el acceso.',studentBinding:'KOMBAX comprobará que el registro se realiza con este mismo correo antes de aceptar la invitación. El código es personal, caduca y solo puede utilizarse una vez.',federationFooter:'KOMBAX · Acceso seguro al equipo federativo',teamFooter:'KOMBAX · Acceso seguro al equipo',studentFooter:'KOMBAX · Invitación segura de alumno o familia'},
 en:{hello:'Hello',review:'Review invitation',personal:'Personal code',personalNotice:'Do not share this code. It expires and can only be used once.',sameEmail:'This invitation is personal and linked to',federationHeading:'You have been invited to the federation team',teamHeading:'You have been invited to the team',clubHeading:'You have been invited to the club',federationSubject:'invites you to its team on KOMBAX',clubSubject:'invites you to KOMBAX',federationInvite:'invites you to join its team as',teamInvite:'invites you to access its team as',studentInvite:'invites you to join KOMBAX as a student or family member. If the student is under 16, the account must be created by a parent or authorized guardian.',federationBinding:'Sign in or create your KOMBAX account with this same email. The invitation will appear in My KOMBAX Account so you can accept or decline it.',teamBinding:'The invitation already defines the role approved by the club. KOMBAX will verify that you sign in with this same email before enabling access.',studentBinding:'KOMBAX will verify that registration uses this same email before accepting the invitation. The code is personal, expires and can only be used once.',federationFooter:'KOMBAX · Secure federation team access',teamFooter:'KOMBAX · Secure team access',studentFooter:'KOMBAX · Secure student or family invitation'},
 fr:{hello:'Bonjour',review:"Examiner l’invitation",personal:'Code personnel',personalNotice:'Ne partagez pas ce code. Il expire et ne peut être utilisé qu’une seule fois.',sameEmail:'Cette invitation est personnelle et liée à',federationHeading:"Vous êtes invité(e) dans l’équipe de la fédération",teamHeading:"Vous êtes invité(e) dans l’équipe",clubHeading:'Vous êtes invité(e) au club',federationSubject:'vous invite dans son équipe sur KOMBAX',clubSubject:'vous invite sur KOMBAX',federationInvite:'vous invite à rejoindre son équipe en tant que',teamInvite:'vous invite à accéder à son équipe en tant que',studentInvite:'vous invite à rejoindre KOMBAX comme élève ou famille. Si l’élève a moins de 16 ans, le compte doit être créé par un parent ou tuteur autorisé.',federationBinding:'Connectez-vous ou créez votre compte KOMBAX avec cette même adresse e-mail. L’invitation apparaîtra dans Mon compte KOMBAX.',teamBinding:'L’invitation définit déjà le rôle approuvé par le club. KOMBAX vérifiera que vous utilisez cette même adresse e-mail avant d’activer l’accès.',studentBinding:'KOMBAX vérifiera que l’inscription est effectuée avec cette même adresse e-mail. Le code est personnel, expire et ne peut être utilisé qu’une fois.',federationFooter:'KOMBAX · Accès sécurisé à l’équipe fédérale',teamFooter:"KOMBAX · Accès sécurisé à l’équipe",studentFooter:'KOMBAX · Invitation sécurisée élève ou famille'},
 pt:{hello:'Olá',review:'Rever convite',personal:'Código pessoal',personalNotice:'Não partilhe este código. Expira e só pode ser utilizado uma vez.',sameEmail:'Este convite é pessoal e está associado a',federationHeading:'Foi convidado para a equipa da federação',teamHeading:'Foi convidado para a equipa',clubHeading:'Foi convidado para o clube',federationSubject:'convida-o para a sua equipa no KOMBAX',clubSubject:'convida-o para o KOMBAX',federationInvite:'convida-o a integrar a sua equipa como',teamInvite:'convida-o a aceder à sua equipa como',studentInvite:'convida-o a juntar-se ao KOMBAX como aluno ou família. Se o aluno tiver menos de 16 anos, a conta deve ser criada por um progenitor ou tutor autorizado.',federationBinding:'Inicie sessão ou crie a sua conta KOMBAX com este mesmo e-mail. O convite aparecerá em A minha conta KOMBAX.',teamBinding:'O convite já define o papel aprovado pelo clube. O KOMBAX verificará este mesmo e-mail antes de ativar o acesso.',studentBinding:'O KOMBAX verificará que o registo é efetuado com este mesmo e-mail. O código é pessoal, expira e só pode ser utilizado uma vez.',federationFooter:'KOMBAX · Acesso seguro à equipa federativa',teamFooter:'KOMBAX · Acesso seguro à equipa',studentFooter:'KOMBAX · Convite seguro de aluno ou família'},
 it:{hello:'Ciao',review:'Esamina invito',personal:'Codice personale',personalNotice:'Non condividere questo codice. Scade e può essere utilizzato una sola volta.',sameEmail:'Questo invito è personale ed è collegato a',federationHeading:'Sei stato invitato nel team della federazione',teamHeading:'Sei stato invitato nel team',clubHeading:'Sei stato invitato nel club',federationSubject:'ti invita nel suo team su KOMBAX',clubSubject:'ti invita su KOMBAX',federationInvite:'ti invita a far parte del suo team come',teamInvite:'ti invita ad accedere al suo team come',studentInvite:'ti invita a unirti a KOMBAX come allievo o famiglia. Se l’allievo ha meno di 16 anni, l’account deve essere creato da un genitore o tutore autorizzato.',federationBinding:'Accedi o crea il tuo account KOMBAX con questa stessa e-mail. L’invito comparirà in Il mio account KOMBAX.',teamBinding:'L’invito definisce già il ruolo approvato dal club. KOMBAX verificherà questa stessa e-mail prima di attivare l’accesso.',studentBinding:'KOMBAX verificherà che la registrazione usi questa stessa e-mail. Il codice è personale, scade e può essere usato una sola volta.',federationFooter:'KOMBAX · Accesso sicuro al team federale',teamFooter:'KOMBAX · Accesso sicuro al team',studentFooter:'KOMBAX · Invito sicuro per allievo o famiglia'},
 de:{hello:'Hallo',review:'Einladung prüfen',personal:'Persönlicher Code',personalNotice:'Teile diesen Code nicht. Er läuft ab und kann nur einmal verwendet werden.',sameEmail:'Diese Einladung ist persönlich und verknüpft mit',federationHeading:'Du wurdest in das Verbandsteam eingeladen',teamHeading:'Du wurdest in das Team eingeladen',clubHeading:'Du wurdest in den Club eingeladen',federationSubject:'lädt dich in sein Team auf KOMBAX ein',clubSubject:'lädt dich zu KOMBAX ein',federationInvite:'lädt dich ein, dem Team beizutreten als',teamInvite:'lädt dich ein, auf das Team zuzugreifen als',studentInvite:'lädt dich ein, KOMBAX als Schüler/in oder Familie beizutreten. Ist der Schüler unter 16, muss das Konto von einem Elternteil oder autorisierten Vormund erstellt werden.',federationBinding:'Melde dich mit derselben E-Mail bei KOMBAX an oder erstelle dein Konto. Die Einladung erscheint in Mein KOMBAX-Konto.',teamBinding:'Die Einladung enthält bereits die vom Club genehmigte Rolle. KOMBAX prüft dieselbe E-Mail, bevor der Zugang aktiviert wird.',studentBinding:'KOMBAX prüft, dass die Registrierung mit derselben E-Mail erfolgt. Der Code ist persönlich, läuft ab und kann nur einmal verwendet werden.',federationFooter:'KOMBAX · Sicherer Zugang zum Verbandsteam',teamFooter:'KOMBAX · Sicherer Teamzugang',studentFooter:'KOMBAX · Sichere Einladung für Schüler oder Familie'},
 th:{hello:'สวัสดี',review:'ตรวจสอบคำเชิญ',personal:'รหัสส่วนบุคคล',personalNotice:'อย่าแชร์รหัสนี้ รหัสจะหมดอายุและใช้ได้เพียงครั้งเดียว',sameEmail:'คำเชิญนี้เป็นคำเชิญส่วนบุคคลและเชื่อมโยงกับ',federationHeading:'คุณได้รับเชิญเข้าสู่ทีมสหพันธ์',teamHeading:'คุณได้รับเชิญเข้าสู่ทีม',clubHeading:'คุณได้รับเชิญเข้าสู่สโมสร',federationSubject:'เชิญคุณเข้าร่วมทีมบน KOMBAX',clubSubject:'เชิญคุณเข้าร่วม KOMBAX',federationInvite:'เชิญคุณเข้าร่วมทีมในบทบาท',teamInvite:'เชิญคุณเข้าถึงทีมในบทบาท',studentInvite:'เชิญคุณเข้าร่วม KOMBAX ในฐานะนักเรียนหรือครอบครัว หากนักเรียนอายุต่ำกว่า 16 ปี บัญชีต้องสร้างโดยผู้ปกครองหรือผู้ดูแลที่ได้รับอนุญาต',federationBinding:'ลงชื่อเข้าใช้หรือสร้างบัญชี KOMBAX ด้วยอีเมลเดียวกัน คำเชิญจะปรากฏในบัญชี KOMBAX ของฉัน',teamBinding:'คำเชิญกำหนดบทบาทที่สโมสรอนุมัติไว้แล้ว KOMBAX จะตรวจสอบอีเมลเดียวกันก่อนเปิดใช้งานการเข้าถึง',studentBinding:'KOMBAX จะตรวจสอบว่าการลงทะเบียนใช้อีเมลเดียวกัน รหัสเป็นรหัสส่วนบุคคล มีวันหมดอายุ และใช้ได้เพียงครั้งเดียว',federationFooter:'KOMBAX · การเข้าถึงทีมสหพันธ์อย่างปลอดภัย',teamFooter:'KOMBAX · การเข้าถึงทีมอย่างปลอดภัย',studentFooter:'KOMBAX · คำเชิญนักเรียนหรือครอบครัวอย่างปลอดภัย'},
 fil:{hello:'Kumusta',review:'Suriin ang imbitasyon',personal:'Personal na code',personalNotice:'Huwag ibahagi ang code na ito. Nag-e-expire ito at isang beses lang magagamit.',sameEmail:'Personal ang imbitasyong ito at naka-link sa',federationHeading:'Inimbitahan ka sa federation team',teamHeading:'Inimbitahan ka sa team',clubHeading:'Inimbitahan ka sa club',federationSubject:'ay nag-iimbita sa iyo sa team nito sa KOMBAX',clubSubject:'ay nag-iimbita sa iyo sa KOMBAX',federationInvite:'ay nag-iimbita sa iyo na sumali sa team bilang',teamInvite:'ay nag-iimbita sa iyo na i-access ang team bilang',studentInvite:'ay nag-iimbita sa iyo na sumali sa KOMBAX bilang mag-aaral o pamilya. Kung wala pang 16 taong gulang ang mag-aaral, dapat gawin ng magulang o awtorisadong guardian ang account.',federationBinding:'Mag-sign in o gumawa ng KOMBAX account gamit ang parehong email. Lalabas ang imbitasyon sa My KOMBAX Account.',teamBinding:'Nakatakda na sa imbitasyon ang role na inaprubahan ng club. Ive-verify ng KOMBAX ang parehong email bago i-activate ang access.',studentBinding:'Ive-verify ng KOMBAX na parehong email ang gamit sa registration. Personal ang code, nag-e-expire at isang beses lang magagamit.',federationFooter:'KOMBAX · Ligtas na federation team access',teamFooter:'KOMBAX · Ligtas na team access',studentFooter:'KOMBAX · Ligtas na imbitasyon para sa mag-aaral o pamilya'}
};
const ROLE_COPY:Record<string,Record<string,string>>={
 es:{coordinacion:'Coordinación',secretaria:'Secretaría',economia:'Economía / Tesorería',comunicacion:'Comunicación',monitor:'Monitor',presidencia:'Presidencia',tesoreria:'Tesorería',junta_directiva:'Junta directiva',colaborador:'Colaborador/a',default:'Miembro del equipo'},
 en:{coordinacion:'Coordination',secretaria:'Administration',economia:'Finance / Treasury',comunicacion:'Communications',monitor:'Coach',presidencia:'President',tesoreria:'Treasury',junta_directiva:'Board member',colaborador:'Collaborator',default:'Team member'},
 fr:{coordinacion:'Coordination',secretaria:'Secrétariat',economia:'Finances / Trésorerie',comunicacion:'Communication',monitor:'Entraîneur',presidencia:'Présidence',tesoreria:'Trésorerie',junta_directiva:'Conseil d’administration',colaborador:'Collaborateur/trice',default:"Membre de l’équipe"},
 pt:{coordinacion:'Coordenação',secretaria:'Secretaria',economia:'Finanças / Tesouraria',comunicacion:'Comunicação',monitor:'Treinador',presidencia:'Presidência',tesoreria:'Tesouraria',junta_directiva:'Direção',colaborador:'Colaborador/a',default:'Membro da equipa'},
 it:{coordinacion:'Coordinamento',secretaria:'Segreteria',economia:'Finanze / Tesoreria',comunicacion:'Comunicazione',monitor:'Allenatore',presidencia:'Presidenza',tesoreria:'Tesoreria',junta_directiva:'Consiglio direttivo',colaborador:'Collaboratore/trice',default:'Membro del team'},
 de:{coordinacion:'Koordination',secretaria:'Sekretariat',economia:'Finanzen / Kasse',comunicacion:'Kommunikation',monitor:'Trainer',presidencia:'Präsidium',tesoreria:'Kasse',junta_directiva:'Vorstand',colaborador:'Mitarbeit',default:'Teammitglied'},
 th:{coordinacion:'ฝ่ายประสานงาน',secretaria:'ฝ่ายธุรการ',economia:'การเงิน / เหรัญญิก',comunicacion:'ฝ่ายสื่อสาร',monitor:'โค้ช',presidencia:'ประธาน',tesoreria:'เหรัญญิก',junta_directiva:'คณะกรรมการ',colaborador:'ผู้ร่วมงาน',default:'สมาชิกทีม'},
 fil:{coordinacion:'Coordination',secretaria:'Secretariat',economia:'Finance / Treasury',comunicacion:'Communications',monitor:'Coach',presidencia:'President',tesoreria:'Treasury',junta_directiva:'Board member',colaborador:'Collaborator',default:'Team member'}
};
const clubRoleLabel=(role:string,locale:string)=>ROLE_COPY[locale]?.[role]||ROLE_COPY[locale]?.default||ROLE_COPY.es.default;
const federationRoleLabel=clubRoleLabel;

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
  const locale=normalizeLocale(body?.user_locale);const c=COPY[locale]||COPY.es;
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
  const greeting=name?`${c.hello} ${esc(name)},`:`${c.hello},`; 
  let url='',subject='',heading='',invitationCopy='',bindingCopy='',footer='',label='';
  if(inviteType==='federation_team'){
    label=federationRoleLabel(String(invite.rol||''),locale);
    const params=new URLSearchParams({federation_invite:String(invite.codigo||'')});
    url=`${web}/?${params.toString()}`;
    subject=`${String(invite.federation_name||'KOMBAX')} ${c.federationSubject}`;
    heading=c.federationHeading;
    invitationCopy=`<strong style="color:#fff">${esc(invite.federation_name||'KOMBAX')}</strong> ${c.federationInvite} <strong style="color:#fff">${esc(label)}</strong>.`;
    bindingCopy=c.federationBinding;
    footer=c.federationFooter;
  }else{
    const params=new URLSearchParams({club:String(invite.club_slug||''),access_type:inviteType==='equipo'?'equipo':'alumnos',access_code:String(invite.codigo||'')});
    if(inviteType==='equipo')params.set('team_role',String(invite.rol||''));
    url=`${web}/?${params.toString()}`;
    label=clubRoleLabel(String(invite.rol||''),locale);
    subject=`${String(invite.club_nombre||'KOMBAX')} ${c.clubSubject}`;
    heading=inviteType==='equipo'?c.teamHeading:c.clubHeading;
    invitationCopy=inviteType==='equipo'?`<strong style="color:#fff">${esc(invite.club_nombre||'KOMBAX')}</strong> ${c.teamInvite} <strong style="color:#fff">${esc(label)}</strong>.`:`<strong style="color:#fff">${esc(invite.club_nombre||'KOMBAX')}</strong> ${c.studentInvite}`;
    bindingCopy=inviteType==='equipo'?c.teamBinding:c.studentBinding;
    footer=inviteType==='equipo'?c.teamFooter:c.studentFooter;
  }

  const html=`<!doctype html><html><body style="margin:0;background:#0b0b0d;color:#f5f5f7;font-family:Arial,Helvetica,sans-serif"><div style="max-width:620px;margin:0 auto;padding:32px 18px"><div style="font-size:13px;letter-spacing:.22em;font-weight:800;color:#e10600;margin-bottom:14px">KOMBAX</div><div style="background:#141416;border:1px solid #2b2b30;border-top:3px solid #e10600;border-radius:18px;padding:28px"><h1 style="font-size:28px;line-height:1.15;margin:0 0 18px">${heading}</h1><p style="color:#c9c9ce;line-height:1.65">${greeting}</p><p style="color:#c9c9ce;line-height:1.65">${invitationCopy}</p><p style="color:#c9c9ce;line-height:1.65">${c.sameEmail} <strong style="color:#fff">${esc(invite.email)}</strong>. ${bindingCopy}</p><div style="margin:26px 0"><a href="${esc(url)}" style="display:inline-block;background:#e10600;color:#fff;text-decoration:none;font-weight:800;padding:14px 20px;border-radius:12px">${c.review}</a></div><div style="background:#0e0e10;border:1px solid #2a2a2e;border-radius:14px;padding:18px;text-align:center"><div style="font-size:12px;color:#8f8f98;letter-spacing:.12em;text-transform:uppercase">${c.personal}</div><div style="font-size:24px;font-weight:900;letter-spacing:.08em;margin-top:8px">${esc(invite.codigo)}</div></div><p style="font-size:13px;color:#92929a;line-height:1.55;margin-top:22px">${c.personalNotice}</p></div><p style="font-size:12px;color:#72727a;text-align:center;line-height:1.5;margin:18px 0 0">${footer}</p></div></body></html>`;
  const text=[
    `${greeting}`,
    invitationCopy.replace(/<[^>]+>/g,''),
    `${c.sameEmail} ${invite.email}.`,
    `${c.personal}: ${invite.codigo}`,
    `${c.review}: ${url}`,
    bindingCopy,
    c.personalNotice
  ].join('\n\n');

  try{
    const r=await fetch('https://api.resend.com/emails',{method:'POST',headers:{authorization:`Bearer ${resend}`,'content-type':'application/json'},body:JSON.stringify({from,to:[invite.email],subject,html,text}),signal:AbortSignal.timeout(12000)});
    const out=await r.json().catch(()=>({}));if(!r.ok)throw new Error(JSON.stringify(out));
    await updateEmailState('sent',null);
    return json(200,{ok:true,invitation_id:invitationId,email:invite.email,status:'sent',provider_id:out?.id||null,type:inviteType,user_locale:locale});
  }catch(error){
    const message=(error instanceof Error?error.message:String(error)).slice(0,900);
    await updateEmailState('error',message).catch(()=>{});
    return json(502,{ok:false,error:'email_send_failed'});
  }
});
