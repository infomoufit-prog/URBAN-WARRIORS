import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, dtFmt } from '../core/utils.js';
import { pageHeader, card, empty, badge, openForm, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { optimizeImage, formatMediaBytes, prepareVideo } from '../core/media.js';

const staff=()=>['direccion','coordinacion','secretaria','comunicacion'].includes(state.session?.rol);
const canModerate=()=>staff();
const canChangeCover=()=>['direccion','coordinacion'].includes(state.session?.rol);
const daysLeft=(iso)=>Math.max(0,Math.ceil((new Date(iso).getTime()-Date.now())/86400000));
const PAGE_SIZE=20;
let communityPosts=[];
let communityCursor=null;
let communityDone=false;
let communityLoading=false;

async function enrich(posts){
  return Promise.all(posts.map(async p=>{let mediaUrl='',avatarUrl='',coverUrl='';try{mediaUrl=await repos.community.mediaUrl(p.media_path)}catch{}try{if(p.autor_avatar_path)avatarUrl=await repos.settings.avatarUrl(p.autor_avatar_path)}catch{}try{const coverPath=p.portada_manual_path||p.portada_automatica_path;if(coverPath)coverUrl=await repos.community.mediaUrl(coverPath)}catch{}return {...p,mediaUrl,avatarUrl,coverUrl};}));
}

async function cleanupPaths(paths){for(const path of [...new Set(paths.filter(Boolean))])await repos.community.removePath(path).catch(()=>{});}

async function publishCommunity(values){
  let file=values.media;const isVideo=String(file?.type||'').startsWith('video/');const uploaded=[];
  try{
    if(isVideo){
      const video=await prepareVideo(file);const mediaPath=await repos.community.upload(video.file);uploaded.push(mediaPath);
      const automatic=await optimizeImage(video.cover,{maxEdge:1280,maxBytes:1024*1024});const automaticPath=await repos.community.upload(automatic.file);uploaded.push(automaticPath);
      let manualPath=null;if(values.manual_cover&&canChangeCover()){const manual=await optimizeImage(values.manual_cover,{maxEdge:1280,maxBytes:1024*1024});manualPath=await repos.community.upload(manual.file);uploaded.push(manualPath);}
      await repos.community.publish({texto:values.texto,media_path:mediaPath,media_tipo:'video',duracion_segundos:video.duration,media_mime:video.mime,media_width:video.width,media_height:video.height,media_size_bytes:video.sizeBytes,portada_automatica_path:automaticPath,portada_manual_path:manualPath});
    }else{
      const image=await optimizeImage(file);file=image.file;if(image.optimized)toast(`Imagen optimizada: ${formatMediaBytes(image.originalBytes)} → ${formatMediaBytes(image.sizeBytes)}`);
      const mediaPath=await repos.community.upload(file);uploaded.push(mediaPath);
      await repos.community.publish({texto:values.texto,media_path:mediaPath,media_tipo:'imagen',media_mime:image.mime,media_width:image.width,media_height:image.height,media_size_bytes:image.sizeBytes});
    }
    toast('Publicado en Comunidad');await renderCommunity();
  }catch(error){await cleanupPaths(uploaded);throw error;}
}

function changeVideoCover(post){
  openForm({title:'Cambiar portada',subtitle:'La nueva portada sustituirá a la manual actual. La automática se conserva como respaldo.',width:'560px',fields:[{name:'cover',label:'Nueva portada',type:'file',required:true,full:true,accept:'image/jpeg,image/png,image/webp',help:'Se optimizará automáticamente.'}],submitText:'Guardar portada',onSubmit:async values=>{
    const image=await optimizeImage(values.cover,{maxEdge:1280,maxBytes:1024*1024});const path=await repos.community.upload(image.file);
    try{const out=await repos.community.changeCover(post.id,path);if(out?.old_cover_path&&out.old_cover_path!==path)await repos.community.removePath(out.old_cover_path).catch(()=>{});toast('Portada actualizada');await renderCommunity();}
    catch(error){await repos.community.removePath(path).catch(()=>{});throw error;}
  }});
}

export async function renderCommunity({append=false}={}){
  if(communityLoading)return;
  communityLoading=true;
  if(!append){communityPosts=[];communityCursor=null;communityDone=false;setMainHtml('<div class="loading-card">Cargando comunidad…</div>');}
  try{
    const [raw,quota]=await Promise.all([repos.community.listPage(communityCursor,PAGE_SIZE),repos.community.quota()]);
    const page=await enrich(raw.filter(p=>new Date(p.expira_en).getTime()>Date.now()));
    const merged=new Map(communityPosts.map(p=>[p.id,p]));for(const p of page)merged.set(p.id,p);communityPosts=[...merged.values()];
    const last=raw.at(-1);communityCursor=last?{created:last.creado_en,id:last.id}:communityCursor;communityDone=raw.length<PAGE_SIZE;
    const posts=communityPosts;
    const publishDisabled=quota.used>=quota.limit;
    const cards=posts.map(p=>`<article class="community-post ${p.estado==='oculta'?'community-hidden':''}">
      <header class="community-author">${p.avatarUrl?`<img src="${esc(p.avatarUrl)}" alt="">`:`<span class="community-avatar-fallback">${esc((p.autor_nombre||'U').slice(0,1).toUpperCase())}</span>`}<div><strong>${esc(p.autor_nombre||'Miembro del club')}</strong><small>${dtFmt(p.creado_en)} · ${daysLeft(p.expira_en)} días restantes</small></div>${p.estado==='oculta'?badge('Oculta','warn'):''}</header>
      ${p.texto?`<p class="community-copy">${esc(p.texto)}</p>`:''}
      <div class="community-media">${p.media_tipo==='video'?`<video controls playsinline preload="none" ${p.coverUrl?`poster="${esc(p.coverUrl)}"`:''} src="${esc(p.mediaUrl)}"></video>`:`<img loading="lazy" src="${esc(p.mediaUrl)}" alt="Publicación de ${esc(p.autor_nombre||'usuario')}">`}</div>
      <footer class="community-actions">${p.media_tipo==='video'&&canChangeCover()?`<button class="btn btn-ghost btn-sm community-cover" data-id="${esc(p.id)}">Cambiar portada</button>`:''}${p.autor_perfil_id===state.session?.id||canModerate()?`<button class="btn btn-ghost btn-sm community-delete" data-id="${esc(p.id)}">${icon('trash',{size:14})} Eliminar</button>`:''}${canModerate()&&p.autor_perfil_id!==state.session?.id?`<button class="btn btn-ghost btn-sm community-hide" data-id="${esc(p.id)}" data-hidden="${p.estado==='oculta'?'1':'0'}">${p.estado==='oculta'?'Mostrar':'Ocultar'}</button>`:''}</footer>
    </article>`).join('');
    setMainHtml(`${pageHeader('Comunidad','Momentos del club durante 30 días',`<button class="btn btn-primary" id="community-new" ${publishDisabled?'disabled':''}>${icon('plus',{size:16})} Publicar</button>`,'Club')}
      <section class="community-hero"><div><span class="page-kicker">COMUNIDAD URBAN WARRIORS</span><h2>Tu club también se vive aquí.</h2><p>Comparte una imagen o un vídeo de hasta 15 segundos. El contenido se elimina automáticamente a los 30 días.</p></div><div class="community-quota"><strong>${quota.used}/${quota.limit}</strong><span>publicaciones este mes</span></div></section>
      ${publishDisabled?`<div class="alert alert-warning"><strong>Límite mensual alcanzado</strong><span>Podrás volver a publicar el próximo mes.</span></div>`:''}
      <div class="community-feed">${cards||empty('Todavía no hay publicaciones','Sé la primera persona en compartir un momento del club.')}</div>
      ${communityDone?'':`<div class="community-load-more"><button class="btn btn-ghost" id="community-load-more">Cargar más</button><span id="community-sentinel" aria-hidden="true"></span></div>`}`);
    document.getElementById('community-new')?.addEventListener('click',()=>openForm({title:'Nueva publicación en Comunidad',subtitle:`Te quedan ${Math.max(0,quota.limit-quota.used)} publicaciones este mes. Caducará a los 30 días.`,width:'720px',fields:[{name:'texto',label:'Mensaje',type:'textarea',full:true,rows:4,placeholder:'Entrenamiento, competición, celebración…'},{name:'media',label:'Imagen o vídeo',type:'file',required:true,full:true,accept:'image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime',help:'Imagen optimizada automáticamente · vídeo máx. 50 MB, 15 s y 1080p.'},...(canChangeCover()?[{name:'manual_cover',label:'Portada manual (opcional, solo vídeo)',type:'file',full:true,accept:'image/jpeg,image/png,image/webp',help:'Si no eliges una, se genera automáticamente.'}]:[])],submitText:'Publicar',onSubmit:publishCommunity}));
    document.querySelectorAll('.community-delete').forEach(b=>b.addEventListener('click',()=>confirmDialog('Eliminar publicación','Se borrará también la imagen o vídeo almacenado.',async()=>{await repos.community.delete(b.dataset.id);toast('Publicación eliminada');await renderCommunity();},{confirmText:'Eliminar',danger:true})));
    document.querySelectorAll('.community-hide').forEach(b=>b.addEventListener('click',async()=>{try{await repos.community.moderate(b.dataset.id,b.dataset.hidden!=='1',b.dataset.hidden==='1'?'Reactivada por el club':'Ocultada por moderación');toast(b.dataset.hidden==='1'?'Publicación visible':'Publicación oculta');await renderCommunity();}catch(e){setError(e)}}));
    document.querySelectorAll('.community-cover').forEach(b=>b.addEventListener('click',()=>{const post=communityPosts.find(p=>p.id===b.dataset.id);if(post)changeVideoCover(post);}));
    const loadMore=()=>renderCommunity({append:true});document.getElementById('community-load-more')?.addEventListener('click',loadMore);
    const sentinel=document.getElementById('community-sentinel');if(sentinel&&'IntersectionObserver' in window){const observer=new IntersectionObserver(entries=>{if(entries.some(x=>x.isIntersecting)){observer.disconnect();loadMore();}},{rootMargin:'500px'});observer.observe(sentinel);}
  }catch(e){setError(e);if(!append)setMainHtml(`${pageHeader('Comunidad')} ${empty('No se pudo cargar la Comunidad',e.message)}`)}finally{communityLoading=false;}
}
