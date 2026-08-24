export type Json = Record<string, unknown>
const RESPONSE_HEADERS={
  'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff',
  'referrer-policy':'no-referrer','content-security-policy':"default-src 'none'; frame-ancestors 'none'"
}
export function jsonResponse(payload:unknown,status=200,requestId=crypto.randomUUID()){
  return new Response(JSON.stringify(payload),{status,headers:{...RESPONSE_HEADERS,'x-request-id':requestId}})
}
async function digest(value:string){return new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))}
async function safeEqual(left:string,right:string){
  const [a,b]=await Promise.all([digest(left),digest(right)]);let mismatch=a.length^b.length;
  for(let i=0;i<Math.max(a.length,b.length);i++)mismatch|=(a[i%a.length]||0)^(b[i%b.length]||0);
  return mismatch===0
}
export async function authorizeCronRequest(request:Request){
  const requestId=crypto.randomUUID()
  if(request.method!=='POST')return {response:jsonResponse({error:'Método no permitido',request_id:requestId},405,requestId),requestId,body:{} as Json}
  if(!String(request.headers.get('content-type')||'').toLowerCase().includes('application/json'))return {response:jsonResponse({error:'Formato no admitido',request_id:requestId},415,requestId),requestId,body:{} as Json}
  const declared=Number(request.headers.get('content-length')||0)
  if(declared>16384)return {response:jsonResponse({error:'Solicitud demasiado grande',request_id:requestId},413,requestId),requestId,body:{} as Json}
  const expected=Deno.env.get('UW_CRON_SECRET')||'',supplied=request.headers.get('x-uw-cron-secret')||''
  if(!expected||!supplied||!await safeEqual(expected,supplied))return {response:jsonResponse({error:'No autorizado',request_id:requestId},401,requestId),requestId,body:{} as Json}
  const raw=await request.text()
  if(raw.length>16384)return {response:jsonResponse({error:'Solicitud demasiado grande',request_id:requestId},413,requestId),requestId,body:{} as Json}
  let body:Json={};try{body=raw?JSON.parse(raw):{}}catch{return {response:jsonResponse({error:'JSON no válido',request_id:requestId},400,requestId),requestId,body:{}}}
  if(!body||Array.isArray(body)||typeof body!=='object')return {response:jsonResponse({error:'JSON no válido',request_id:requestId},400,requestId),requestId,body:{}}
  return {response:null,requestId,body}
}
export function validUuid(value:unknown){return typeof value==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)}
export function validIsoDate(value:unknown){return typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value)&&!Number.isNaN(Date.parse(`${value}T00:00:00Z`))}
