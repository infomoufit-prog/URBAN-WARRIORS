import { createClient } from 'npm:@supabase/supabase-js@2.112.3'
import { importPKCS8, SignJWT } from 'npm:jose@6.2.9'
import { authorizeCronRequest, jsonResponse, validUuid } from '../_shared/cron-security.ts'

type Json = Record<string, unknown>
type FirebaseServiceAccount = { project_id: string; client_email: string; private_key: string; token_uri?: string }

function getSecretKey(): string {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (legacy) return legacy
  const raw = Deno.env.get('SUPABASE_SECRET_KEYS')
  if (!raw) throw new Error('KOMBAX_SERVICE_KEY_MISSING')
  const keys = JSON.parse(raw) as Record<string, string>
  const key = keys.default || Object.values(keys)[0]
  if (!key) throw new Error('KOMBAX_SERVICE_KEY_MISSING')
  return key
}

async function firebaseAccessToken(account: FirebaseServiceAccount): Promise<string> {
  const privateKey = await importPKCS8(account.private_key.replace(/\\n/g, '\n'), 'RS256')
  const now = Math.floor(Date.now() / 1000)
  const audience = account.token_uri || 'https://oauth2.googleapis.com/token'
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).setIssuer(account.client_email).setSubject(account.client_email)
    .setAudience(audience).setIssuedAt(now).setExpirationTime(now + 3600).sign(privateKey)
  const response = await fetch(audience,{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})})
  const payload=await response.json();if(!response.ok||!payload.access_token)throw new Error(`FCM_TOKEN_ERROR:${JSON.stringify(payload)}`)
  return payload.access_token as string
}


async function dispatchCommerceEmails(supabase:any){
  const apiKey=Deno.env.get('RESEND_API_KEY')||''
  if(!apiKey)return {configured:false,claimed:0,sent:0,errors:0}
  const {data:rows,error}=await supabase.rpc('app_kombax_commerce_outbox_claim_internal_r65',{p_limit:40})
  if(error){
    if(/does not exist|schema cache|could not find/i.test(String(error.message||error)))return {configured:true,claimed:0,sent:0,errors:0}
    throw error
  }
  const list=Array.isArray(rows)?rows:[];let sent=0,errors=0
  const from=Deno.env.get('KOMBAX_COMMERCE_FROM')||Deno.env.get('KOMBAX_EMAIL_FROM')||'KOMBAX <no-reply@kombax.es>'
  for(const item of list){
    if(!item?.recipient_email){
      errors++;await supabase.rpc('app_kombax_commerce_outbox_finalize_internal_r65',{p_id:item.id,p_ok:false,p_error:'RECIPIENT_EMAIL_MISSING'});continue
    }
    try{
      const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{authorization:`Bearer ${apiKey}`,'content-type':'application/json'},body:JSON.stringify({from,to:[item.recipient_email],subject:item.subject,text:item.body_text})})
      const payload=await response.json().catch(()=>({}));if(!response.ok)throw new Error(String(payload?.message||`RESEND_${response.status}`))
      sent++;await supabase.rpc('app_kombax_commerce_outbox_finalize_internal_r65',{p_id:item.id,p_ok:true,p_error:null})
    }catch(error){errors++;await supabase.rpc('app_kombax_commerce_outbox_finalize_internal_r65',{p_id:item.id,p_ok:false,p_error:String(error instanceof Error?error.message:error).slice(0,500)})}
  }
  return {configured:true,claimed:list.length,sent,errors}
}

const FINANCE_TYPES=new Set(['cuota','aviso_cobro','pago','validacion_pago','recibo'])
const SESSION_TYPES=new Set(['clase','reserva_sesion','sesion_cambio'])
const SUPPORTED_LOCALES=new Set(['es','en','fr','pt','it','de','th','fil'])
const FINANCE_COPY:Record<string,string>={es:'Tienes una actualización financiera en KOMBAX.',en:'You have a financial update in KOMBAX.',fr:'Vous avez une mise à jour financière dans KOMBAX.',pt:'Tem uma atualização financeira no KOMBAX.',it:'Hai un aggiornamento finanziario in KOMBAX.',de:'Du hast eine finanzielle Aktualisierung in KOMBAX.',th:'คุณมีข้อมูลการเงินอัปเดตใน KOMBAX',fil:'May financial update ka sa KOMBAX.'}
const SESSION_COPY:Record<string,{title:string;body:string}>={
  es:{title:'Actualización de clases',body:'Tienes una actualización de clases en KOMBAX.'},
  en:{title:'Class update',body:'You have a class update in KOMBAX.'},
  fr:{title:'Mise à jour des cours',body:'Vous avez une mise à jour de cours dans KOMBAX.'},
  pt:{title:'Atualização de aulas',body:'Tem uma atualização de aulas no KOMBAX.'},
  it:{title:'Aggiornamento lezioni',body:'Hai un aggiornamento delle lezioni in KOMBAX.'},
  de:{title:'Kursaktualisierung',body:'Du hast eine Kursaktualisierung in KOMBAX.'},
  th:{title:'อัปเดตคลาส',body:'คุณมีการอัปเดตคลาสใน KOMBAX'},
  fil:{title:'Update sa klase',body:'May update ka sa klase sa KOMBAX.'}
}
function normalizeLocale(value:unknown){const raw=String(value||'').trim().toLowerCase().replace('_','-');const base=raw.split('-')[0];return SUPPORTED_LOCALES.has(raw)?raw:SUPPORTED_LOCALES.has(base)?base:'es'}
function systemNotificationCopy(notification: Json, clubName='KOMBAX',locale='es'){
  const type=String(notification.tipo||''),resolved=normalizeLocale(locale)
  if(FINANCE_TYPES.has(type))return {title:clubName,body:FINANCE_COPY[resolved]||FINANCE_COPY.es}
  if(SESSION_TYPES.has(type)){const copy=SESSION_COPY[resolved]||SESSION_COPY.es;return {title:`${clubName} · ${copy.title}`,body:copy.body}}
  // Admin/user-authored notification copy remains in its original language.
  return {title:String(notification.titulo||clubName||'KOMBAX'),body:String(notification.cuerpo||'')}
}

async function sendFcm(account: FirebaseServiceAccount, accessToken: string, token: string, notification: Json, clubName='KOMBAX',locale='es') {
  const route=String(notification.ruta||'notifications')
  const copy=systemNotificationCopy(notification,clubName,locale)
  const response=await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,{method:'POST',headers:{authorization:`Bearer ${accessToken}`,'content-type':'application/json'},body:JSON.stringify({message:{token,notification:copy,data:{route,payload:JSON.stringify({notification_id:notification.id||null,tipo:notification.tipo||null})},android:{priority:'high',notification:{channel_id:'urban_warriors_alerts',visibility:'PRIVATE'}},webpush:{fcm_options:{link:`/#/${route}`}}}})})
  const payload=await response.json().catch(()=>({}));if(!response.ok)throw new Error(JSON.stringify(payload));return payload
}

Deno.serve(async (request) => {
  let requestId=crypto.randomUUID()
  try {
    const guard=await authorizeCronRequest(request);requestId=guard.requestId;if(guard.response)return guard.response
    const body=guard.body
    if(body.club_id!=null&&!validUuid(body.club_id))return jsonResponse({error:'invalid_club_id',request_id:requestId},400,requestId)
    const requestedClub=typeof body.club_id==='string'?body.club_id:null
    const supabase=createClient(Deno.env.get('SUPABASE_URL')!,getSecretKey(),{auth:{persistSession:false,autoRefreshToken:false}})
    const now=new Date().toISOString()

    // 1) Mantener siempre un horizonte móvil de sesiones recurrentes.
    let clubsQuery=supabase.from('clubes').select('id,nombre').eq('activo',true)
    if(requestedClub)clubsQuery=clubsQuery.eq('id',requestedClub)
    const {data:clubs,error:clubsError}=await clubsQuery;if(clubsError)throw clubsError
    const clubNames=new Map((clubs||[]).map(c=>[String(c.id),String(c.nombre||'KOMBAX')]))
    let recurringGenerated=0
    for(const club of clubs||[]){const {data,error}=await supabase.rpc('app_generar_sesiones_recurrentes',{p_club_id:club.id,p_horizonte_dias:84});if(error)throw error;recurringGenerated+=Number(data||0)}

    // 2) Retención Comunidad: DB + archivo físico. Se hace antes del push y funciona incluso sin Firebase.
    let expiredQuery=supabase.from('publicaciones_comunidad').select('id,club_id,media_path,portada_automatica_path,portada_manual_path').lte('expira_en',now).limit(500)
    if(requestedClub)expiredQuery=expiredQuery.eq('club_id',requestedClub)
    const {data:expired,error:expiredError}=await expiredQuery;if(expiredError)throw expiredError
    const paths=[...new Set((expired||[]).flatMap(x=>[x.media_path,x.portada_automatica_path,x.portada_manual_path]).filter(Boolean))] as string[]
    if(paths.length){for(let i=0;i<paths.length;i+=100){const {error}=await supabase.storage.from('community-media').remove(paths.slice(i,i+100));if(error)throw error}}
    if((expired||[]).length){const {error}=await supabase.from('publicaciones_comunidad').delete().in('id',(expired||[]).map(x=>x.id));if(error)throw error}

    // 3) Publicaciones oficiales programadas y recordatorios de clase existentes.
    const {data:scheduledPublished,error:scheduledError}=await supabase.rpc('publicar_comunicaciones_programadas',{p_ahora:now});if(scheduledError)throw scheduledError
    const {data:classReminders,error:classError}=await supabase.rpc('generar_recordatorios_clase',{p_ahora:now,p_horas:3});if(classError)throw classError

    // 4) KOMBAX Commerce / Events transactional outbox. Independent from Firebase.
    const commerceEmail=await dispatchCommerceEmails(supabase)

    const firebaseRaw=Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if(!firebaseRaw)return jsonResponse({ok:true,firebase_configured:false,recurring_generated:recurringGenerated,community_deleted:(expired||[]).length,scheduled_published:scheduledPublished||0,class_reminders:classReminders||0,commerce_email:commerceEmail,sent:0,errors:commerceEmail.errors},200,requestId)
    const account=JSON.parse(firebaseRaw) as FirebaseServiceAccount, accessToken=await firebaseAccessToken(account)
    const since=new Date(Date.now()-14*24*60*60*1000).toISOString()
    let notificationQuery=supabase.from('notificaciones').select('id,club_id,perfil_id,rol_destino,audiencia,tipo,titulo,cuerpo,ruta,datos,push_intentos,programada_para').is('push_enviado_en',null).lt('push_intentos',5).gte('creado_en',since).order('creado_en',{ascending:true}).limit(300)
    if(requestedClub)notificationQuery=notificationQuery.eq('club_id',requestedClub)
    const {data:notifications,error:notificationError}=await notificationQuery;if(notificationError)throw notificationError

    let sent=0,errors=0
    const due=(notifications||[]).filter(n=>!n.programada_para||new Date(n.programada_para).getTime()<=Date.now())
    for(const notification of due){
      const recipientIds=new Set<string>()
      if(notification.perfil_id)recipientIds.add(notification.perfil_id)
      if(!notification.perfil_id&&(notification.rol_destino||notification.audiencia==='todos')){
        let memberQuery=supabase.from('miembros_club').select('perfil_id').eq('club_id',notification.club_id).eq('activo',true)
        if(notification.rol_destino)memberQuery=memberQuery.eq('rol',notification.rol_destino)
        const {data:members,error}=await memberQuery;if(error)throw error;for(const m of members||[])recipientIds.add(m.perfil_id)
      }
      const ids=[...recipientIds]
      const localeByProfile=new Map<string,string>()
      if(ids.length){
        try{const {data:profiles,error}=await supabase.from('perfiles').select('id,preferred_locale').in('id',ids);if(error)throw error;for(const profile of profiles||[])localeByProfile.set(String(profile.id),normalizeLocale(profile.preferred_locale))}
        catch(error){console.warn('preferred_locale lookup unavailable; using es fallback',error)}
      }
      let tokens:{id:string;token:string;perfil_id:string}[]=[]
      if(ids.length){const {data:devices,error}=await supabase.from('dispositivos_push').select('id,token,perfil_id').eq('club_id',notification.club_id).eq('activo',true).in('perfil_id',ids);if(error)throw error;tokens=devices||[]}
      let delivered=false;const itemErrors:string[]=[]
      for(const device of tokens){try{await sendFcm(account,accessToken,device.token,notification as Json,clubNames.get(String(notification.club_id))||'KOMBAX',localeByProfile.get(String(device.perfil_id))||'es');delivered=true;sent++}catch(error){errors++;const message=error instanceof Error?error.message:String(error);itemErrors.push(message);if(/UNREGISTERED|registration-token-not-registered|not found/i.test(message))await supabase.from('dispositivos_push').update({activo:false}).eq('id',device.id)}}
      await supabase.from('notificaciones').update({push_enviado_en:delivered?new Date().toISOString():null,push_intentos:Number(notification.push_intentos||0)+1,push_error:itemErrors.length?itemErrors.join(' | ').slice(0,2000):(tokens.length?null:'no_active_push_devices')}).eq('id',notification.id)
    }
    return jsonResponse({ok:true,firebase_configured:true,recurring_generated:recurringGenerated,community_deleted:(expired||[]).length,scheduled_published:scheduledPublished||0,class_reminders:classReminders||0,commerce_email:commerceEmail,notifications:due.length,sent,errors:errors+commerceEmail.errors},200,requestId)
  }catch(error){console.error(`[${requestId}]`,error);return jsonResponse({error:'internal_error',request_id:requestId},500,requestId)}
})
