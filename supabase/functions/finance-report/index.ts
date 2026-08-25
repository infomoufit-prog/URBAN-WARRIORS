import { createClient } from 'npm:@supabase/supabase-js@2.112.3'
import { PDFDocument, StandardFonts, rgb, type PDFPage, type PDFFont } from 'npm:pdf-lib@1.17.1'

const A4:[number,number]=[595.28,841.89]
const MARGIN=42

function secretKey():string{
  const legacy=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if(legacy)return legacy
  const raw=Deno.env.get('SUPABASE_SECRET_KEYS')
  if(!raw)throw new Error('Missing Supabase secret key')
  const parsed=JSON.parse(raw) as Record<string,string>
  const key=parsed.default||Object.values(parsed)[0]
  if(!key)throw new Error('SUPABASE_SECRET_KEYS is empty')
  return key
}
const cors={'access-control-allow-origin':'*','access-control-allow-headers':'authorization, x-client-info, apikey, content-type','access-control-allow-methods':'POST, OPTIONS','access-control-max-age':'86400'}
function json(data:unknown,status=200){return new Response(JSON.stringify(data),{status,headers:{...cors,'content-type':'application/json; charset=utf-8','cache-control':'no-store'}})}
function uuid(v:unknown){return typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)}
function n(v:unknown){const x=Number(v||0);return Number.isFinite(x)?x:0}
function eur(v:unknown){return `${n(v).toLocaleString('es-ES',{minimumFractionDigits:2,maximumFractionDigits:2})} EUR`}
function safe(v:unknown){return String(v??'').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g,' ').replace(/[–—]/g,'-').replace(/…/g,'...').replace(/[^\x20-\x7E\u00A0-\u00FF\u20AC]/g,'?')}
function short(v:unknown,max=34){const t=safe(v).replace(/\s+/g,' ').trim();return t.length<=max?t:`${t.slice(0,Math.max(0,max-1))}…`}
function hex(value:unknown,fallback=[0.82,0.08,0.10] as [number,number,number]){
  const m=/^#([0-9a-f]{6})$/i.exec(String(value||''));if(!m)return fallback
  const x=parseInt(m[1],16);return [((x>>16)&255)/255,((x>>8)&255)/255,(x&255)/255] as [number,number,number]
}
function wrap(text:string,font:PDFFont,size:number,width:number){
  const words=safe(text).split(/\s+/).filter(Boolean),lines:string[]=[];let line=''
  for(const word of words){const next=line?`${line} ${word}`:word;if(font.widthOfTextAtSize(next,size)<=width)line=next;else{if(line)lines.push(line);line=word}}
  if(line)lines.push(line);return lines.length?lines:['']
}
function drawText(page:PDFPage,font:PDFFont,text:string,x:number,y:number,size=9,opts:{maxWidth?:number;color?:[number,number,number]}={}){
  const c=opts.color||[0.12,0.14,0.17];page.drawText(safe(text),{x,y,size,font,color:rgb(c[0],c[1],c[2]),maxWidth:opts.maxWidth})
}
function reportTypeLabel(type:string){return ({vista_actual:'Vista financiera',tesoreria_mensual:'Tesoreria mensual',tesoreria_anual:'Tesoreria anual',cobros:'Cobros',pendientes:'Pendientes',vencidos:'Vencidos',por_grupo:'Por grupo',por_disciplina:'Por disciplina',por_categoria:'Por categoria',por_metodo_pago:'Por metodo de pago',licencias:'Licencias',competiciones:'Competiciones',eventos:'Eventos',estado_cuenta:'Estado de cuenta'} as Record<string,string>)[type]||type}

async function embedLogo(pdf:PDFDocument,url:unknown){
  const value=String(url||'').trim();if(!/^https:\/\//i.test(value))return null
  try{const res=await fetch(value,{signal:AbortSignal.timeout(4500)});if(!res.ok)return null;const bytes=new Uint8Array(await res.arrayBuffer());const type=res.headers.get('content-type')||'';if(/png/i.test(type)||/\.png(?:\?|$)/i.test(value))return await pdf.embedPng(bytes);if(/jpe?g/i.test(type)||/\.jpe?g(?:\?|$)/i.test(value))return await pdf.embedJpg(bytes)}catch{/* optional branding */}return null
}

async function buildPdf(payload:any){
  const snap=payload.snapshot||{},club=snap.club||{},summary=snap.totales||{},months=Array.isArray(snap.meses)?snap.meses:[],rows=Array.isArray(snap.rows)?snap.rows:[]
  const pdf=await PDFDocument.create();pdf.setTitle(safe(snap.titulo||payload.titulo||'Informe financiero KOMBAX'));pdf.setSubject(`KOMBAX Finance Premium · ${safe(payload.identificador)}`);pdf.setCreator('KOMBAX Finance Premium 2.0');pdf.setProducer('KOMBAX');
  const normal=await pdf.embedFont(StandardFonts.Helvetica),bold=await pdf.embedFont(StandardFonts.HelveticaBold);const logo=await embedLogo(pdf,club.logo_url);const accent=hex(club.color_primario)
  let page=pdf.addPage(A4);let y=A4[1]-MARGIN
  const header=(p:PDFPage,compact=false)=>{
    p.drawRectangle({x:0,y:A4[1]-8,width:A4[0],height:8,color:rgb(accent[0],accent[1],accent[2])})
    if(logo&&!compact){const scale=Math.min(64/logo.width,40/logo.height);p.drawImage(logo,{x:MARGIN,y:A4[1]-MARGIN-38,width:logo.width*scale,height:logo.height*scale})}
    const tx=logo&&!compact?MARGIN+74:MARGIN
    drawText(p,bold,safe(club.nombre||'Club KOMBAX'),tx,A4[1]-MARGIN-8,14)
    drawText(p,normal,[club.cif?`CIF/NIF ${club.cif}`:'',club.email,club.telefono].filter(Boolean).join(' · '),tx,A4[1]-MARGIN-23,7,{color:[0.38,0.42,0.47]})
    return A4[1]-MARGIN-(compact?34:62)
  }
  y=header(page)
  drawText(page,bold,safe(snap.titulo||payload.titulo||reportTypeLabel(payload.tipo)),MARGIN,y,19);y-=22
  drawText(page,normal,`${safe(payload.identificador)} · Version ${payload.version||1} · ${reportTypeLabel(payload.tipo||snap.tipo||'')}`,MARGIN,y,8,{color:[0.38,0.42,0.47]});y-=16
  const period=snap.periodo||{};const actor=snap.generado_por||{};const generated=new Date(snap.generado_en||payload.generado_en||Date.now()).toLocaleString('es-ES',{timeZone:club.zona_horaria||'Europe/Madrid'})
  drawText(page,normal,`Periodo: ${period.desde||'—'} a ${period.hasta||'—'} · Generado: ${generated}`,MARGIN,y,8);y-=13
  drawText(page,normal,`Generado por: ${safe(`${actor.nombre||''} ${actor.apellidos||''}`.trim()||'Usuario autorizado')} · ${rows.length} registros`,MARGIN,y,8);y-=24

  const kpis=[['Generado',summary.generado],['Cobrado',summary.cobrado],['Pendiente',summary.pendiente],['Vencido',summary.vencido]] as const;const gap=8,w=(A4[0]-2*MARGIN-gap*3)/4
  for(let i=0;i<kpis.length;i++){const x=MARGIN+i*(w+gap);page.drawRectangle({x,y:y-48,width:w,height:48,borderWidth:.7,borderColor:rgb(.82,.84,.87),color:rgb(.97,.975,.98)});drawText(page,normal,kpis[i][0],x+9,y-15,7,{color:[.38,.42,.47]});drawText(page,bold,eur(kpis[i][1]),x+9,y-34,11)}
  y-=66
  drawText(page,bold,`Porcentaje de cobro: ${n(summary.porcentaje_cobro).toFixed(2)} % · Alumnos con deuda: ${n(summary.alumnos_con_deuda)}`,MARGIN,y,9);y-=22

  if(months.length){
    drawText(page,bold,'Evolucion mensual · Histograma mensual',MARGIN,y,10);y-=13
    drawText(page,normal,'Generado / Cobrado / Pendiente',MARGIN,y,7,{color:[.38,.42,.47]});y-=12
    const chartH=108,chartW=A4[0]-2*MARGIN,max=Math.max(1,...months.flatMap((m:any)=>[n(m.generado),n(m.cobrado),n(m.pendiente)]));
    const display=months.slice(-12),slot=chartW/Math.max(1,display.length),bar=Math.max(4,Math.min(11,(slot-12)/3)),base=y-chartH;
    ;[0,.5,1].forEach(fr=>{const yy=base+fr*(chartH-18);page.drawLine({start:{x:MARGIN,y:yy},end:{x:MARGIN+chartW,y:yy},thickness:.35,color:rgb(.86,.87,.89)});drawText(page,normal,eur(max*(1-fr)),MARGIN,yy+2,5.6,{color:[.46,.49,.54]})})
    display.forEach((m:any,i:number)=>{const x=MARGIN+i*slot+10,values=[n(m.generado),n(m.cobrado),n(m.pendiente)],cols=[[.72,.75,.79],[accent[0],accent[1],accent[2]],[.36,.40,.46]] as [number,number,number][];values.forEach((v,j)=>{const h=(v/max)*(chartH-22);page.drawRectangle({x:x+j*(bar+3),y:base,width:bar,height:Math.max(1,h),color:rgb(cols[j][0],cols[j][1],cols[j][2])})});drawText(page,normal,String(m.mes||'').slice(5,7),x+bar,base-10,6,{color:[.38,.42,.47]})})
    const ly=base-25;[['Generado',[.72,.75,.79]],['Cobrado',accent],['Pendiente',[.36,.40,.46]]].forEach((it:any,i:number)=>{const x=MARGIN+i*105;page.drawRectangle({x,y:ly,width:8,height:8,color:rgb(it[1][0],it[1][1],it[1][2])});drawText(page,normal,it[0],x+12,ly+1,6.5)})
    y=ly-17
  }

  const aging=Array.isArray(snap.antiguedad)?snap.antiguedad:[]
  if(aging.length&&y>MARGIN+125){
    drawText(page,bold,'Antiguedad de la deuda',MARGIN,y,10);y-=14
    const labels:Record<string,string>={sin_vencer:'Sin vencer','1_15':'1-15 dias','16_30':'16-30 dias','31_60':'31-60 dias','60_plus':'+60 dias'}
    const vals=aging.map((a:any)=>n(a.total)),amax=Math.max(1,...vals),labelW=82,amountW=62,trackW=A4[0]-2*MARGIN-labelW-amountW-14
    aging.slice(0,5).forEach((a:any,i:number)=>{const val=n(a.total),yy=y-i*18;drawText(page,normal,labels[String(a.bucket)]||String(a.bucket||''),MARGIN,yy,7);page.drawRectangle({x:MARGIN+labelW,y:yy-2,width:trackW,height:8,color:rgb(.92,.93,.94)});page.drawRectangle({x:MARGIN+labelW,y:yy-2,width:Math.max(1,trackW*val/amax),height:8,color:rgb(accent[0],accent[1],accent[2]),opacity:.78});drawText(page,bold,eur(val),A4[0]-MARGIN-amountW+3,yy,7)})
    y-=aging.slice(0,5).length*18+10
  }


  const filterLabels=snap.filtros_etiquetas||{};const filterText=Object.entries(filterLabels).filter(([,v])=>String(v||'').trim()).map(([k,v])=>`${k}: ${v}`).join(' · ')
  if(filterText){drawText(page,bold,'Filtros',MARGIN,y,9);y-=12;for(const line of wrap(filterText,normal,7,A4[0]-2*MARGIN)){drawText(page,normal,line,MARGIN,y,7);y-=10}y-=6}

  const tableHeader=(p:PDFPage,startY:number)=>{const cols=[['Alumno',116],['Concepto',110],['Periodo',52],['Importe',55],['Cobrado',55],['Pendiente',55],['Estado',62]] as const;let x=MARGIN;p.drawRectangle({x:MARGIN,y:startY-15,width:A4[0]-2*MARGIN,height:17,color:rgb(.93,.94,.95)});for(const [label,cw] of cols){drawText(p,bold,label,x+3,startY-10,6.5);x+=cw}return startY-19}
  if(rows.length){drawText(page,bold,'Detalle financiero',MARGIN,y,10);y-=14;y=tableHeader(page,y);for(const r of rows){if(y<MARGIN+34){page=pdf.addPage(A4);y=header(page,true);drawText(page,bold,'Detalle financiero (continuacion)',MARGIN,y,9);y-=13;y=tableHeader(page,y)}const cells=[short(`${r.socio_apellidos||''}, ${r.socio_nombre||''}`,26),short(r.concepto,24),String(r.periodo||'').slice(0,7),eur(r.importe),eur(r.pagado_validado),eur(r.saldo),short(r.estado,14)],widths=[116,110,52,55,55,55,62];let x=MARGIN;for(let i=0;i<cells.length;i++){drawText(page,normal,cells[i],x+3,y,6.2,{maxWidth:widths[i]-5});x+=widths[i]}page.drawLine({start:{x:MARGIN,y:y-4},end:{x:A4[0]-MARGIN,y:y-4},thickness:.25,color:rgb(.88,.89,.91)});y-=13}}
  if(!rows.length){drawText(page,normal,'No hay movimientos que coincidan con los filtros del informe.',MARGIN,y,9);y-=18}

  if(y<MARGIN+60){page=pdf.addPage(A4);y=header(page,true)}
  y-=8;drawText(page,bold,'Nota historica',MARGIN,y,8);y-=12;for(const line of wrap(safe(snap.nota_historica||'Este informe es un snapshot historico inmutable.'),normal,7,A4[0]-2*MARGIN)){drawText(page,normal,line,MARGIN,y,7,{color:[.38,.42,.47]});y-=10}

  const pages=pdf.getPages();pages.forEach((p,i)=>{p.drawLine({start:{x:MARGIN,y:28},end:{x:A4[0]-MARGIN,y:28},thickness:.4,color:rgb(.82,.84,.87)});drawText(p,normal,`${safe(payload.identificador)} · Pagina ${i+1}/${pages.length}`,MARGIN,16,6.5,{color:[.42,.45,.5]});const right='KOMBAX · Informe financiero privado';const rw=normal.widthOfTextAtSize(right,6.5);drawText(p,normal,right,A4[0]-MARGIN-rw,16,6.5,{color:[.42,.45,.5]})})
  return new Uint8Array(await pdf.save())
}

Deno.serve(async(req)=>{
  const requestId=crypto.randomUUID()
  try{
    if(req.method==='OPTIONS')return new Response(null,{status:204,headers:cors})
    if(req.method!=='POST')return json({error:'Method not allowed',request_id:requestId},405)
    const auth=req.headers.get('authorization')||'';if(!/^Bearer\s+.+/i.test(auth))return json({error:'AUTH_REQUIRED',request_id:requestId},401)
    const body=await req.json().catch(()=>({}));if(!uuid(body.report_id))return json({error:'report_id no valido',request_id:requestId},400)
    const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')||Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!
    const user=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{persistSession:false,autoRefreshToken:false}})
    const {data:payload,error:accessError}=await user.rpc('app_finance_v2_report_payload_v145',{p_report_id:body.report_id})
    if(accessError||!payload?.id)return json({error:'FINANCE_REPORT_FORBIDDEN',request_id:requestId},403)
    if(payload.archivo_path)return json({ok:true,existing:true,report_id:payload.id,archivo_path:payload.archivo_path,request_id:requestId})

    const bytes=await buildPdf(payload);if(bytes.byteLength>20*1024*1024)throw new Error('Generated PDF exceeds 20 MB')
    const hashBytes=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));const sha=[...hashBytes].map(x=>x.toString(16).padStart(2,'0')).join('')
    const year=String(payload.snapshot?.generado_en||payload.generado_en||new Date().toISOString()).slice(0,4)||String(new Date().getFullYear())
    const path=`${payload.club_id}/${year}/${payload.identificador}.pdf`
    const service=createClient(url,secretKey(),{auth:{persistSession:false,autoRefreshToken:false}})
    const {error:uploadError}=await service.storage.from('finance-reports').upload(path,bytes,{contentType:'application/pdf',upsert:true,cacheControl:'private, max-age=0'})
    if(uploadError)throw uploadError
    const {error:attachError}=await service.rpc('app_finance_v2_report_file_attach_v145',{p_report_id:payload.id,p_path:path,p_bytes:bytes.byteLength,p_sha256:sha})
    if(attachError)throw attachError
    return json({ok:true,report_id:payload.id,identificador:payload.identificador,archivo_path:path,archivo_bytes:bytes.byteLength,archivo_sha256:sha,request_id:requestId})
  }catch(error){console.error(`[finance-report ${requestId}]`,error);return json({error:'FINANCE_REPORT_GENERATION_FAILED',request_id:requestId},500)}
})
