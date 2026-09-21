import { openDetail, toast } from './components.js';
import { esc } from '../core/utils.js';
import { optimizeImage } from '../core/media.js';

const clamp=(v,min,max,fallback)=>{const n=Number(v);return Number.isFinite(n)?Math.max(min,Math.min(max,n)):fallback;};
const toBlob=(canvas,type,quality)=>new Promise(resolve=>canvas.toBlob(resolve,type,quality));

export async function captureVideoFrame(src,timeSeconds=null,{maxEdge=1280}={}){
  if(!src)throw new Error('No hay vídeo disponible para capturar la portada.');
  const video=document.createElement('video');video.muted=true;video.playsInline=true;video.preload='auto';video.crossOrigin='anonymous';
  return await new Promise((resolve,reject)=>{
    let done=false;const timeout=setTimeout(()=>finish(null,new Error('No se pudo preparar el fotograma.')),18000);
    const finish=(value,error)=>{if(done)return;done=true;clearTimeout(timeout);video.onloadedmetadata=video.onseeked=video.onloadeddata=video.onerror=null;try{video.removeAttribute('src');video.load();}catch{}error?reject(error):resolve(value);};
    const capture=async()=>{try{
      const width=Number(video.videoWidth||0),height=Number(video.videoHeight||0),duration=Number(video.duration||0);if(!width||!height)throw new Error('El vídeo no contiene dimensiones válidas.');
      const scale=Math.min(1,maxEdge/Math.max(width,height)),w=Math.max(1,Math.round(width*scale)),h=Math.max(1,Math.round(height*scale));
      const canvas=document.createElement('canvas');canvas.width=w;canvas.height=h;const ctx=canvas.getContext('2d');if(!ctx)throw new Error('No se pudo crear la portada.');ctx.drawImage(video,0,0,w,h);
      const blob=await toBlob(canvas,'image/webp',0.86);if(!blob)throw new Error('No se pudo generar el fotograma.');
      const file=new File([blob],`kombax-video-cover-${Date.now()}.webp`,{type:'image/webp',lastModified:Date.now()});finish({file,time:Number(video.currentTime||0),duration,width:w,height:h});
    }catch(error){finish(null,error);}};
    video.onerror=()=>finish(null,new Error('No se pudo abrir este vídeo para elegir portada.'));
    video.onloadedmetadata=()=>{const duration=Number(video.duration||0);const target=timeSeconds==null?Math.min(Math.max(duration*.25,.05),Math.max(.05,duration-.05)):clamp(timeSeconds,0,Math.max(0,duration-.02),0);if(target>.01){video.onseeked=capture;video.currentTime=target;}else video.onloadeddata=capture;};
    video.src=src;video.load();
  });
}

export function openVideoCoverEditor({src,initial={},title='Portada del vídeo',subtitle='Elige un fotograma o sube una imagen propia.',onSave}={}){
  if(!src){toast('No hay vídeo disponible.','error');return null;}
  const body=`<div class="kx-video-cover-editor"><div class="kx-video-cover-preview"><video src="${esc(src)}" controls muted playsinline preload="metadata" crossorigin="anonymous"></video><img data-kx-cover-preview alt="Vista previa de la portada" hidden></div><div class="kx-video-cover-time"><label><span>Fotograma <b data-kx-cover-time-label>0:00</b></span><input data-kx-cover-time type="range" min="0" max="1" step="0.05" value="0"></label><small>Mueve el control o reproduce el vídeo hasta el momento que quieras.</small></div><div class="kx-video-cover-choices"><button type="button" class="btn btn-ghost" data-kx-cover-auto>Automática</button><button type="button" class="btn btn-primary" data-kx-cover-frame>Usar este fotograma</button><label class="btn btn-ghost kx-video-cover-upload">Subir imagen<input type="file" accept="image/jpeg,image/png,image/webp" data-kx-cover-upload hidden></label></div><p class="muted">La portada solo afecta a la miniatura. El vídeo original permanece intacto y se reproduce completo al abrirlo.</p></div>`;
  const modal=openDetail({title,subtitle,body,actions:'',width:'820px',className:'kx-video-cover-modal'});const root=modal.wrap.querySelector('.kx-video-cover-editor'),video=root?.querySelector('video'),slider=root?.querySelector('[data-kx-cover-time]'),label=root?.querySelector('[data-kx-cover-time-label]'),preview=root?.querySelector('[data-kx-cover-preview]');
  let duration=0,busy=false;const fmt=s=>{const n=Math.max(0,Number(s)||0),m=Math.floor(n/60),sec=Math.floor(n%60);return `${m}:${String(sec).padStart(2,'0')}`;};
  const syncLabel=()=>{if(label)label.textContent=fmt(slider?.value||video?.currentTime||0);};
  video?.addEventListener('loadedmetadata',()=>{duration=Number(video.duration||0);if(slider){slider.max=String(Math.max(.05,duration-.02));const initialTime=clamp(initial?.cover_time,0,Math.max(0,duration-.02),Math.min(duration*.25,Math.max(0,duration-.02)));slider.value=String(initialTime);video.currentTime=initialTime;}syncLabel();},{once:true});
  video?.addEventListener('timeupdate',()=>{if(slider&&!slider.matches(':active'))slider.value=String(video.currentTime||0);syncLabel();});
  slider?.addEventListener('input',()=>{if(video&&duration){video.currentTime=Number(slider.value)||0;video.pause();}syncLabel();});
  const save=async(file,mode,time)=>{if(busy)return;busy=true;root?.classList.add('is-busy');try{const prepared=await optimizeImage(file,{maxEdge:1600,maxBytes:2*1024*1024});if(preview){preview.src=URL.createObjectURL(prepared.file);preview.hidden=false;}await onSave?.({file:prepared.file,mode,time:Number(time)||0});toast(mode==='upload'?'Portada personalizada guardada.':mode==='auto'?'Portada automática guardada.':'Fotograma guardado como portada.');modal.close?.();}catch(error){toast(error?.message||'No se pudo guardar la portada.','error');busy=false;root?.classList.remove('is-busy');}};
  root?.querySelector('[data-kx-cover-auto]')?.addEventListener('click',async()=>{const target=Math.min(Math.max((duration||Number(video?.duration||0))*.25,.05),Math.max(.05,(duration||Number(video?.duration||0))-.05));try{const frame=await captureVideoFrame(src,target);await save(frame.file,'auto',frame.time);}catch(error){toast(error?.message||'No se pudo generar la portada automática.','error');}});
  root?.querySelector('[data-kx-cover-frame]')?.addEventListener('click',async()=>{try{const frame=await captureVideoFrame(src,Number(video?.currentTime||slider?.value||0));await save(frame.file,'frame',frame.time);}catch(error){toast(error?.message||'No se pudo capturar ese fotograma.','error');}});
  root?.querySelector('[data-kx-cover-upload]')?.addEventListener('change',async e=>{const file=e.currentTarget.files?.[0];if(file)await save(file,'upload',Number(video?.currentTime||0));});
  return modal;
}
