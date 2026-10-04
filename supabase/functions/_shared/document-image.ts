import type {PDFDocument} from 'npm:pdf-lib@1.17.1';
import {ImageMagick,initializeImageMagick,MagickFormat} from 'npm:@imagemagick/magick-wasm@0.0.44';

let initialized:Promise<void>|undefined;
async function pngCompatible(bytes:Uint8Array){
 initialized??=Deno.readFile(new URL('x86/magick.wasm',import.meta.resolve('npm:@imagemagick/magick-wasm@0.0.44'))).then(data=>initializeImageMagick(data));
 await initialized;
 return ImageMagick.read(bytes,image=>{
  if(image.width<1||image.height<1||image.width*image.height>16_777_216)throw Error('DOCUMENT_IMAGE_DIMENSIONS');
  if(image.width>1024||image.height>1024)image.resize(1024,1024);
  return image.write(MagickFormat.Png,data=>Uint8Array.from(data));
 });
}
export function documentImageUrl(value:unknown){
 if(!value)return '';
 const app=Deno.env.get('KOMBAX_APP_URL')||'',supabase=Deno.env.get('SUPABASE_URL')||'';
 let url:URL;try{url=new URL(String(value).trim(),app||undefined);}catch{throw Error('DOCUMENT_IMAGE_URL');}
 const origins=new Set([app,supabase].filter(Boolean).map(v=>new URL(v).origin));
 const allowedHosts=new Set((Deno.env.get('KOMBAX_DOCUMENT_IMAGE_HOSTS')||'').split(',').map(v=>v.trim().toLowerCase()).filter(Boolean));
 if(url.protocol!=='https:'||url.username||url.password||(!origins.has(url.origin)&&!allowedHosts.has(url.hostname.toLowerCase())))throw Error('DOCUMENT_IMAGE_ORIGIN');
 return url.href;
}
export async function embedDocumentImage(pdf:PDFDocument,value:unknown,{required=false}={}){
 if(!value)return null;
 try{
  const url=documentImageUrl(value),response=await fetch(url,{redirect:'error',signal:AbortSignal.timeout(8000)});
  if(!response.ok)throw Error('DOCUMENT_IMAGE_UNAVAILABLE');
  if(Number(response.headers.get('content-length')||0)>5*1024*1024)throw Error('DOCUMENT_IMAGE_SIZE');
  const reader=response.body?.getReader();if(!reader)throw Error('DOCUMENT_IMAGE_EMPTY');const chunks:Uint8Array[]=[];let size=0;
  for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>5*1024*1024){await reader.cancel();throw Error('DOCUMENT_IMAGE_SIZE');}chunks.push(value);}
  const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  if(bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71)return await pdf.embedPng(bytes);
  if(bytes[0]===255&&bytes[1]===216)return await pdf.embedJpg(bytes);
  if(new TextDecoder().decode(bytes.slice(0,4))==='RIFF'&&new TextDecoder().decode(bytes.slice(8,12))==='WEBP')return await pdf.embedPng(await pngCompatible(bytes));
  throw Error('DOCUMENT_IMAGE_FORMAT');
 }catch(error){if(required)throw error;console.warn('Optional document image unavailable');return null;}
}

