import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc } from '../core/utils.js';
import { pageHeader, card, quickRow, empty, badge, openDetail, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const team=()=>['direccion','coordinacion','secretaria','economia','comunicacion','monitor'].includes(state.session?.rol);
const diffusion=()=>['direccion','coordinacion','secretaria'].includes(state.session?.rol);
const titleFor=(t)=>({condiciones_uso:'Condiciones de uso',privacidad:'Política de privacidad',comunidad:'Normas de Comunidad',derechos_imagen:'Autorización de imagen'})[t]||t;

const USER_MANUAL=[
  {src:'./assets/docs/manual-usuario/01_portada_manual_usuario.png',title:'Manual de uso',subtitle:'Portada y acceso visual a Urban Warriors'},
  {src:'./assets/docs/manual-usuario/02_funciones_principales.png',title:'Funciones principales',subtitle:'Sesiones, Comunidad, Finanzas y Material'}
];
const TEAM_MANUAL=[
  {src:'./assets/docs/manual-equipo/01_portada_equipo.png',title:'Manual del equipo',subtitle:'Guía visual de gestión Urban Warriors'},
  {src:'./assets/docs/manual-equipo/02_roles_permisos_acceso.png',title:'Roles y permisos',subtitle:'Gestor, Coordinación, Secretaría, Tesorería, Comunicación y Monitor'},
  {src:'./assets/docs/manual-equipo/03_gestion_alumnos.png',title:'Gestión de alumnos',subtitle:'Altas, edición, documentos y gestión del alumno'},
  {src:'./assets/docs/manual-equipo/04_gestion_sesiones.png',title:'Gestión de sesiones',subtitle:'Sesiones, recurrencia, sustituciones y cancelaciones'}
];

function legalBody(text){return `<div class="legal-document">${esc(text||'').replace(/\n\n/g,'</p><p>').replace(/^/,'<p>').replace(/$/,'</p>').replace(/\n/g,'<br>')}</div>`}
function manualGallery(pages,kind){
  return `<div class="manual-gallery ${kind==='team'?'manual-gallery-team':''}">${pages.map((p,i)=>`<button type="button" class="manual-page-card" data-manual-kind="${esc(kind)}" data-manual-index="${i}"><span class="manual-page-media"><img src="${esc(p.src)}" alt="${esc(p.title)}" loading="lazy"></span><span class="manual-page-copy"><strong>${esc(p.title)}</strong><small>${esc(p.subtitle)}</small><span>Ver página ${i+1} ${icon('eye',{size:14})}</span></span></button>`).join('')}</div>`;
}
function bindManualGallery(){
  document.querySelectorAll('.manual-page-card').forEach(btn=>btn.addEventListener('click',()=>{
    const pages=btn.dataset.manualKind==='team'?TEAM_MANUAL:USER_MANUAL;const idx=Number(btn.dataset.manualIndex||0);const p=pages[idx];
    openDetail({title:p.title,subtitle:`Página ${idx+1} de ${pages.length} · ${p.subtitle}`,width:'1180px',className:'manual-viewer-modal',body:`<div class="manual-viewer"><img src="${esc(p.src)}" alt="${esc(p.title)}"><div class="manual-viewer-nav">${idx>0?`<button type="button" class="btn btn-ghost manual-prev">${icon('chevronLeft',{size:16})} Anterior</button>`:'<span></span>'}<a class="btn btn-ghost" href="${esc(p.src)}" target="_blank">${icon('image',{size:16})} Abrir imagen</a>${idx<pages.length-1?`<button type="button" class="btn btn-primary manual-next">Siguiente ${icon('chevronRight',{size:16})}</button>`:'<span></span>'}</div></div>`});
    const reopen=(n)=>{document.querySelector(`.manual-page-card[data-manual-kind="${btn.dataset.manualKind}"][data-manual-index="${n}"]`)?.click()};
    document.querySelector('.manual-prev')?.addEventListener('click',()=>reopen(idx-1));
    document.querySelector('.manual-next')?.addEventListener('click',()=>reopen(idx+1));
  }));
}

export async function renderHelpLegal(){
  setMainHtml('<div class="loading-card">Cargando ayuda…</div>');
  try{
    const [docs,accepts]=await Promise.all([repos.legal.docs(),repos.legal.acceptances().catch(()=>[])]);const accepted=new Map(accepts.filter(a=>a.aceptado&&!a.revocado_en).map(a=>[`${a.tipo}:${a.version}`,a]));
    const staff=team();
    const manualCards=staff
      ? `${card('Manual de equipo · Uso y funcionamiento',`<p class="muted manual-intro">Formación principal para el equipo del club. Consulta visualmente los roles, la gestión de alumnos y el funcionamiento de las sesiones. Las páginas están guardadas dentro de Urban Warriors y no dependen de enlaces externos.</p>${manualGallery(TEAM_MANUAL,'team')}<div class="manual-secondary-link"><a class="btn btn-ghost" href="./assets/docs/Manual_Equipo_Urban_Warriors.pdf" target="_blank">${icon('fileText',{size:16})} Versión PDF de referencia</a></div>`)}${card('Manual de usuario · Para ayudar a alumnos y familias',`<p class="muted manual-intro">Referencia visual del entorno que utilizan alumnos y familias.</p>${manualGallery(USER_MANUAL,'user')}`)}`
      : card('Manual de usuario · Urban Warriors',`<p class="muted manual-intro">Tu guía visual para utilizar la aplicación: sesiones, Comunidad, finanzas, material y acceso habitual.</p>${manualGallery(USER_MANUAL,'user')}<div class="manual-secondary-link"><a class="btn btn-ghost" href="./assets/docs/Manual_Usuario_Urban_Warriors.pdf" target="_blank">${icon('fileText',{size:16})} Versión PDF de referencia</a></div>`);
    const diffusionResource=diffusion()?card('Material de difusión del club',quickRow(icon('qr'),'Cartel de descarga del club','Solo Gestor, Coordinación y Secretaría','<a class="btn btn-ghost btn-sm" href="./assets/docs/Cartel_Guia_Rapida_Usuarios.png" target="_blank">Abrir cartel</a>')):'';
    const legal=docs.map(d=>quickRow(icon(d.tipo==='privacidad'?'shieldCheck':d.tipo==='derechos_imagen'?'image':'fileText'),titleFor(d.tipo),`Versión ${d.version}`,`${accepted.has(`${d.tipo}:${d.version}`)?badge('Aceptado','ok'):badge(d.tipo==='derechos_imagen'?'Opcional':'Consultar','neutral')} <button class="btn btn-ghost btn-sm legal-open" data-id="${esc(d.id)}">Leer</button>`)).join('');
    setMainHtml(`${pageHeader(staff?'Manual, ayuda y condiciones':'Ayuda y condiciones',staff?'Formación operativa, recursos y documentos de uso':'Manual de uso, privacidad y documentos de la aplicación','','Ayuda')}${manualCards}${diffusionResource}${card('Condiciones y privacidad',legal||empty('Sin textos legales vigentes'))}${card('Privacidad y consentimiento',`<p class="muted">La autorización de imagen es independiente de las funciones esenciales de la aplicación. Puedes consultarla y retirar el consentimiento para usos futuros desde este apartado.</p>${docs.find(d=>d.tipo==='derechos_imagen')?`<button class="btn btn-ghost" id="image-consent-toggle">${accepted.has(`derechos_imagen:${docs.find(d=>d.tipo==='derechos_imagen').version}`)?'Retirar autorización de imagen':'Autorizar uso de imagen dentro de Urban Warriors'}</button>`:''}`)}`);
    bindManualGallery();
    document.querySelectorAll('.legal-open').forEach(b=>b.addEventListener('click',()=>{const d=docs.find(x=>x.id===b.dataset.id);openDetail({title:titleFor(d.tipo),subtitle:`Versión ${d.version}`,body:legalBody(d.cuerpo),width:'900px'});}));
    const image=docs.find(d=>d.tipo==='derechos_imagen');document.getElementById('image-consent-toggle')?.addEventListener('click',async()=>{try{const on=!accepted.has(`derechos_imagen:${image.version}`);await repos.legal.accept('derechos_imagen',image.version,on);toast(on?'Autorización registrada':'Autorización retirada');await renderHelpLegal();}catch(e){setError(e)}});
  }catch(e){setError(e);setMainHtml(`${pageHeader('Ayuda y condiciones')} ${empty('No se pudo cargar la ayuda',e.message)}`)}
}
