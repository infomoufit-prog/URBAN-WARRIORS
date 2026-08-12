import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, dtFmt } from '../core/utils.js';
import { pageHeader, empty, badge, openForm, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const staff=()=>['direccion','coordinacion','secretaria','comunicacion'].includes(state.session?.rol);
const canModerate=()=>staff();
const daysLeft=(iso)=>Math.max(0,Math.ceil((new Date(iso).getTime()-Date.now())/86400000));
const PAGE_SIZE=20;
let loadedPosts=[];
let nextOffset=0;
let hasMore=true;

async function videoInfo(file){
  if(!String(file?.type||'').startsWith('video/'))return null;
  return new Promise((resolve,reject)=>{
    const v=document.createElement('video');const url=URL.createObjectURL(file);v.preload='metadata';
    v.onloadedmetadata=()=>{const info={duration:Number(v.duration||0),width:Number(v.videoWidth||0),height:Number(v.videoHeight||0)};URL.revokeObjectURL(url);resolve(info)};
    v.onerror=()=>{URL.revokeObjectURL(url);reject(new Error('No se pudo leer el vídeo.'))};v.src=url;
  });
}
async function imageInfo(file){
  const bitmap=await createImageBitmap(file);const info={width:bitmap.width,height:bitmap.height};bitmap.close?.();return info;
}
async function compressImage(file,max=1600,quality=.82){
  if(!file||!String(file.type||'').startsWith('image/'))return file;
  const bitmap=await createImageBitmap(file);const scale=Math.min(1,max/Math.max(bitmap.width,bitmap.height));
  if(scale===1&&file.size<900*1024){bitmap.close?.();return file;}
  const w=Math.max(1,Math.round(bitmap.width*scale)),h=Math.max(1,Math.round(bitmap.height*scale));
  const canvas=document.createElement('canvas');canvas.width=w;canvas.height=h;canvas.getContext('2d').drawImage(bitmap,0,0,w,h);bitmap.close?.();
  const blob=await new Promise(r=>canvas.toBlob(r,'image/jpeg',quality));
  return blob?new File([blob],file.name.replace(/\.[^.]+$/,'.jpg'),{type:'image/jpeg'}):file;
}
async function automaticVideoCover(file){
  return new Promise((resolve,reject)=>{
    const video=document.createElement('video');const url=URL.createObjectURL(file);video.muted=true;video.playsInline=true;video.preload='auto';
    const cleanup=()=>URL.revokeObjectURL(url);
    video.onloadedmetadata=()=>{video.currentTime=Math.min(Math.max(.2,video.duration*.18),Math.max(.2,video.duration-.1));};
    video.onseeked=async()=>{try{const max=960,scale=Math.min(1,max/Math.max(video.videoWidth,video.videoHeight));const canvas=document.createElement('canvas');canvas.width=Math.round(video.videoWidth*scale);canvas.height=Math.round(video.videoHeight*scale);canvas.getContext('2d').drawImage(video,0,0,canvas.width,canvas.height);const blob=await new Promise(r=>canvas.toBlob(r,'image/jpeg',.78));cleanup();if(!blob)throw new Error('No se pudo generar la portada.');resolve(new File([blob],`portada-${Date.now()}.jpg`,{type:'image/jpeg'}));}catch(e){cleanup();reject(e)}};
    video.onerror=()=>{cleanup();reject(new Error('No se pudo generar la portada del vídeo.'))};video.src=url;
  });
}
async function enrich(posts){
  return Promise.all(posts.map(async p=>{let mediaUrl='',avatarUrl='',coverUrl='';try{mediaUrl=await repos.community.mediaUrl(p.media_path)}catch{}try{if(p.portada_path)coverUrl=await repos.community.mediaUrl(p.portada_path)}catch{}try{if(p.autor_avatar_path)avatarUrl=await repos.settings.avatarUrl(p.autor_avatar_path)}catch{}return {...p,mediaUrl,coverUrl,avatarUrl};}));
}
function cardHtml(p){return `<article class="community-post ${p.estado==='oculta'?'community-hidden':''}">
  <header class="community-author">${p.avatarUrl?`<img loading="lazy" src="${esc(p.avatarUrl)}" alt="">`:`<span class="community-avatar-fallback">${esc((p.autor_nombre||'U').slice(0,1).toUpperCase())}</span>`}<div><strong>${esc(p.autor_nombre||'Miembro del club')}</strong><small>${dtFmt(p.creado_en)} · ${daysLeft(p.expira_en)} días restantes</small></div>${p.estado==='oculta'?badge('Oculta','warn'):''}</header>
  ${p.texto?`<p class="community-copy">${esc(p.texto)}</p>`:''}
  <div class="community-media">${p.media_tipo==='video'?`<video controls playsinline preload="none" ${p.coverUrl?`poster="${esc(p.coverUrl)}"`:''} src="${esc(p.mediaUrl)}"></video>`:`<img loading="lazy" decoding="async" src="${esc(p.mediaUrl)}" alt="Publicación de ${esc(p.autor_nombre||'usuario')}">`}</div>
  <footer class="community-actions">${p.autor_perfil_id===state.session?.id||canModerate()?`<button class="btn btn-ghost btn-sm community-delete" data-id="${esc(p.id)}">${icon('trash',{size:14})} Eliminar</button>`:''}${canModerate()&&p.autor_perfil_id!==state.session?.id?`<button class="btn btn-ghost btn-sm community-hide" data-id="${esc(p.id)}" data-hidden="${p.estado==='oculta'?'1':'0'}">${p.estado==='oculta'?'Mostrar':'Ocultar'}</button>`:''}</footer>
</article>`}
function bindPostActions(){
  document.querySelectorAll('.community-delete').forEach(b=>b.addEventListener('click',()=>confirmDialog('Eliminar publicación','Se borrará también la imagen o vídeo almacenado.',async()=>{const p=loadedPosts.find(x=>x.id===b.dataset.id);await repos.community.delete(b.dataset.id);if(p?.portada_path)await repos.community.removeMedia(p.portada_path).catch(()=>{});toast('Publicación eliminada');await renderCommunity();},{confirmText:'Eliminar',danger:true})));
  document.querySelectorAll('.community-hide').forEach(b=>b.addEventListener('click',async()=>{try{await repos.community.moderate(b.dataset.id,b.dataset.hidden!=='1',b.dataset.hidden==='1'?'Reactivada por el club':'Ocultada por moderación');toast(b.dataset.hidden==='1'?'Publicación visible':'Publicación oculta');await renderCommunity();}catch(e){setError(e)}}));
}
function drawFeed(){
  const feed=document.querySelector('.community-feed');if(!feed)return;
  feed.innerHTML=loadedPosts.map(cardHtml).join('')||empty('Todavía no hay publicaciones','Sé la primera persona en compartir un momento del club.');
  const more=document.getElementById('community-more');if(more){more.hidden=!hasMore;more.disabled=false;}
  bindPostActions();
}
async function loadMore(){
  const button=document.getElementById('community-more');if(button)button.disabled=true;
  const raw=await repos.community.list(PAGE_SIZE,nextOffset);const active=raw.filter(p=>new Date(p.expira_en).getTime()>Date.now());const page=await enrich(active);
  loadedPosts.push(...page);nextOffset+=raw.length;hasMore=raw.length===PAGE_SIZE;drawFeed();
}

export async function renderCommunity(){
  loadedPosts=[];nextOffset=0;hasMore=true;setMainHtml('<div class="loading-card">Cargando comunidad…</div>');
  try{
    const quota=await repos.community.quota();const publishDisabled=quota.used>=quota.limit;
    setMainHtml(`${pageHeader('Comunidad','Momentos del club durante 30 días',`<button class="btn btn-primary" id="community-new" ${publishDisabled?'disabled':''}>${icon('plus',{size:16})} Publicar</button>`,'Club')}
      <section class="community-hero"><div><span class="page-kicker">COMUNIDAD URBAN WARRIORS</span><h2>Tu club también se vive aquí.</h2><p>Imágenes optimizadas y vídeos de hasta 15 segundos. El feed carga por bloques para mantenerse rápido aunque el club acumule mucho contenido.</p></div><div class="community-quota"><strong>${quota.used}/${quota.limit}</strong><span>publicaciones este mes</span></div></section>
      ${publishDisabled?`<div class="alert alert-warning"><strong>Límite mensual alcanzado</strong><span>Podrás volver a publicar el próximo mes.</span></div>`:''}
      <div class="community-feed"></div><div class="community-more-wrap"><button class="btn btn-ghost" id="community-more">Cargar más publicaciones</button></div>`);
    document.getElementById('community-more')?.addEventListener('click',()=>loadMore().catch(setError));
    document.getElementById('community-new')?.addEventListener('click',()=>openForm({title:'Nueva publicación en Comunidad',subtitle:`Te quedan ${Math.max(0,quota.limit-quota.used)} publicaciones este mes. Caducará a los 30 días.`,width:'720px',fields:[{name:'texto',label:'Mensaje',type:'textarea',full:true,rows:4,placeholder:'Entrenamiento, competición, celebración…'},{name:'media',label:'Imagen o vídeo',type:'file',required:true,accept:'image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime',help:'Imagen optimizada automáticamente · vídeo máx. 50 MB, 15 s y 1080p.'},{name:'portada',label:'Portada manual (opcional, solo vídeo)',type:'file',accept:'image/jpeg,image/png,image/webp',help:'Si no eliges una, Urban Warriors generará una automáticamente.'}],submitText:'Publicar',onSubmit:async v=>{
      let file=v.media;const isVideo=String(file.type||'').startsWith('video/');let duration=null,mediaWidth=null,mediaHeight=null,coverFile=null,coverPath='';
      if(isVideo){const info=await videoInfo(file);duration=info.duration;mediaWidth=info.width;mediaHeight=info.height;if(duration>15.2)throw new Error(`El vídeo dura ${duration.toFixed(1)} s. El máximo es 15 s.`);if(mediaWidth>1920||mediaHeight>1920)throw new Error('El vídeo supera 1080p. Exporta o graba una versión HD/Full HD antes de subirla.');coverFile=v.portada?.size?await compressImage(v.portada,960,.8):await automaticVideoCover(file);}else{file=await compressImage(file);const info=await imageInfo(file);mediaWidth=info.width;mediaHeight=info.height;}
      const path=await repos.community.upload(file,'media');try{if(coverFile)coverPath=await repos.community.upload(coverFile,'covers');await repos.community.publish({texto:v.texto,media_path:path,media_tipo:isVideo?'video':'imagen',duracion_segundos:duration,portada_path:coverPath,media_ancho:mediaWidth,media_alto:mediaHeight});toast('Publicado en Comunidad');await renderCommunity();}catch(e){await repos.community.removeMedia(path).catch(()=>{});if(coverPath)await repos.community.removeMedia(coverPath).catch(()=>{});throw e;}
    }}));
    await loadMore();
  }catch(e){setError(e);setMainHtml(`${pageHeader('Comunidad')} ${empty('No se pudo cargar la Comunidad',e.message)}`)}
}
