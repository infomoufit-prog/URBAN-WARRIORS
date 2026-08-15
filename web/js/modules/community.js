import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, dtFmt } from '../core/utils.js';
import { pageHeader, card, empty, badge, openForm, openDetail, closeModal, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { optimizeImage, formatMediaBytes, prepareVideo } from '../core/media.js';
import { openSportsProfile, loadSportsProfiles } from './sports-profile.js';
import { openClubPublicProfile, openPublicDirectory } from './club-profile.js';

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
  let profiles=[];try{profiles=await loadSportsProfiles()}catch{}
  const profileMap=new Map((profiles||[]).map(p=>[p.socio_id,p]));
  return Promise.all(posts.map(async p=>{let mediaUrl='',avatarUrl='',coverUrl='';const sportsProfile=p.autor_socio_id?profileMap.get(p.autor_socio_id):null;try{mediaUrl=await repos.community.mediaUrl(p.media_path)}catch{}try{if(sportsProfile?.fotoUrl)avatarUrl=sportsProfile.fotoUrl;else if(p.autor_avatar_path)avatarUrl=await repos.settings.avatarUrl(p.autor_avatar_path)}catch{}try{const coverPath=p.portada_manual_path||p.portada_automatica_path;if(coverPath)coverUrl=await repos.community.mediaUrl(coverPath)}catch{}return {...p,mediaUrl,avatarUrl,coverUrl,sportsProfile};}));
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
    toast('Publicado en Comunidad del Club');await renderCommunity();
  }catch(error){await cleanupPaths(uploaded);throw error;}
}

const REPORT_REASONS=[
  {value:'acoso',label:'Acoso o intimidación'},
  {value:'odio_discriminacion',label:'Odio o discriminación'},
  {value:'violencia',label:'Violencia o amenazas'},
  {value:'sexual_menores',label:'Contenido sexual o riesgo para menores'},
  {value:'privacidad',label:'Privacidad o datos personales'},
  {value:'spam',label:'Spam o contenido engañoso'},
  {value:'suplantacion',label:'Suplantación de identidad'},
  {value:'otro',label:'Otro motivo'}
];

function reportCommunityTarget({postId,authorId,name=''}){
  openForm({title:'Denunciar en Comunidad del Club',subtitle:name?`La denuncia relacionada con ${name} será revisada por el equipo autorizado.`:'La denuncia será revisada por el equipo autorizado.',width:'600px',fields:[{name:'objetivo_tipo',label:'¿Qué quieres denunciar?',type:'select',required:true,value:'publicacion',options:[{value:'publicacion',label:'Esta publicación'},{value:'perfil',label:'El perfil del autor'}]},{name:'motivo',label:'Motivo',type:'select',required:true,options:REPORT_REASONS},{name:'detalle',label:'Explica brevemente qué ocurre',type:'textarea',rows:4,full:true,placeholder:'Añade contexto útil para la revisión.'}],submitText:'Enviar denuncia',onSubmit:async v=>{const id=v.objetivo_tipo==='perfil'?authorId:postId;await repos.community.report(v.objetivo_tipo,id,v.motivo,v.detalle||'');toast('Denuncia enviada para revisión');}});
}

async function openBlockedProfiles(){
  try{
    const rows=await repos.community.blocked();
    const body=rows?.length?`<div class="community-safety-list">${rows.map(r=>`<div class="community-safety-row"><div><strong>${esc(r.nombre||'Perfil bloqueado')}</strong><small>Sus publicaciones quedan ocultas para ti en la Comunidad del Club.</small></div><button class="btn btn-ghost btn-sm unblock-community" data-id="${esc(r.perfil_id)}">Desbloquear</button></div>`).join('')}</div>`:empty('No has bloqueado ningún perfil');
    const modal=openDetail({title:'Perfiles bloqueados',subtitle:'El bloqueo solo afecta a la experiencia social; no oculta avisos administrativos del club.',body,width:'650px'});
    modal.wrap.querySelectorAll('.unblock-community').forEach(b=>b.addEventListener('click',async()=>{try{b.disabled=true;await repos.community.block(b.dataset.id,false);toast('Perfil desbloqueado');closeModal();await renderCommunity();}catch(e){setError(e);b.disabled=false;}}));
  }catch(e){setError(e)}
}

async function openCommunityReports(){
  try{
    const rows=await repos.community.reports();
    const active=(rows||[]).filter(r=>['pendiente','en_revision'].includes(r.estado));
    const body=active.length?`<div class="community-safety-list">${active.map(r=>`<div class="community-report-row"><div><span class="page-kicker">${esc(r.objetivo_tipo)} · ${esc(r.motivo)}</span><strong>${esc(r.objetivo_nombre||'Contenido denunciado')}</strong>${r.objetivo_resumen?`<p>${esc(r.objetivo_resumen)}</p>`:''}<small>${dtFmt(r.creado_en)} · ${esc(r.estado)}${r.identidad_social_estado?` · acceso social ${esc(r.identidad_social_estado)}`:''}</small></div><div class="row-actions"><button class="btn btn-ghost btn-sm report-review" data-id="${esc(r.id)}">En revisión</button><button class="btn btn-ghost btn-sm report-dismiss" data-id="${esc(r.id)}">Descartar</button>${r.objetivo_tipo==='publicacion'?`<button class="btn btn-danger btn-sm report-hide" data-id="${esc(r.id)}">Ocultar y resolver</button>`:''}${r.identidad_social_estado==='activa'&&r.objetivo_perfil_id?`<button class="btn btn-danger btn-sm social-access-moderate" data-profile="${esc(r.objetivo_perfil_id)}" data-state="suspendida" data-name="${esc(r.objetivo_nombre||'perfil')}">Suspender acceso social</button>`:''}${r.identidad_social_estado==='suspendida'&&r.objetivo_perfil_id?`<button class="btn btn-ghost btn-sm social-access-moderate" data-profile="${esc(r.objetivo_perfil_id)}" data-state="activa" data-name="${esc(r.objetivo_nombre||'perfil')}">Reactivar acceso social</button>`:''}</div></div>`).join('')}</div>`:empty('Sin denuncias pendientes','No hay contenido que requiera revisión en este momento.');
    const modal=openDetail({title:'Denuncias de la Comunidad del Club',subtitle:'Revisión interna y trazable del contenido generado por usuarios.',body,width:'850px'});
    const act=async(id,estado,opts={})=>{await repos.community.reportStatus(id,estado,opts);toast(estado==='descartada'?'Denuncia descartada':estado==='en_revision'?'Marcada en revisión':'Denuncia resuelta');closeModal();await renderCommunity();};
    modal.wrap.querySelectorAll('.report-review').forEach(b=>b.addEventListener('click',()=>act(b.dataset.id,'en_revision',{resolucion:'En revisión por el equipo del club.'}).catch(setError)));
    modal.wrap.querySelectorAll('.report-dismiss').forEach(b=>b.addEventListener('click',()=>act(b.dataset.id,'descartada',{resolucion:'Revisada y descartada por el equipo del club.'}).catch(setError)));
    modal.wrap.querySelectorAll('.report-hide').forEach(b=>b.addEventListener('click',()=>confirmDialog('Ocultar publicación denunciada','La publicación quedará oculta y la denuncia se marcará como resuelta.',()=>act(b.dataset.id,'resuelta',{resolucion:'Contenido ocultado tras revisión de la denuncia.',ocultar_publicacion:true}),{confirmText:'Ocultar y resolver',danger:true})));
    modal.wrap.querySelectorAll('.social-access-moderate').forEach(b=>b.addEventListener('click',()=>openForm({title:b.dataset.state==='suspendida'?'Suspender acceso a Social Community':'Reactivar acceso a Social Community',subtitle:`Esta medida afecta solo al servicio social general de ${b.dataset.name||'este perfil'}; no bloquea su acceso administrativo al club.`,width:'580px',fields:[{name:'motivo',label:'Motivo',type:'textarea',required:true,rows:4,full:true,placeholder:'Describe el motivo de la decisión para dejar trazabilidad.'}],submitText:b.dataset.state==='suspendida'?'Suspender acceso':'Reactivar acceso',onSubmit:async v=>{await repos.socialGeneral.moderateAccess(b.dataset.profile,b.dataset.state,v.motivo);toast(b.dataset.state==='suspendida'?'Acceso social suspendido':'Acceso social reactivado');closeModal();await renderCommunity();}})));
  }catch(e){setError(e)}
}

function changeVideoCover(post){
  openForm({title:'Cambiar portada',subtitle:'La nueva portada sustituirá a la manual actual. La automática se conserva como respaldo.',width:'560px',fields:[{name:'cover',label:'Nueva portada',type:'file',required:true,full:true,accept:'image/jpeg,image/png,image/webp',help:'Se optimizará automáticamente.'}],submitText:'Guardar portada',onSubmit:async values=>{
    const image=await optimizeImage(values.cover,{maxEdge:1280,maxBytes:1024*1024});const path=await repos.community.upload(image.file);
    try{const out=await repos.community.changeCover(post.id,path);if(out?.old_cover_path&&out.old_cover_path!==path)await repos.community.removePath(out.old_cover_path).catch(()=>{});toast('Portada actualizada');await renderCommunity();}
    catch(error){await repos.community.removePath(path).catch(()=>{});throw error;}
  }});
}

async function openCommunityPublishWithRules(quota){
  const openPublisher=()=>openForm({title:'Nueva publicación en la Comunidad del Club',subtitle:`Te quedan ${Math.max(0,quota.limit-quota.used)} publicaciones este mes. Caducará a los 30 días.`,width:'720px',fields:[{name:'texto',label:'Mensaje',type:'textarea',full:true,rows:4,placeholder:'Entrenamiento, competición, celebración…'},{name:'media',label:'Imagen o vídeo',type:'file',required:true,full:true,accept:'image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime',help:'Imagen optimizada automáticamente · vídeo máx. 50 MB, 15 s y 1080p.'},...(canChangeCover()?[{name:'manual_cover',label:'Portada manual (opcional, solo vídeo)',type:'file',full:true,accept:'image/jpeg,image/png,image/webp',help:'Si no eliges una, se genera automáticamente.'}]:[])],submitText:'Publicar',onSubmit:publishCommunity});
  try{
    const [docs,accepts]=await Promise.all([repos.legal.docs(),repos.legal.acceptances().catch(()=>[])]);
    const rules=(docs||[]).find(d=>d.tipo==='comunidad');
    if(!rules)throw new Error('Las Normas de Comunidad del Club vigentes no están disponibles.');
    const accepted=(accepts||[]).some(a=>a.tipo==='comunidad'&&a.version===rules.version&&a.texto_legal_id===rules.id&&a.aceptado&&!a.revocado_en);
    if(accepted){openPublisher();return;}
    const modal=openDetail({title:'Normas de Comunidad del Club',subtitle:`Versión ${rules.version} · Debes aceptarlas antes de publicar`,width:'820px',body:`<div class="legal-document"><p>${esc(rules.cuerpo||'').replace(/\n\n/g,'</p><p>').replace(/\n/g,'<br>')}</p></div>`,actions:'<button class="btn btn-primary" id="community-rules-accept">Aceptar y continuar</button>'});
    modal.wrap.querySelector('#community-rules-accept')?.addEventListener('click',async()=>{try{const b=modal.wrap.querySelector('#community-rules-accept');b.disabled=true;await repos.legal.accept('comunidad',rules.version,true);closeModal();openPublisher();}catch(e){setError(e);}});
  }catch(e){setError(e);}
}

export async function renderCommunity({append=false}={}){
  if(communityLoading)return;
  communityLoading=true;
  if(!append){communityPosts=[];communityCursor=null;communityDone=false;setMainHtml('<div class="loading-card">Cargando comunidad…</div>');}
  try{
    const [raw,quota,blockedRows]=await Promise.all([repos.community.listPage(communityCursor,PAGE_SIZE),repos.community.quota(),repos.community.blocked().catch(()=>[])]);
    const blockedSet=new Set((blockedRows||[]).map(x=>x.perfil_id));
    const page=await enrich(raw.filter(p=>new Date(p.expira_en).getTime()>Date.now()&&!blockedSet.has(p.autor_perfil_id)));
    const merged=new Map(communityPosts.map(p=>[p.id,p]));for(const p of page)merged.set(p.id,p);communityPosts=[...merged.values()];
    const last=raw.at(-1);communityCursor=last?{created:last.creado_en,id:last.id}:communityCursor;communityDone=raw.length<PAGE_SIZE;
    const posts=communityPosts;
    const publishDisabled=quota.used>=quota.limit;
    const cards=posts.map(p=>`<article class="community-post ${p.estado==='oculta'?'community-hidden':''}">
      <header class="community-author ${p.sportsProfile?'community-author-clickable':''}" ${p.sportsProfile?`data-author-socio="${esc(p.autor_socio_id)}" role="button" tabindex="0" aria-label="Ver perfil deportivo de ${esc(p.autor_nombre||'miembro')}"`:''}>${p.avatarUrl?`<img src="${esc(p.avatarUrl)}" alt="">`:`<span class="community-avatar-fallback">${esc((p.autor_nombre||'U').slice(0,1).toUpperCase())}</span>`}<div><strong>${esc(p.sportsProfile?.apodo||p.autor_nombre||'Miembro del club')}</strong><small>${dtFmt(p.creado_en)} · ${daysLeft(p.expira_en)} días restantes${p.sportsProfile?' · Ver perfil':''}</small></div>${p.estado==='oculta'?badge('Oculta','warn'):''}</header>
      ${p.texto?`<p class="community-copy">${esc(p.texto)}</p>`:''}
      <div class="community-media">${p.media_tipo==='video'?`<video controls playsinline preload="none" ${p.coverUrl?`poster="${esc(p.coverUrl)}"`:''} src="${esc(p.mediaUrl)}"></video>`:`<img loading="lazy" src="${esc(p.mediaUrl)}" alt="Publicación de ${esc(p.autor_nombre||'usuario')}">`}</div>
      <footer class="community-actions"><button type="button" class="community-like ${p.likedByMe?'active':''}" data-like-id="${esc(p.id)}" data-liked="${p.likedByMe?'1':'0'}" aria-pressed="${p.likedByMe?'true':'false'}" aria-label="${p.likedByMe?'Quitar like':'Dar like'}"><span aria-hidden="true">♥</span><b data-like-count>${Number(p.likes_count||0)}</b></button><div class="community-admin-actions">${p.media_tipo==='video'&&canChangeCover()?`<button class="btn btn-ghost btn-sm community-cover" data-id="${esc(p.id)}">Cambiar portada</button>`:''}${p.autor_perfil_id===state.session?.id||canModerate()?`<button class="btn btn-ghost btn-sm community-delete" data-id="${esc(p.id)}">${icon('trash',{size:14})} Eliminar</button>`:''}${canModerate()&&p.autor_perfil_id!==state.session?.id?`<button class="btn btn-ghost btn-sm community-hide" data-id="${esc(p.id)}" data-hidden="${p.estado==='oculta'?'1':'0'}">${p.estado==='oculta'?'Mostrar':'Ocultar'}</button>`:''}${p.autor_perfil_id!==state.session?.id?`<button class="btn btn-ghost btn-sm community-report" data-id="${esc(p.id)}" data-author="${esc(p.autor_perfil_id)}" data-name="${esc(p.autor_nombre||'usuario')}">Denunciar</button><button class="btn btn-ghost btn-sm community-block" data-author="${esc(p.autor_perfil_id)}" data-name="${esc(p.autor_nombre||'usuario')}">Bloquear</button>`:''}</div></footer>
    </article>`).join('');
    setMainHtml(`${pageHeader('Comunidad del Club','Momentos internos del club durante 30 días',`<button class="btn btn-ghost" id="community-members">${icon('users',{size:16})} Perfiles</button><button class="btn btn-ghost" id="community-blocked">Bloqueados</button>${canModerate()?'<button class="btn btn-ghost" id="community-reports">Denuncias</button>':''}<button class="btn btn-primary" id="community-new" ${publishDisabled?'disabled':''}>${icon('plus',{size:16})} Publicar</button>`,'Club')}
      <section class="community-hero"><div><span class="page-kicker">COMUNIDAD DEL CLUB · <button type="button" class="community-club-name" id="community-club-profile" aria-label="Abrir perfil público de ${esc(state.session?.club?.nombre||'Urban Warriors')}">${esc(String(state.session?.club?.nombre||'Urban Warriors').toUpperCase())}</button></span><h2>Tu club también se vive aquí.</h2><p>Comparte una imagen o un vídeo de hasta 15 segundos. El contenido se elimina automáticamente a los 30 días.</p></div><div class="community-quota"><strong>${quota.used}/${quota.limit}</strong><span>publicaciones este mes</span></div></section>
      ${publishDisabled?`<div class="alert alert-warning"><strong>Límite mensual alcanzado</strong><span>Podrás volver a publicar el próximo mes.</span></div>`:''}
      <div class="community-feed">${cards||empty('Todavía no hay publicaciones','Sé la primera persona en compartir un momento del club.')}</div>
      ${communityDone?'':`<div class="community-load-more"><button class="btn btn-ghost" id="community-load-more">Cargar más</button><span id="community-sentinel" aria-hidden="true"></span></div>`}`);
    document.getElementById('community-members')?.addEventListener('click',()=>openPublicDirectory());
    document.getElementById('community-blocked')?.addEventListener('click',()=>openBlockedProfiles());
    document.getElementById('community-reports')?.addEventListener('click',()=>openCommunityReports());
    document.getElementById('community-club-profile')?.addEventListener('click',()=>openClubPublicProfile(state.session?.club_id));
    document.querySelectorAll('[data-author-socio]').forEach(el=>{const open=()=>openSportsProfile(el.dataset.authorSocio);el.addEventListener('click',open);el.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();open();}});});
    document.querySelectorAll('[data-like-id]').forEach(button=>button.addEventListener('click',async()=>{if(button.disabled)return;button.disabled=true;try{const next=button.dataset.liked!=='1';const out=await repos.community.like(button.dataset.likeId,next);const liked=out?.liked===true;const count=Math.max(0,Number(out?.likes_count||0));button.dataset.liked=liked?'1':'0';button.classList.toggle('active',liked);button.setAttribute('aria-pressed',String(liked));button.setAttribute('aria-label',liked?'Quitar like':'Dar like');button.querySelector('[data-like-count]').textContent=String(count);const post=communityPosts.find(p=>p.id===button.dataset.likeId);if(post){post.likedByMe=liked;post.likes_count=count;}}catch(e){setError(e)}finally{button.disabled=false;}}));
    document.getElementById('community-new')?.addEventListener('click',()=>openCommunityPublishWithRules(quota));
    document.querySelectorAll('.community-delete').forEach(b=>b.addEventListener('click',()=>confirmDialog('Eliminar publicación','Se borrará también la imagen o vídeo almacenado.',async()=>{await repos.community.delete(b.dataset.id);toast('Publicación eliminada');await renderCommunity();},{confirmText:'Eliminar',danger:true})));
    document.querySelectorAll('.community-hide').forEach(b=>b.addEventListener('click',async()=>{try{await repos.community.moderate(b.dataset.id,b.dataset.hidden!=='1',b.dataset.hidden==='1'?'Reactivada por el club':'Ocultada por moderación');toast(b.dataset.hidden==='1'?'Publicación visible':'Publicación oculta');await renderCommunity();}catch(e){setError(e)}}));
    document.querySelectorAll('.community-cover').forEach(b=>b.addEventListener('click',()=>{const post=communityPosts.find(p=>p.id===b.dataset.id);if(post)changeVideoCover(post);}));
    document.querySelectorAll('.community-report').forEach(b=>b.addEventListener('click',()=>reportCommunityTarget({postId:b.dataset.id,authorId:b.dataset.author,name:b.dataset.name})));
    document.querySelectorAll('.community-block').forEach(b=>b.addEventListener('click',()=>confirmDialog('Bloquear perfil',`Dejarás de ver las publicaciones de ${b.dataset.name||'este perfil'} en la Comunidad del Club. Los avisos administrativos del club no se bloquean.`,async()=>{await repos.community.block(b.dataset.author,true);toast('Perfil bloqueado');await renderCommunity();},{confirmText:'Bloquear',danger:true})));
    const loadMore=()=>renderCommunity({append:true});document.getElementById('community-load-more')?.addEventListener('click',loadMore);
    const sentinel=document.getElementById('community-sentinel');if(sentinel&&'IntersectionObserver' in window){const observer=new IntersectionObserver(entries=>{if(entries.some(x=>x.isIntersecting)){observer.disconnect();loadMore();}},{rootMargin:'500px'});observer.observe(sentinel);}
  }catch(e){setError(e);if(!append)setMainHtml(`${pageHeader('Comunidad del Club')} ${empty('No se pudo cargar la Comunidad del Club',e.message)}`)}finally{communityLoading=false;}
}
