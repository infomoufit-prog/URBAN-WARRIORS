const CORS={'access-control-allow-origin':'*','access-control-allow-headers':'authorization,apikey,content-type,x-client-info','access-control-allow-methods':'POST,OPTIONS'};
const headers={...CORS,'cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer','content-security-policy':"sandbox; default-src 'none'"};
const json=(error,status)=>new Response(JSON.stringify({error}),{status,headers:{...headers,'content-type':'application/json'}});
export function documentMime(bytes){
 if(bytes.length>=5&&String.fromCharCode(...bytes.slice(0,5))==='%PDF-')return 'application/pdf';
 if(bytes.length>=3&&bytes[0]===255&&bytes[1]===216&&bytes[2]===255)return 'image/jpeg';
 if(bytes.length>=8&&[137,80,78,71,13,10,26,10].every((v,i)=>bytes[i]===v))return 'image/png';
 if(bytes.length>=12&&String.fromCharCode(...bytes.slice(0,4))==='RIFF'&&String.fromCharCode(...bytes.slice(8,12))==='WEBP')return 'image/webp';
 return null;
}
export function makeDocumentHandler(createService){return async req=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:CORS});
 if(req.method!=='POST')return json('method_not_allowed',405);
 const body=await req.json().catch(()=>null),id=body?.credential_id;
 if(typeof id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id))return json('invalid_credential_id',400);
 try{
  const service=createService();
  const {data:asset,error}=await service.rpc('app_kombax_public_document_asset_r120',{p_credential_id:id});
  if(error)return json('document_unavailable',503);
  if(!asset||asset.bucket!=='kombax-credential-public-copies'||typeof asset.path!=='string')return json('document_unavailable',404);
  const {data:file,error:downloadError}=await service.storage.from(asset.bucket).download(asset.path);
  if(downloadError||!file||file.size>15728640)return json('document_unavailable',404);
  const bytes=new Uint8Array(await file.arrayBuffer()),mime=documentMime(bytes);
  if(!mime)return json('document_format_rejected',415);
  return new Response(bytes,{headers:{...headers,'content-type':mime,'content-disposition':`inline; filename="credential-${id}.${mime==='application/pdf'?'pdf':mime==='image/jpeg'?'jpg':mime==='image/png'?'png':'webp'}"`}});
 }catch{return json('document_unavailable',503);}
};}
