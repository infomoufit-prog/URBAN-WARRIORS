import { createClient } from 'npm:@supabase/supabase-js@2.112.3'

const CORS={
  'access-control-allow-origin':'*',
  'access-control-allow-headers':'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods':'POST, OPTIONS',
  'access-control-max-age':'86400'
}
const HEADERS={...CORS,'content-type':'application/json; charset=utf-8','cache-control':'private, max-age=120','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:HEADERS})
const validUuid=(v:unknown)=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)
function serviceKey(){
  const legacy=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');if(legacy)return legacy
  const raw=Deno.env.get('SUPABASE_SECRET_KEYS');if(!raw)throw new Error('KOMBAX_SERVICE_KEY_MISSING')
  const keys=JSON.parse(raw) as Record<string,string>;const key=keys.default||Object.values(keys)[0];if(!key)throw new Error('KOMBAX_SERVICE_KEY_MISSING');return key
}
function publicKey(){
  const legacy=Deno.env.get('SUPABASE_ANON_KEY');if(legacy)return legacy
  const publishable=Deno.env.get('SUPABASE_PUBLISHABLE_KEY');if(publishable)return publishable
  const raw=Deno.env.get('SUPABASE_PUBLISHABLE_KEYS');if(!raw)return ''
  try{const keys=JSON.parse(raw) as Record<string,string>;return keys.default||Object.values(keys)[0]||''}catch{return ''}
}
Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:CORS})
  if(req.method!=='POST')return json({ok:false,error:'method_not_allowed'},405)
  const body=await req.json().catch(()=>null) as {media_id?:string,variant?:'asset'|'cover'|'thumb'}|null
  if(!validUuid(body?.media_id))return json({ok:false,error:'invalid_media_id'},400)
  const variant=body?.variant==='cover'?'cover':body?.variant==='thumb'?'thumb':'asset'
  const url=Deno.env.get('SUPABASE_URL')||'';if(!url)return json({ok:false,error:'backend_not_configured'},503)
  try{
    const service=createClient(url,serviceKey(),{auth:{persistSession:false,autoRefreshToken:false}})
    const key=publicKey();const authorization=req.headers.get('authorization')||''
    const resolver=key?createClient(url,key,{global:{headers:authorization?{Authorization:authorization}:{}},auth:{persistSession:false,autoRefreshToken:false}}):service
    let {data,error}=await resolver.rpc('app_kombax_evento_media_asset_v253',{p_media_id:body!.media_id,p_variant:variant})
    if(error){
      const fallbackVariant=variant==='thumb'?'thumbnail':variant
      const fallback=await resolver.rpc('app_kombax_evento_media_asset_v252',{p_media_id:body!.media_id,p_variant:fallbackVariant});data=fallback.data;error=fallback.error
    }
    if(error&&variant==='asset'){
      const fallback=await service.rpc('app_kombax_evento_media_asset_v165',{p_media_id:body!.media_id});data=fallback.data;error=fallback.error
    }
    if(error)throw error
    const asset=Array.isArray(data)?data[0]:data
    if(!asset)return json({ok:false,error:variant==='cover'?'cover_not_available':variant==='thumb'?'thumb_not_available':'media_not_available'},404)
    if(asset.external_url)return json({ok:true,url:asset.external_url,external:true,tipo:asset.tipo,mime_type:asset.mime_type||'',allow_download:false},200)
    if(!asset.storage_bucket||!asset.storage_path)return json({ok:false,error:variant==='cover'?'cover_not_available':variant==='thumb'?'thumb_not_available':'media_asset_invalid'},404)
    const {data:signed,error:signError}=await service.storage.from(asset.storage_bucket).createSignedUrl(asset.storage_path,900)
    if(signError||!signed?.signedUrl)throw signError||new Error('SIGNED_URL_FAILED')
    return json({ok:true,url:signed.signedUrl,external:false,expires_in:900,tipo:asset.tipo,mime_type:asset.mime_type||'',allow_download:variant==='asset'&&asset.allow_download===true},200)
  }catch(error){console.error(error);return json({ok:false,error:'media_url_failed'},500)}
})
