import { state } from '../core/state.js';
import { repos } from '../core/repositories.js';
import { esc } from '../core/utils.js';
import { pageHeader, setMainHtml, empty, toast, setError, openForm } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { openClubPublicProfile, openClubAlbum, editClubPublicProfile } from './club-profile.js';
import { openKombaxPublicProfile } from './public-profile.js';
import { openAuthenticatedPasswordChange } from './account-security.js';

const PERMISSIONS=[
  ['social.act_as_club','Publicar y actuar como Club'],['profile.public.manage','Editar perfil público'],['showcase.manage','Gestionar Showcase'],['relations.manage','Gestionar Mi red'],['contacts.manage','Gestionar contactos']
];
function go(route){location.hash=`#${route}`;}
async function clubSocialProfile(){const rows=await repos.kombaxSocial.myProfiles();return rows.find(x=>x.sujeto_tipo==='club'&&String(x.club_id)===String(state.session?.club_id))||null;}
async function editPermissions(){
  try{
    const rows=await repos.kombaxIdentity.team();
    const targetOptions=rows.filter(x=>x.rol!=='direccion').map(x=>({value:x.perfil_id,label:`${x.nombre||'Miembro'} · ${x.coordinacion?'Coordinación':x.rol}`}));
    if(!targetOptions.length){toast('No hay otros miembros del equipo para configurar.');return;}
    openForm({title:'Permisos KOMBAX del equipo',subtitle:'Estos permisos permiten actuar públicamente en nombre del Club. Toda acción conserva el usuario real en auditoría.',fields:[{name:'perfil_id',label:'Miembro del equipo',type:'select',required:true,options:targetOptions},{name:'permiso',label:'Permiso',type:'select',required:true,options:PERMISSIONS.map(([value,label])=>({value,label}))},{name:'activo',label:'Conceder permiso',type:'checkbox',value:true,full:true}],submitText:'Guardar permiso',onSubmit:async v=>{await repos.kombaxIdentity.setTeamPermission(v.perfil_id,v.permiso,v.activo===true);toast('Permiso actualizado');await renderClubKombaxHub();}});
  }catch(error){setError(error);}
}
function card(id,title,text,ico,actionLabel='Abrir'){
  return `<article class="kx-hub-card"><div class="kx-hub-icon">${icon(ico,{size:24})}</div><div><h3>${esc(title)}</h3><p>${esc(text)}</p></div><button type="button" class="btn btn-ghost" data-kx-hub="${esc(id)}">${esc(actionLabel)}</button></article>`;
}
export async function renderClubKombaxHub(){
  const club=state.session?.club;if(!club){setMainHtml(empty('Club no disponible','Selecciona un club para gestionar su identidad KOMBAX.'));return;}
  let publicProfile=null,social=null,album=[];
  try{[publicProfile,social,album]=await Promise.all([repos.clubPublic.one(state.session.club_id).catch(()=>null),clubSocialProfile().catch(()=>null),repos.clubPublic.album(state.session.club_id).catch(()=>[])]);}catch{}
  const photos=(album||[]).filter(x=>x.tipo==='photo'&&x.estado!=='removed').length,videos=(album||[]).filter(x=>x.tipo==='video'&&x.estado!=='removed').length;
  const acting=social?`${social.nombre_publico||club.nombre} · Club`:`${publicProfile?.nombre_publico||club.nombre} · Club`;
  setMainHtml(`<div class="kx-club-hub">
    ${pageHeader('Perfil del Club','Gestiona la presencia pública de tu club y mantén separada la información interna.','','KOMBAX')}
    <section class="kx-acting-banner"><div>${icon('shieldCheck',{size:24})}</div><div><small>ESTÁS GESTIONANDO</small><strong>${esc(acting)}</strong><span>Las acciones públicas se atribuyen al Club; KOMBAX registra internamente qué miembro del equipo las realiza.</span></div></section>
    <section class="kx-hub-summary"><div class="kx-hub-brand">${publicProfile?.logo_url?`<img src="${esc(publicProfile.logo_url)}" alt="">`:`<span>${esc((club.nombre||'C').slice(0,2).toUpperCase())}</span>`}</div><div><span class="page-kicker">PERFIL PÚBLICO KOMBAX</span><h2>${esc(publicProfile?.nombre_publico||club.nombre)}</h2><p>${esc(publicProfile?.descripcion||club.lema||'Completa el perfil público para presentar el club en KOMBAX.')}</p><div class="kx-hub-stats"><span>${photos}/10 fotos</span><span>${videos}/3 vídeos</span><span>${social?'Social activo':'Social pendiente'}</span></div></div><button class="btn btn-primary" id="kx-hub-public-preview">Ver como público</button></section>
    <div class="kx-hub-grid">
      ${card('public','Perfil público','Logo, banner, descripción, disciplinas, ubicación, enlaces y datos visibles.','user','Gestionar')}
      ${card('album','Álbum','Hasta 10 fotos y 3 vídeos de 15 segundos. Avatar y portada no cuentan.','image','Gestionar')}
      ${card('community','Comunidad del Club','Publicaciones internas para miembros del club. No se muestran automáticamente en la red pública.','users','Abrir comunidad')}
      ${card('social','KOMBAX Social','Publica texto, fotos y vídeos en la red pública utilizando la identidad del Club.','activity','Ir a Social')}
      ${card('showcase','Showcase','Productos y servicios informativos con contacto, web, tienda externa y guardados.','shoppingBag','Gestionar')}
      ${card('relations','Mi red','Federaciones, competidores, marcas y profesionales conectados de forma privada y confirmada.','network','Gestionar')}
      ${card('contacts','Contactos','Solicitudes estructuradas recibidas y enviadas como Club.','message','Gestionar')}
      ${state.session?.rol==='direccion'?card('permissions','Permisos del equipo','Decide quién puede actuar como Club y gestionar cada área pública.','shield','Configurar'):''}
      ${card('personal','Mi perfil personal','Tu cuenta personal permanece separada de la identidad pública del Club.','user','Abrir')}
      ${card('security','Seguridad y acceso','Cambia la contraseña de tu cuenta personal verificando primero la contraseña actual.','lock','Cambiar contraseña')}
    </div>
    <section class="kx-internal-separation"><div>${icon('lock',{size:22})}</div><div><strong>Información interna separada</strong><p>Alumnos, cuotas, asistencia, documentación, teléfonos, emails y datos familiares nunca forman parte del perfil público KOMBAX.</p></div></section>
  </div>`);
  document.getElementById('kx-hub-public-preview')?.addEventListener('click',()=>social?openKombaxPublicProfile(social.id):openClubPublicProfile(state.session.club_id));
  document.querySelectorAll('[data-kx-hub]').forEach(b=>b.addEventListener('click',async()=>{
    const a=b.dataset.kxHub;
    if(a==='community')go('community');
    else if(a==='public'){if(publicProfile?.editable)editClubPublicProfile(publicProfile);else openClubPublicProfile(state.session.club_id);}
    else if(a==='album'){const p=publicProfile||await repos.clubPublic.one(state.session.club_id);if(p)openClubAlbum(p);}
    else if(a==='social')go('social');
    else if(a==='showcase')go('showcase');
    else if(a==='relations'){sessionStorage.setItem('kombax_social_view','relations');go('social');}
    else if(a==='contacts'){sessionStorage.setItem('kombax_social_view','contacts');go('social');}
    else if(a==='permissions')editPermissions();
    else if(a==='personal')go('personal-profile');
    else if(a==='security')openAuthenticatedPasswordChange({onComplete:()=>location.reload()});
  }));
}
