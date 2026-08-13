const MAX_IMAGE_INPUT_BYTES=35*1024*1024;
const MAX_IMAGE_OUTPUT_BYTES=5*1024*1024;
const MAX_IMAGE_EDGE=1920;

function imageName(name,type){
  const ext=type==='image/webp'?'webp':type==='image/png'?'png':'jpg';
  return String(name||'imagen').replace(/\.[^.]+$/, '')+`.${ext}`;
}

async function loadImage(file){
  if(typeof createImageBitmap==='function'){
    try{
      const bitmap=await createImageBitmap(file,{imageOrientation:'from-image'});
      return {source:bitmap,width:bitmap.width,height:bitmap.height,close:()=>bitmap.close?.()};
    }catch(error){console.warn('ImageBitmap no disponible para esta imagen; se usa decodificación HTML.',error);}
  }
  const url=URL.createObjectURL(file);
  try{
    const source=await new Promise((resolve,reject)=>{const img=new Image();img.onload=()=>resolve(img);img.onerror=()=>reject(new Error('No se pudo decodificar la imagen seleccionada.'));img.src=url;});
    return {source,width:source.naturalWidth,height:source.naturalHeight,close:()=>{}};
  }finally{URL.revokeObjectURL(url);}
}

const toBlob=(canvas,type,quality)=>new Promise(resolve=>canvas.toBlob(resolve,type,quality));

export async function optimizeImage(file,{maxEdge=MAX_IMAGE_EDGE,maxBytes=MAX_IMAGE_OUTPUT_BYTES}={}){
  if(!file||!file.size)throw new Error('Selecciona una imagen.');
  if(!String(file.type||'').startsWith('image/'))throw new Error('El archivo seleccionado no es una imagen.');
  if(file.size>MAX_IMAGE_INPUT_BYTES)throw new Error('La imagen original supera 35 MB. Selecciona una versión más ligera.');
  const decoded=await loadImage(file);
  try{
    if(!decoded.width||!decoded.height)throw new Error('La imagen no tiene dimensiones válidas.');
    const scale=Math.min(1,maxEdge/Math.max(decoded.width,decoded.height));
    const width=Math.max(1,Math.round(decoded.width*scale));
    const height=Math.max(1,Math.round(decoded.height*scale));
    if(scale===1&&file.size<=1200*1024&&file.size<=maxBytes){
      return {file,width,height,mime:file.type,sizeBytes:file.size,originalBytes:file.size,optimized:false};
    }
    const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;
    const context=canvas.getContext('2d',{alpha:true});
    if(!context)throw new Error('Este dispositivo no puede optimizar la imagen.');
    context.imageSmoothingEnabled=true;context.imageSmoothingQuality='high';context.drawImage(decoded.source,0,0,width,height);
    let blob=null;
    for(const quality of [0.86,0.78,0.70]){
      blob=await toBlob(canvas,'image/webp',quality);
      if(blob&&blob.size<=maxBytes)break;
    }
    if(!blob){
      context.globalCompositeOperation='destination-over';context.fillStyle='#ffffff';context.fillRect(0,0,width,height);
      blob=await toBlob(canvas,'image/jpeg',0.82);
    }
    if(!blob||blob.size>maxBytes)throw new Error('No se pudo reducir la imagen por debajo de 5 MB sin perder demasiada calidad.');
    const output=new File([blob],imageName(file.name,blob.type),{type:blob.type,lastModified:Date.now()});
    return {file:output,width,height,mime:output.type,sizeBytes:output.size,originalBytes:file.size,optimized:output.size<file.size||scale<1};
  }finally{decoded.close();}
}

export function formatMediaBytes(bytes){
  const value=Number(bytes||0);if(value<1024)return `${value} B`;if(value<1024*1024)return `${(value/1024).toFixed(0)} KB`;return `${(value/1024/1024).toFixed(1)} MB`;
}

export async function prepareVideo(file){
  if(!file||!file.size)throw new Error('Selecciona un vídeo.');
  if(!String(file.type||'').startsWith('video/'))throw new Error('El archivo seleccionado no es un vídeo.');
  if(file.size>50*1024*1024)throw new Error('El vídeo supera 50 MB.');
  const url=URL.createObjectURL(file);const video=document.createElement('video');video.muted=true;video.playsInline=true;video.preload='auto';
  try{
    return await new Promise((resolve,reject)=>{
      let finished=false;const timeout=setTimeout(()=>finish(null,new Error('No se pudo preparar el vídeo en este dispositivo.')),15000);
      const finish=(value,error)=>{if(finished)return;finished=true;clearTimeout(timeout);video.onloadedmetadata=video.onloadeddata=video.onseeked=video.onerror=null;error?reject(error):resolve(value);};
      const capture=async()=>{try{
        const duration=Number(video.duration||0),width=Number(video.videoWidth||0),height=Number(video.videoHeight||0);
        if(!duration||!width||!height)throw new Error('El vídeo no contiene metadatos válidos.');
        if(duration>15.2)throw new Error(`El vídeo dura ${duration.toFixed(1)} s. El máximo es 15 s.`);
        if(Math.max(width,height)>1920||Math.min(width,height)>1080)throw new Error(`El vídeo es ${width}×${height}. La resolución final máxima admitida es 1080p.`);
        const scale=Math.min(1,1280/Math.max(width,height));const posterWidth=Math.max(1,Math.round(width*scale)),posterHeight=Math.max(1,Math.round(height*scale));
        const canvas=document.createElement('canvas');canvas.width=posterWidth;canvas.height=posterHeight;const context=canvas.getContext('2d');if(!context)throw new Error('No se pudo generar la portada del vídeo.');
        context.drawImage(video,0,0,posterWidth,posterHeight);const blob=await toBlob(canvas,'image/webp',0.82);if(!blob)throw new Error('No se pudo generar la portada automática.');
        const cover=new File([blob],String(file.name||'video').replace(/\.[^.]+$/,'')+'-portada.webp',{type:blob.type||'image/webp',lastModified:Date.now()});
        finish({file,duration,width,height,mime:file.type,sizeBytes:file.size,cover});
      }catch(error){finish(null,error);}};
      video.onerror=()=>finish(null,new Error('El formato de vídeo no puede procesarse en este navegador. Usa MP4 H.264 o WEBM.'));
      video.onloadedmetadata=()=>{const target=Math.min(Math.max(Number(video.duration||0)*0.25,0.05),Math.max(0,Number(video.duration||0)-0.05));if(target>0){video.onseeked=capture;video.currentTime=target;}else video.onloadeddata=capture;};
      video.src=url;video.load();
    });
  }finally{URL.revokeObjectURL(url);video.removeAttribute('src');video.load();}
}
