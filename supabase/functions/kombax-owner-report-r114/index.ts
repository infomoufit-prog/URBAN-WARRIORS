import { createClient } from 'npm:@supabase/supabase-js@2.112.3'
import { PDFDocument, StandardFonts, rgb } from 'npm:pdf-lib@1.17.1'

const cors={'access-control-allow-origin':'*','access-control-allow-headers':'authorization, x-client-info, apikey, content-type','access-control-allow-methods':'POST, OPTIONS'}
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'content-type':'application/json; charset=utf-8'}})
const safe=(v:unknown)=>String(v??'').replace(/[\u0000-\u001f]/g,' ').slice(0,180)
const number=(v:unknown)=>new Intl.NumberFormat('es-ES',{maximumFractionDigits:0}).format(Number(v||0))
const money=(v:unknown)=>new Intl.NumberFormat('es-ES',{style:'currency',currency:'EUR',maximumFractionDigits:2}).format(Number(v||0))
const bytes=(v:unknown)=>{let n=Number(v||0),i=0;const u=['B','KB','MB','GB','TB'];while(n>=1024&&i<u.length-1){n/=1024;i++}return `${n.toLocaleString('es-ES',{maximumFractionDigits:i<2?0:2})} ${u[i]}`}
const serviceKey=()=>Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||Deno.env.get('SERVICE_ROLE_KEY')||''

async function buildPdf(payload:any){
  const pdf=await PDFDocument.create(),regular=await pdf.embedFont(StandardFonts.Helvetica),bold=await pdf.embedFont(StandardFonts.HelveticaBold)
  const metrics=payload.metrics||{},latest=metrics.latest||{},tot=metrics.period_totals||{},alerts=payload.owner_alerts||{},agents=payload.agents||{}
  const page=pdf.addPage([595.28,841.89]);let y=792;const left=44
  const draw=(text:string,x:number,size=9,font=regular,color=rgb(.18,.2,.24))=>{page.drawText(safe(text),{x,y,size,font,color});y-=size+7}
  page.drawText('KOMBAX',{x:left,y,size:18,font:bold,color:rgb(.06,.55,.72)});y-=27
  page.drawText('Owner Command Center · Informe ejecutivo',{x:left,y,size:16,font:bold,color:rgb(.08,.1,.14)});y-=25
  draw(`Generado: ${new Date(payload.generated_at||Date.now()).toLocaleString('es-ES')} · Periodo: ${number(payload.days)} días`,left,8)
  y-=6
  const sections:[string,Array<[string,string]>][]=[
    ['Plataforma', [['Clubes activos',number(latest.active_clubs)],['Cuentas',number(latest.accounts_total)],['Alumnos activos',number(latest.active_students)],['Storage',bytes(latest.storage_bytes)]]],
    ['Actividad', [['Nuevas cuentas',number(tot.new_accounts)],['Sesiones',number(tot.sessions)],['Asistencias',number(tot.attendance)],['Pagos validados',`${number(tot.payments)} · ${money(tot.payment_amount)}`],['Mensajes Social',number(tot.social_messages)],['Push enviados',number(tot.push_sent)]]],
    ['Owner', [['Alertas sin leer',number(alerts.unread)],['Requieren acción',number(alerts.action_required)],['Críticas',number(alerts.critical)],['Warnings',number(alerts.warnings)]]],
    ['Agentes SaaS', [['Ejecuciones',number(agents.total)],['Completadas',number(agents.completed)],['Fallidas',number(agents.failed)],['Riesgo alto/crítico',number(agents.high_risk)],['Owner Operations',number(agents.operations)],['Pilot Intelligence',number(agents.pilot_intelligence)]]]
  ]
  for(const [title,rows] of sections){y-=8;page.drawText(title,{x:left,y,size:11,font:bold,color:rgb(.08,.1,.14)});y-=18;for(const [label,value] of rows){page.drawText(label,{x:left+6,y,size:8.5,font:regular,color:rgb(.32,.35,.4)});page.drawText(value,{x:330,y,size:9,font:bold,color:rgb(.08,.1,.14)});y-=16}}
  y-=10;page.drawLine({start:{x:left,y},end:{x:551,y},thickness:.6,color:rgb(.78,.8,.84)});y-=18
  draw('Informe privado de administración. No contiene detalle identificativo de miembros.',left,7)

  const page2=pdf.addPage([595.28,841.89]),daily=Array.isArray(metrics.daily)?metrics.daily:[],top=Array.isArray(metrics.top_clubs)?metrics.top_clubs:[]
  page2.drawText('Tendencia y actividad por club',{x:left,y:792,size:15,font:bold,color:rgb(.08,.1,.14)})
  const chart={x:left,y:522,w:507,h:220},series=daily.map((row:any)=>({label:String(row.metric_date||''),value:Number(row.sessions||0)})),max=Math.max(1,...series.map((row:any)=>row.value))
  page2.drawText('Sesiones por día',{x:left,y:760,size:10,font:bold,color:rgb(.18,.2,.24)})
  page2.drawLine({start:{x:chart.x,y:chart.y},end:{x:chart.x+chart.w,y:chart.y},thickness:.7,color:rgb(.68,.71,.76)})
  page2.drawLine({start:{x:chart.x,y:chart.y},end:{x:chart.x,y:chart.y+chart.h},thickness:.7,color:rgb(.68,.71,.76)})
  if(series.length){
    const step=series.length>1?chart.w/(series.length-1):0;let prev:any=null
    series.forEach((row:any,index:number)=>{const point={x:chart.x+index*step,y:chart.y+(row.value/max)*chart.h};if(prev)page2.drawLine({start:prev,end:point,thickness:1.5,color:rgb(.06,.55,.72)});prev=point})
    page2.drawText(`Máx. ${number(max)}`,{x:chart.x+4,y:chart.y+chart.h+8,size:7,font:regular,color:rgb(.32,.35,.4)})
    page2.drawText(safe(series[0]?.label),{x:chart.x,y:chart.y-14,size:7,font:regular,color:rgb(.32,.35,.4)})
    const last=safe(series.at(-1)?.label);page2.drawText(last,{x:chart.x+chart.w-Math.min(80,last.length*4),y:chart.y-14,size:7,font:regular,color:rgb(.32,.35,.4)})
  }else page2.drawText('Sin datos diarios para el periodo.',{x:chart.x+12,y:chart.y+100,size:8,font:regular,color:rgb(.32,.35,.4)})

  let ty=474;page2.drawText('Clubes con mayor actividad',{x:left,y:ty,size:10,font:bold,color:rgb(.18,.2,.24)});ty-=20
  const cols=[left,left+215,left+295,left+370,left+445]
  ;[['Club',cols[0]],['Alumnos',cols[1]],['Sesiones',cols[2]],['Asistencia',cols[3]],['Actividad',cols[4]]].forEach(([label,x]:any)=>page2.drawText(String(label),{x:Number(x),y:ty,size:7.5,font:bold,color:rgb(.32,.35,.4)}));ty-=14
  for(const row of top.slice(0,10)){
    page2.drawText(safe(row.nombre||'Club').slice(0,34),{x:cols[0],y:ty,size:7.5,font:regular,color:rgb(.12,.14,.18)})
    page2.drawText(number(row.active_students),{x:cols[1],y:ty,size:7.5,font:regular,color:rgb(.12,.14,.18)})
    page2.drawText(number(row.sessions),{x:cols[2],y:ty,size:7.5,font:regular,color:rgb(.12,.14,.18)})
    page2.drawText(number(row.attendance),{x:cols[3],y:ty,size:7.5,font:regular,color:rgb(.12,.14,.18)})
    page2.drawText(number(row.activity_score),{x:cols[4],y:ty,size:7.5,font:regular,color:rgb(.12,.14,.18)});ty-=18
  }
  page2.drawText('Los gráficos y tablas usan agregaciones server-side; no se exporta el dataset completo de miembros al navegador.',{x:left,y:54,size:7,font:regular,color:rgb(.32,.35,.4)})
  return new Uint8Array(await pdf.save())
}

Deno.serve(async req=>{const requestId=crypto.randomUUID();try{
  if(req.method==='OPTIONS')return new Response(null,{status:204,headers:cors});if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED',request_id:requestId},405)
  const auth=req.headers.get('authorization')||'';if(!/^Bearer\s+.+/i.test(auth))return json({error:'AUTH_REQUIRED',request_id:requestId},401)
  const body=await req.json().catch(()=>({})),days=Math.min(365,Math.max(7,Number(body.days||90))),url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')||Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!
  const user=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{persistSession:false,autoRefreshToken:false}})
  const {data:payload,error}=await user.rpc('app_kombax_owner_report_payload_r114',{p_days:days});if(error||!payload?.ok)return json({error:'OWNER_REPORT_FORBIDDEN',detail:error?.message,request_id:requestId},403)
  const pdf=await buildPdf(payload);const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',pdf)),sha=[...digest].map(x=>x.toString(16).padStart(2,'0')).join('')
  const key=serviceKey();if(!key)throw new Error('SERVICE_ROLE_KEY_MISSING');const service=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}})
  const date=new Date().toISOString().slice(0,10),path=`owner/${date}/owner-command-center-${crypto.randomUUID()}.pdf`,up=await service.storage.from('kombax-reports').upload(path,pdf,{contentType:'application/pdf',upsert:false,cacheControl:'private, max-age=0'});if(up.error)throw up.error
  const signed=await service.storage.from('kombax-reports').createSignedUrl(path,600);if(signed.error||!signed.data?.signedUrl)throw signed.error||new Error('SIGNED_URL_FAILED')
  return json({ok:true,url:signed.data.signedUrl,path,filename:`KOMBAX-Owner-Command-Center-${date}.pdf`,bytes:pdf.byteLength,sha256:sha,period_days:days,expires_in:600,request_id:requestId})
}catch(error){console.error(`[kombax-owner-report-r114 ${requestId}]`,error);return json({error:'OWNER_REPORT_FAILED',request_id:requestId},500)}})
