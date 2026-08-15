import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc } from '../core/utils.js';
import { openForm, openDetail, toast, setError } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const canModerate=()=>['direccion','coordinacion','secretaria','comunicacion'].includes(state.session?.rol);
const initials=(p)=>`${p?.nombre?.[0]||''}${p?.apellidos?.[0]||''}`.toUpperCase()||'UW';
const disciplines=(p)=>Array.isArray(p?.disciplinas)?p.disciplinas:[];
const officialLine=(p)=>disciplines(p).map(d=>[d.disciplina,d.grado,d.grupo].filter(Boolean).join(' · ')).filter(Boolean).join(' / ')||'Sin disciplina oficial activa';

async function withPhoto(profile){
  if(!profile)return null;
  let fotoUrl='';
  if(profile.foto_path){try{fotoUrl=await repos.sportsProfiles.photoUrl(profile.foto_path)}catch{}}
  return {...profile,fotoUrl};
}

export async function loadSportsProfile(socioId){
  return withPhoto(await repos.sportsProfiles.one(socioId));
}

export async function loadSportsProfiles(){
  const rows=await repos.sportsProfiles.list();
  return Promise.all((rows||[]).map(withPhoto));
}

export function sportsProfileCompactHtml(profile,{showEdit=false}={}){
  if(!profile)return '<div class="sports-profile-empty"><strong>Perfil deportivo aún no publicado</strong><small>El alumno o su tutor puede completarlo cuando quiera.</small></div>';
  return `<div class="sports-profile-card-compact">
    <div class="sports-profile-photo">${profile.fotoUrl?`<img src="${esc(profile.fotoUrl)}" alt="">`:`<span>${esc(initials(profile))}</span>`}</div>
    <div class="sports-profile-compact-copy"><span class="page-kicker">PERFIL DEPORTIVO</span><h3>${esc(profile.apodo||`${profile.nombre||''} ${profile.apellidos||''}`.trim())}</h3><p>${esc(officialLine(profile))}</p>${profile.presentacion?`<small>${esc(profile.presentacion)}</small>`:''}</div>
    ${showEdit&&profile.editable?`<button class="btn btn-primary btn-sm" type="button" data-edit-sports-profile="${esc(profile.socio_id)}">${icon('edit',{size:14})} Editar</button>`:''}
  </div>`;
}

function detailBody(p){
  const rows=[
    ['Experiencia',p.experiencia_anos!=null?`${Number(p.experiencia_anos)} años`:''],
    ['Guardia',p.guardia],['Técnica favorita',p.tecnica_favorita],['Especialidad',p.especialidad],['Categoría competitiva',p.categoria_competitiva]
  ].filter(([,v])=>String(v??'').trim());
  return `<div class="sports-profile-detail">
    <div class="sports-profile-identity"><div class="sports-profile-photo sports-profile-photo-xl">${p.fotoUrl?`<img src="${esc(p.fotoUrl)}" alt="">`:`<span>${esc(initials(p))}</span>`}</div><div><span class="page-kicker">MIEMBRO DEL CLUB</span><h2>${esc(`${p.nombre||''} ${p.apellidos||''}`.trim())}</h2>${p.apodo?`<strong class="sports-nickname">“${esc(p.apodo)}”</strong>`:''}<p>${esc(officialLine(p))}</p></div></div>
    ${p.presentacion?`<div class="sports-profile-about"><h3>Sobre mí</h3><p>${esc(p.presentacion)}</p></div>`:''}
    ${rows.length?`<div class="sports-profile-facts">${rows.map(([k,v])=>`<div><span>${esc(k)}</span><strong>${esc(v)}</strong></div>`).join('')}</div>`:''}
    ${p.competiciones_logros?`<div class="sports-profile-section"><h3>Competiciones y logros</h3><p>${esc(p.competiciones_logros)}</p></div>`:''}
    ${p.objetivos?`<div class="sports-profile-section"><h3>Objetivos deportivos</h3><p>${esc(p.objetivos)}</p></div>`:''}
    ${p.moderado?'<div class="alert alert-warning"><strong>Perfil oculto por moderación</strong><span>El contenido no es visible para el resto del club hasta que se retire el bloqueo.</span></div>':p.visible===false?'<div class="alert alert-warning"><strong>Perfil privado</strong><span>El alumno o tutor ha decidido no compartirlo todavía con el resto del club.</span></div>':''}
  </div>`;
}

export async function openSportsProfile(socioId,{onChanged=null}={}){
  try{
    const p=await loadSportsProfile(socioId);
    if(!p){toast('Este miembro todavía no tiene un perfil deportivo visible.','error');return null;}
    const actions=[];
    if(p.editable)actions.push(`<button class="btn btn-primary" id="sports-detail-edit">${icon('edit',{size:15})} Editar perfil</button>`);
    if(canModerate())actions.push(`<button class="btn btn-ghost" id="sports-detail-moderate">${p.moderado?'Retirar bloqueo':'Ocultar por moderación'}</button>`);
    const modal=openDetail({title:p.apodo||`${p.nombre||''} ${p.apellidos||''}`.trim(),subtitle:'Perfil deportivo · visible solo dentro del club',body:detailBody(p),actions:actions.join(''),width:'780px',className:'sports-profile-modal'});
    modal.wrap.querySelector('#sports-detail-edit')?.addEventListener('click',()=>editSportsProfile(p.socio_id,{profile:p,onSaved:async()=>{await onChanged?.();await openSportsProfile(p.socio_id,{onChanged});}}));
    modal.wrap.querySelector('#sports-detail-moderate')?.addEventListener('click',()=>{
      const hide=!p.moderado;
      openForm({title:hide?'Ocultar perfil deportivo':'Volver a mostrar perfil',subtitle:hide?'El perfil quedará bloqueado para el resto del club sin modificar la preferencia de privacidad del alumno.':'Se retirará el bloqueo. Solo volverá a ser visible si el alumno/tutor mantiene activada su publicación.',fields:hide?[{name:'motivo',label:'Motivo de moderación',type:'textarea',full:true,rows:3,required:true}]:[],submitText:hide?'Ocultar':'Mostrar',onSubmit:async v=>{await repos.sportsProfiles.moderate(p.socio_id,!hide,v.motivo||'');toast(hide?'Perfil ocultado':'Perfil visible');await onChanged?.();}});
    });
    return p;
  }catch(error){setError(error);return null;}
}

export async function editSportsProfile(socioId,{profile=null,onSaved=null}={}){
  try{
    const p=profile||await loadSportsProfile(socioId);
    if(p&&!p.editable)throw new Error('No puedes editar este perfil deportivo.');
    const current=p||{socio_id:socioId,editable:true,visible:true};
    openForm({title:'Editar perfil deportivo',subtitle:'Solo se comparte información deportiva con miembros autenticados del mismo club.',width:'860px',initial:current,fields:[
      {name:'apodo',label:'Apodo',maxLength:60},{name:'experiencia_anos',label:'Años de experiencia',type:'number',min:0,max:80,step:'0.5'},
      {name:'presentacion',label:'Sobre mí',type:'textarea',rows:4,full:true,maxLength:600,help:'Máximo 600 caracteres. No incluyas teléfono, email, dirección ni otros datos privados.'},
      {name:'guardia',label:'Guardia',maxLength:40},{name:'tecnica_favorita',label:'Técnica favorita',maxLength:120},{name:'especialidad',label:'Especialidad',maxLength:120},{name:'categoria_competitiva',label:'Categoría competitiva',maxLength:100},
      {name:'competiciones_logros',label:'Competiciones y logros',type:'textarea',rows:4,full:true,maxLength:1200},{name:'objetivos',label:'Objetivos deportivos',type:'textarea',rows:4,full:true,maxLength:800},
      {name:'visible',label:'Mostrar mi perfil deportivo al resto de miembros de mi club',type:'checkbox',full:true,value:current.visible!==false}
    ],submitText:'Guardar perfil',onSubmit:async v=>{await repos.sportsProfiles.save({socio_id:socioId,...v});toast('Perfil deportivo actualizado');await onSaved?.();}});
  }catch(error){setError(error);}
}

export function openSportsPhotoEditor(socioId,{profile=null,onSaved=null}={}){
  openForm({title:'Foto del perfil deportivo',subtitle:'Esta foto pertenece al alumno seleccionado, no a la cuenta del tutor.',width:'560px',fields:[{name:'foto',label:'Imagen',type:'file',required:true,full:true,accept:'image/jpeg,image/png,image/webp',help:'JPG, PNG o WEBP · se optimiza antes de subir.'}],submitText:'Guardar foto',onSubmit:async v=>{await repos.sportsProfiles.uploadPhoto(socioId,v.foto);toast('Foto deportiva actualizada');await onSaved?.();}});
  if(profile?.foto_path){
    const actions=document.querySelector('#modal-form .modal-actions');
    if(actions){const remove=document.createElement('button');remove.type='button';remove.className='btn btn-ghost';remove.textContent='Quitar foto';remove.addEventListener('click',async()=>{try{await repos.sportsProfiles.removePhoto(socioId);toast('Foto eliminada');document.getElementById('modal-layer')?.remove();await onSaved?.();}catch(error){setError(error)}});actions.prepend(remove);}
  }
}

export async function openMembersDirectory(){
  try{
    const profiles=await loadSportsProfiles();
    const items=profiles.map(p=>`<button type="button" class="sports-member" data-sports-member="${esc(p.socio_id)}"><div class="sports-profile-photo">${p.fotoUrl?`<img src="${esc(p.fotoUrl)}" alt="">`:`<span>${esc(initials(p))}</span>`}</div><div><strong>${esc(p.apodo||`${p.nombre||''} ${p.apellidos||''}`.trim())}</strong><small>${esc(officialLine(p))}</small>${p.moderado?'<em>Oculto por moderación</em>':p.visible===false?'<em>Privado por elección del alumno/tutor</em>':''}</div>${icon('chevronRight',{size:17})}</button>`).join('');
    const modal=openDetail({title:'Miembros',subtitle:'Perfiles deportivos compartidos dentro de tu club',body:`<div class="sports-directory">${items||'<div class="empty"><strong>Aún no hay perfiles deportivos publicados</strong><p>Los perfiles aparecerán cuando cada alumno o tutor decida compartirlos.</p></div>'}</div>`,width:'760px',className:'sports-directory-modal'});
    modal.wrap.querySelectorAll('[data-sports-member]').forEach(b=>b.addEventListener('click',()=>openSportsProfile(b.dataset.sportsMember,{onChanged:openMembersDirectory})));
  }catch(error){setError(error);}
}
