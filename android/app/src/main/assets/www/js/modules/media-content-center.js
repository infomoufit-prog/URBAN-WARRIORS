import { repos } from '../core/repositories.js';
import { esc, dtFmt, humanError } from '../core/utils.js';
import { setAppHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { openKombaxPublicProfile } from './public-profile.js';

const mediaLabel=type=>type==='video'?'Vídeo':type==='photo'?'Fotografía':type==='avatar'?'Avatar':type==='banner'?'Portada':'Contenido';

export async function renderMediaContentCenter(profile,{onBack=()=>{},onSocial=()=>{},onShowcase=()=>{}}={}){
  setAppHtml('<main class="kx-managed-hub"><div class="loading-card">Cargando Mi contenido…</div></main>');
  try{
    const [identities,album]=await Promise.all([
      repos.kombaxSocial.myProfiles(),
      repos.kombaxProfiles.album(profile.id)
    ]);
    const social=(identities||[]).find(row=>row.perfil_directo_id===profile.id&&row.perfil_tipo==='media');
    const posts=social?await repos.kombaxSocial.profilePosts(social.id,null,10):[];
    const assets=(album||[]).filter(row=>row.estado!=='removed'&&['photo','video'].includes(row.tipo));
    setAppHtml(`<main class="kx-managed-hub kx-media-content-center" data-profile-type="media">
      <header class="kx-managed-top"><button class="gateway-icon-button" id="kx-media-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button><div class="kx-managed-title"><span>MEDIA / CREADOR</span><strong>Mi contenido</strong></div><button class="btn btn-ghost btn-sm" id="kx-media-close" type="button">${icon('close',{size:16})} Cerrar</button></header>
      <section class="kx-managed-hero"><div class="kx-managed-icon">${icon('image',{size:48})}</div><div><span>ESTUDIO DE CONTENIDO</span><h1>${esc(profile.nombre_publico||'Mi contenido')}</h1><p>Gestiona tus publicaciones y tu material visual con la identidad Media / Creador. El contenido público y los datos privados de tu cuenta permanecen separados.</p></div></section>
      <div class="kx-media-content-actions"><button class="btn btn-primary" id="kx-media-publish">${icon('plus',{size:16})} Publicar en Social</button><button class="btn btn-ghost" id="kx-media-public-profile" ${social?'':'disabled'}>Ver mi perfil público</button><button class="btn btn-ghost" id="kx-media-showcase">Abrir Showcase</button></div>
      ${social?'':'<div class="kx-managed-boundary"><strong>Identidad Social pendiente</strong><p>Cuando tu identidad Media / Creador esté activa en Social, aquí aparecerán sus publicaciones. Puedes abrir Social para consultar los pasos de activación.</p></div>'}
      <section class="kx-media-content-section"><header><h2>Mis publicaciones</h2><small>Las 10 publicaciones más recientes · ${posts.length} visibles</small></header>${posts.length?`<div class="kx-media-content-list">${posts.map(row=>`<article><span>${esc(mediaLabel(row.media_tipo||row.tipo))}</span><strong>${esc((row.texto||'Publicación multimedia').slice(0,150))}</strong><small>${esc(dtFmt(row.creado_en))}${row.audiencia_label?` · ${esc(row.audiencia_label)}`:''}</small></article>`).join('')}</div>`:'<div class="empty-card compact"><strong>Aún no hay publicaciones visibles</strong><p>Crea tu primera publicación desde KOMBAX Social.</p></div>'}</section>
      <section class="kx-media-content-section"><header><h2>Álbum y material visual</h2><small>${assets.length} archivos · avatar y portada aparte</small></header>${assets.length?`<div class="kx-media-content-list">${assets.slice(0,10).map(row=>`<article><span>${esc(mediaLabel(row.tipo))}</span><strong>${esc(row.titulo||row.nombre||mediaLabel(row.tipo))}</strong><small>${esc(dtFmt(row.creado_en))}</small></article>`).join('')}</div>`:'<div class="empty-card compact"><strong>Álbum vacío</strong><p>Desde tu perfil público podrás añadir fotografías y vídeos a tu presentación.</p></div>'}</section>
    </main>`);
    document.getElementById('kx-media-back')?.addEventListener('click',onBack);
    document.getElementById('kx-media-close')?.addEventListener('click',onBack);
    document.getElementById('kx-media-publish')?.addEventListener('click',onSocial);
    document.getElementById('kx-media-showcase')?.addEventListener('click',onShowcase);
    document.getElementById('kx-media-public-profile')?.addEventListener('click',()=>social&&openKombaxPublicProfile(social.id));
  }catch(error){
    setAppHtml(`<main class="kx-managed-hub"><header class="kx-managed-top"><button class="gateway-icon-button" id="kx-media-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button><div class="kx-managed-title"><strong>Mi contenido</strong></div></header><div class="empty-card compact"><strong>No se pudo cargar el contenido</strong><p>${esc(humanError(error)||'Inténtalo de nuevo.')}</p></div></main>`);
    document.getElementById('kx-media-back')?.addEventListener('click',onBack);
  }
}
