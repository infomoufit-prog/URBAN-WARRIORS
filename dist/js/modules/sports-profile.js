import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc } from '../core/utils.js';
import { openForm, openDetail, toast, setError } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { mediaFrameAttrs, openMediaFramingEditor } from '../ui/media-framing.js';
import { t } from '../i18n/index.js';

const canModerate=()=>['direccion','coordinacion','secretaria','comunicacion'].includes(state.session?.rol);
const initials=(p)=>`${p?.nombre?.[0]||''}${p?.apellidos?.[0]||''}`.toUpperCase()||'UW';
const disciplines=(p)=>Array.isArray(p?.disciplinas)?p.disciplinas:[];
const officialLine=(p)=>disciplines(p).map(d=>[d.disciplina,d.grado,d.grupo].filter(Boolean).join(' · ')).filter(Boolean).join(' / ')||t('profile.sports.noOfficialDiscipline');

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
  if(!profile)return `<div class="sports-profile-empty"><strong>${t('profile.sports.unpublished')}</strong><small>${t('profile.sports.unpublishedHint')}</small></div>`;
  return `<div class="sports-profile-card-compact">
    <div class="sports-profile-photo">${profile.fotoUrl?`<img ${mediaFrameAttrs(profile.foto_presentation,'avatar')} src="${esc(profile.fotoUrl)}" alt="">`:`<span>${esc(initials(profile))}</span>`}</div>
    <div class="sports-profile-compact-copy"><span class="page-kicker">${t('profile.sports.kicker')}</span><h3>${esc(profile.apodo||`${profile.nombre||''} ${profile.apellidos||''}`.trim())}</h3><p>${esc(officialLine(profile))}</p>${profile.presentacion?`<small>${esc(profile.presentacion)}</small>`:''}</div>
    ${showEdit&&profile.editable?`<button class="btn btn-primary btn-sm" type="button" data-edit-sports-profile="${esc(profile.socio_id)}">${icon('edit',{size:14})} ${t('profile.sports.edit')}</button>`:''}
  </div>`;
}

function detailBody(p){
  const rows=[
    [t('profile.sports.experience'),p.experiencia_anos!=null?t('profile.sports.years',{count:Number(p.experiencia_anos)}):''],
    [t('profile.sports.guard'),p.guardia],[t('profile.sports.favoriteTechnique'),p.tecnica_favorita],[t('profile.sports.specialty'),p.especialidad],[t('profile.sports.competitiveCategory'),p.categoria_competitiva]
  ].filter(([,v])=>String(v??'').trim());
  return `<div class="sports-profile-detail">
    <div class="sports-profile-identity"><div class="sports-profile-photo sports-profile-photo-xl">${p.fotoUrl?`<img ${mediaFrameAttrs(p.foto_presentation,'avatar')} src="${esc(p.fotoUrl)}" alt="">`:`<span>${esc(initials(p))}</span>`}</div><div><span class="page-kicker">${t('profile.sports.memberClub')}</span><h2>${esc(`${p.nombre||''} ${p.apellidos||''}`.trim())}</h2>${p.apodo?`<strong class="sports-nickname">“${esc(p.apodo)}”</strong>`:''}<p>${esc(officialLine(p))}</p></div></div>
    ${p.presentacion?`<div class="sports-profile-about"><h3>${t('profile.sports.about')}</h3><p>${esc(p.presentacion)}</p></div>`:''}
    ${rows.length?`<div class="sports-profile-facts">${rows.map(([k,v])=>`<div><span>${esc(k)}</span><strong>${esc(v)}</strong></div>`).join('')}</div>`:''}
    ${p.competiciones_logros?`<div class="sports-profile-section"><h3>${t('profile.sports.competitions')}</h3><p>${esc(p.competiciones_logros)}</p></div>`:''}
    ${p.objetivos?`<div class="sports-profile-section"><h3>${t('profile.sports.goals')}</h3><p>${esc(p.objetivos)}</p></div>`:''}
    ${p.moderado?`<div class="alert alert-warning"><strong>${t('profile.sports.hiddenModeration')}</strong><span>${t('profile.sports.moderationBody')}</span></div>`:p.visible===false?`<div class="alert alert-warning"><strong>${t('profile.sports.privateTitle')}</strong><span>${t('profile.sports.privateBody')}</span></div>`:''}
  </div>`;
}

export async function openSportsProfile(socioId,{onChanged=null}={}){
  try{
    const p=await loadSportsProfile(socioId);
    if(!p){toast(t('profile.sports.noVisible'),'error');return null;}
    const actions=[];
    if(p.editable)actions.push(`<button class="btn btn-primary" id="sports-detail-edit">${icon('edit',{size:15})} ${t('profile.sports.editProfile')}</button>${p.fotoUrl?`<button class="btn btn-ghost" id="sports-detail-frame">${t('profile.sports.adjustPhoto')}</button>`:''}`);
    if(canModerate())actions.push(`<button class="btn btn-ghost" id="sports-detail-moderate">${p.moderado?t('profile.sports.removeBlock'):t('profile.sports.hideModeration')}</button>`);
    const modal=openDetail({title:p.apodo||`${p.nombre||''} ${p.apellidos||''}`.trim(),subtitle:t('profile.sports.clubOnly'),body:detailBody(p),actions:actions.join(''),width:'780px',className:'sports-profile-modal'});
    modal.wrap.querySelector('#sports-detail-frame')?.addEventListener('click',()=>openMediaFramingEditor({title:t('profile.sports.adjustPhoto'),subtitle:t('profile.sports.adjustPhotoSubtitle'),src:p.fotoUrl,initial:p.foto_presentation,preset:'avatar',onSave:async presentation=>{await repos.mediaFraming.set('sports_profile',p.socio_id,presentation);p.foto_presentation=presentation;await onChanged?.();await openSportsProfile(p.socio_id,{onChanged});}}));
    modal.wrap.querySelector('#sports-detail-edit')?.addEventListener('click',()=>editSportsProfile(p.socio_id,{profile:p,onSaved:async()=>{await onChanged?.();await openSportsProfile(p.socio_id,{onChanged});}}));
    modal.wrap.querySelector('#sports-detail-moderate')?.addEventListener('click',()=>{
      const hide=!p.moderado;
      openForm({title:hide?t('profile.sports.hideModeration'):t('profile.sports.showAgain'),subtitle:hide?t('profile.sports.hideSubtitle'):t('profile.sports.showSubtitle'),fields:hide?[{name:'motivo',label:t('profile.sports.moderationReason'),type:'textarea',full:true,rows:3,required:true}]:[],submitText:hide?t('profile.sports.hide'):t('profile.sports.show'),onSubmit:async v=>{await repos.sportsProfiles.moderate(p.socio_id,!hide,v.motivo||'');toast(hide?t('profile.sports.hiddenToast'):t('profile.sports.visibleToast'));await onChanged?.();}});
    });
    return p;
  }catch(error){setError(error);return null;}
}

export async function editSportsProfile(socioId,{profile=null,onSaved=null}={}){
  try{
    const p=profile||await loadSportsProfile(socioId);
    if(p&&!p.editable)throw new Error(t('profile.sports.cannotEdit'));
    const current=p||{socio_id:socioId,editable:true,visible:true};
    openForm({title:t('profile.sports.editProfile'),subtitle:t('profile.sports.editSubtitle'),width:'860px',initial:current,fields:[
      {name:'apodo',label:t('profile.sports.nickname'),maxLength:60},{name:'experiencia_anos',label:t('profile.sports.experienceYears'),type:'number',min:0,max:80,step:'0.5'},
      {name:'presentacion',label:t('profile.sports.about'),type:'textarea',rows:4,full:true,maxLength:600,help:t('profile.sports.aboutHelp')},
      {name:'guardia',label:t('profile.sports.guard'),maxLength:40},{name:'tecnica_favorita',label:t('profile.sports.favoriteTechnique'),maxLength:120},{name:'especialidad',label:t('profile.sports.specialty'),maxLength:120},{name:'categoria_competitiva',label:t('profile.sports.competitiveCategory'),maxLength:100},
      {name:'competiciones_logros',label:t('profile.sports.competitions'),type:'textarea',rows:4,full:true,maxLength:1200},{name:'objetivos',label:t('profile.sports.goals'),type:'textarea',rows:4,full:true,maxLength:800},
      {name:'visible',label:t('profile.sports.showToClub'),type:'checkbox',full:true,value:current.visible!==false}
    ],submitText:t('profile.sports.saveProfile'),onSubmit:async v=>{await repos.sportsProfiles.save({socio_id:socioId,...v});toast(t('profile.sports.updated'));await onSaved?.();}});
  }catch(error){setError(error);}
}

export function openSportsPhotoEditor(socioId,{profile=null,onSaved=null}={}){
  openForm({title:t('profile.sports.photoTitle'),subtitle:t('profile.sports.photoSubtitle'),width:'560px',fields:[{name:'foto',label:t('profile.sports.image'),type:'file',required:true,full:true,accept:'image/jpeg,image/png,image/webp',help:t('profile.sports.imageHelp')}],submitText:t('profile.sports.savePhoto'),onSubmit:async v=>{await repos.sportsProfiles.uploadPhoto(socioId,v.foto);toast(t('profile.sports.photoUpdated'));await onSaved?.();}});
  if(profile?.foto_path){
    const actions=document.querySelector('#modal-form .modal-actions');
    if(actions){const remove=document.createElement('button');remove.type='button';remove.className='btn btn-ghost';remove.textContent=t('profile.sports.removePhoto');remove.addEventListener('click',async()=>{try{await repos.sportsProfiles.removePhoto(socioId);toast(t('profile.sports.photoRemoved'));document.getElementById('modal-layer')?.remove();await onSaved?.();}catch(error){setError(error)}});actions.prepend(remove);}
  }
}

export async function openMembersDirectory(){
  try{
    const profiles=await loadSportsProfiles();
    const items=profiles.map(p=>`<button type="button" class="sports-member" data-sports-member="${esc(p.socio_id)}"><div class="sports-profile-photo">${p.fotoUrl?`<img ${mediaFrameAttrs(p.foto_presentation,'avatar')} src="${esc(p.fotoUrl)}" alt="">`:`<span>${esc(initials(p))}</span>`}</div><div><strong>${esc(p.apodo||`${p.nombre||''} ${p.apellidos||''}`.trim())}</strong><small>${esc(officialLine(p))}</small>${p.moderado?`<em>${t('profile.sports.hiddenByModeration')}</em>`:p.visible===false?`<em>${t('profile.sports.privateByChoice')}</em>`:''}</div>${icon('chevronRight',{size:17})}</button>`).join('');
    const modal=openDetail({title:t('profile.sports.members'),subtitle:t('profile.sports.membersSubtitle'),body:`<div class="sports-directory">${items||`<div class="empty"><strong>${t('profile.sports.noProfiles')}</strong><p>${t('profile.sports.noProfilesBody')}</p></div>`}</div>`,width:'760px',className:'sports-directory-modal'});
    modal.wrap.querySelectorAll('[data-sports-member]').forEach(b=>b.addEventListener('click',()=>openSportsProfile(b.dataset.sportsMember,{onChanged:openMembersDirectory})));
  }catch(error){setError(error);}
}
