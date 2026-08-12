import { createClient } from 'npm:@supabase/supabase-js@2'
import { importPKCS8, SignJWT } from 'npm:jose@6'

type Json = Record<string, unknown>
type FirebaseServiceAccount = { project_id: string; client_email: string; private_key: string; token_uri?: string }
function getSecretKey(): string {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (legacy) return legacy
  const raw = Deno.env.get('SUPABASE_SECRET_KEYS')
  if (!raw) throw new Error('No se encontró una clave secreta de Supabase')
  const keys = JSON.parse(raw) as Record<string, string>
  const key = keys.default || Object.values(keys)[0]
  if (!key) throw new Error('SUPABASE_SECRET_KEYS no contiene ninguna clave')
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
  const payload=await response.json();if(!response.ok||!payload.access_token)throw new Error(`No se pudo obtener token FCM: ${JSON.stringify(payload)}`)
  return payload.access_token as string
}

async function sendFcm(account: FirebaseServiceAccount, accessToken: string, token: string, notification: Json) {
  const route=String(notification.ruta||'notifications')
  const response=await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,{method:'POST',headers:{authorization:`Bearer ${accessToken}`,'content-type':'application/json'},body:JSON.stringify({message:{token,notification:{title:String(notification.titulo||'Urban Warriors'),body:String(notification.cuerpo||'')},data:{route,payload:JSON.stringify(notification.datos||{})},android:{priority:'high',notification:{channel_id:'urban_warriors_alerts'}},webpush:{fcm_options:{link:`/#/${route}`}}}})})
  const payload=await response.json().catch(()=>({}));if(!response.ok)throw new Error(JSON.stringify(payload));return payload
}

Deno.serve(async (request) => {
  try {
    const expectedSecret=Deno.env.get('UW_CRON_SECRET'), suppliedSecret=request.headers.get('x-uw-cron-secret')
    if(!expectedSecret||suppliedSecret!==expectedSecret)return Response.json({error:'No autorizado'},{status:401})
    const body=request.method==='POST'?await request.json().catch(()=>({} as Json)) as Json:{} as Json
    const requestedClub=typeof body.club_id==='string'?body.club_id:null
    const supabase=createClient(Deno.env.get('SUPABASE_URL')!,getSecretKey(),{auth:{persistSession:false,autoRefreshToken:false}})
    const now=new Date().toISOString()

    // 1) Mantener siempre un horizonte móvil de sesiones recurrentes.
    let clubsQuery=supabase.from('clubes').select('id').eq('activo',true)
    if(requestedClub)clubsQuery=clubsQuery.eq('id',requestedClub)
    const {data:clubs,error:clubsError}=await clubsQuery;if(clubsError)throw clubsError
    let recurringGenerated=0
    for(const club of clubs||[]){const {data,error}=await supabase.rpc('app_generar_sesiones_recurrentes',{p_club_id:club.id,p_horizonte_dias:84});if(error)throw error;recurringGenerated+=Number(data||0)}

    // 2) Retención Comunidad: DB + archivo físico. Se hace antes del push y funciona incluso sin Firebase.
    let expiredQuery=supabase.from('publicaciones_comunidad').select('id,club_id,media_path,portada_path').lte('expira_en',now).limit(500)
    if(requestedClub)expiredQuery=expiredQuery.eq('club_id',requestedClub)
    const {data:expired,error:expiredError}=await expiredQuery;if(expiredError)throw expiredError
    const paths=(expired||[]).flatMap(x=>[x.media_path,x.portada_path]).filter(Boolean) as string[]
    if(paths.length){for(let i=0;i<paths.length;i+=100){const {error}=await supabase.storage.from('community-media').remove(paths.slice(i,i+100));if(error)throw error}}
    if((expired||[]).length){const {error}=await supabase.from('publicaciones_comunidad').delete().in('id',(expired||[]).map(x=>x.id));if(error)throw error}

    // 3) Publicaciones oficiales programadas y recordatorios de clase existentes.
    const {data:scheduledPublished,error:scheduledError}=await supabase.rpc('publicar_comunicaciones_programadas',{p_ahora:now});if(scheduledError)throw scheduledError
    const {data:classReminders,error:classError}=await supabase.rpc('generar_recordatorios_clase',{p_ahora:now,p_horas:3});if(classError)throw classError

    const firebaseRaw=Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if(!firebaseRaw)return Response.json({ok:true,firebase_configured:false,recurring_generated:recurringGenerated,community_deleted:(expired||[]).length,scheduled_published:scheduledPublished||0,class_reminders:classReminders||0,sent:0,errors:0})
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
      let tokens:{id:string;token:string}[]=[]
      if(ids.length){const {data:devices,error}=await supabase.from('dispositivos_push').select('id,token').eq('club_id',notification.club_id).eq('activo',true).in('perfil_id',ids);if(error)throw error;tokens=devices||[]}
      let delivered=false;const itemErrors:string[]=[]
      for(const device of tokens){try{await sendFcm(account,accessToken,device.token,notification as Json);delivered=true;sent++}catch(error){errors++;const message=error instanceof Error?error.message:String(error);itemErrors.push(message);if(/UNREGISTERED|registration-token-not-registered|not found/i.test(message))await supabase.from('dispositivos_push').update({activo:false}).eq('id',device.id)}}
      await supabase.from('notificaciones').update({push_enviado_en:delivered?new Date().toISOString():null,push_intentos:Number(notification.push_intentos||0)+1,push_error:itemErrors.length?itemErrors.join(' | ').slice(0,2000):(tokens.length?null:'Sin dispositivos push registrados')}).eq('id',notification.id)
    }
    return Response.json({ok:true,firebase_configured:true,recurring_generated:recurringGenerated,community_deleted:(expired||[]).length,scheduled_published:scheduledPublished||0,class_reminders:classReminders||0,notifications:due.length,sent,errors})
  }catch(error){console.error(error);return Response.json({error:error instanceof Error?error.message:String(error)},{status:500})}
})
