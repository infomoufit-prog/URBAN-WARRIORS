import { esc, humanError } from '../core/utils.js';
import { state } from '../core/state.js';
import { rolesLabel } from '../core/permissions.js';
import { icon } from './icons.js';

export function setAppHtml(html){document.getElementById('app').innerHTML=html;}
export function setMainHtml(html){const el=document.getElementById('main-view');if(el)el.innerHTML=html;}

export function alertHtml(){
  const bits=[];
  if(state.error)bits.push(`<div class="alert alert-error"><strong>Error</strong><span>${esc(state.error)}</span><button type="button" class="icon-btn alert-close" data-dismiss-alert aria-label="Cerrar">${icon('close',{size:16})}</button></div>`);
  if(state.warning)bits.push(`<div class="alert alert-warning"><strong>Atención</strong><span>${esc(state.warning)}</span><button type="button" class="icon-btn alert-close" data-dismiss-alert aria-label="Cerrar">${icon('close',{size:16})}</button></div>`);
  return bits.join('');
}
export function bindDismissAlerts(){document.querySelectorAll('[data-dismiss-alert]').forEach(b=>b.addEventListener('click',()=>{state.clearError();b.closest('.alert')?.remove();}));}

const initials=(name='')=>String(name).split(/\s+/).filter(Boolean).slice(0,2).map(x=>x[0]?.toUpperCase()).join('')||'UW';
const safeColor=(value,fallback)=>/^#[0-9a-f]{6}$/i.test(String(value||''))?String(value):fallback;
const safeLogo=(value)=>{const v=String(value||'').trim();return /^(https?:\/\/|\.\/|\/)/i.test(v)?v:'./assets/urban-warriors-logo.png'};
const safeOptionalImage=(value)=>{const v=String(value||'').trim();return /^(https?:\/\/|\.\/|\/)/i.test(v)?v:''};

export function shell(navItems,active,mobileItems=[]){
  const s=state.session;
  const sections={dashboard:'Principal',members:'Gestión',enrollments:'Gestión',catalog:'Club',groups:'Club',sessions:'Clases',attendance:'Clases',progress:'Seguimiento',tracking:'Seguimiento',finance:'Economía',reminders:'Economía',communications:'Contenido',community:'Contenido',events:'Club',material:'Contenido',documents:'Administración',notifications:'Cuenta',users:'Administración',settings:'Administración',diagnostics:'Sistema',certification:'Sistema',requests:'Mi cuenta',install:'Mi cuenta',help:'Ayuda',profile:'Cuenta'};
  let last='';const navHtml=navItems.map(n=>{const sec=sections[n.id]||'Más';const head=sec!==last?`<div class="nav-section">${esc(sec)}</div>`:'';last=sec;return `${head}<button type="button" class="nav-item ${active===n.id?'active':''}" data-nav="${esc(n.id)}"><span>${n.icon}</span><b>${esc(n.label)}</b></button>`}).join('');
  const mobile=mobileItems.map(n=>`<button type="button" class="${active===n.id?'active':''}" ${n.id==='more'?'id="mobile-more"':`data-nav="${esc(n.id)}"`}><span>${n.icon}</span>${esc(n.label)}</button>`).join('');
  const logo=safeLogo(s?.club?.logo_url);const cover=safeOptionalImage(s?.club?.portada_url);const primary=safeColor(s?.club?.color_primario,'#ffffff');const secondary=safeColor(s?.club?.color_secundario,'#050608');
  return `<div class="app-shell" style="--club-primary:${esc(primary)};--club-secondary:${esc(secondary)};--uw-logo-image:url('${esc(logo)}');--uw-cover-image:${cover?`url('${esc(cover)}')`:'none'}">
    <button type="button" class="icon-btn mobile-only menu-toggle" id="menu-btn" aria-label="Abrir menú" aria-controls="sidebar" aria-expanded="false"><span class="menu-icon-open">${icon('menu')}</span><span class="menu-icon-close">${icon('close')}</span></button>
    <aside class="sidebar" id="sidebar">
      <div class="brand-block"><img src="${esc(logo)}" alt="${esc(s?.club?.nombre||'Urban Warriors')}"><div><strong>${esc(String(s?.club?.nombre||'URBAN WARRIORS').toUpperCase())}</strong><small>${esc(s?.club?.lema||'Bring the Pain')}</small></div></div>
      <nav class="nav-list">${navHtml}</nav>
      <div class="sidebar-foot"><div class="user-avatar session-avatar" data-session-avatar><span>${esc(initials(`${s?.nombre||''} ${s?.apellidos||''}`))}</span><img alt="Foto de perfil" hidden></div><span>${esc(`${s?.nombre||''} ${s?.apellidos||''}`.trim())}</span><small>${esc(rolesLabel(s?.roles||[s?.rol]))}</small><button type="button" class="btn btn-ghost btn-sm" id="logout-btn">${icon('logOut',{size:15})} Cerrar sesión</button></div>
    </aside>
    <button type="button" class="sidebar-scrim" id="sidebar-scrim" aria-label="Cerrar menú" tabindex="-1"></button>
    <section class="content-shell">
      <header class="topbar"><div class="topbar-identity"><strong>${esc(s?.club?.nombre||'Urban Warriors')}</strong><small>${esc(rolesLabel(s?.roles||[s?.rol]))}</small></div><div class="topbar-actions"><button class="icon-btn notification-button" id="notification-button" type="button" data-nav="notifications" aria-label="Notificaciones">${icon('bell')}<span class="notification-count" id="notification-count" hidden>0</span></button><button class="topbar-avatar session-avatar" type="button" data-nav="profile" aria-label="Mi perfil" data-session-avatar><span>${esc(initials(`${s?.nombre||''} ${s?.apellidos||''}`))}</span><img alt="Foto de perfil" hidden></button></div></header>
      <div id="global-alerts">${alertHtml()}</div>
      <main id="main-view" class="main-view"><div class="loading-card">Cargando…</div></main>
    </section>
    <nav class="bottom-nav" aria-label="Navegación móvil">${mobile}</nav>
  </div>`;
}

export function setNotificationBadge(count=0){const el=document.getElementById('notification-count');if(!el)return;const n=Math.max(0,Number(count||0));el.textContent=n>99?'99+':String(n);el.hidden=n===0;document.getElementById('notification-button')?.classList.toggle('has-unread',n>0);}

export function pageHeader(title,subtitle='',actions='',kicker=''){
  return `<div class="page-head"><div>${kicker?`<div class="page-kicker">${esc(kicker)}</div>`:''}<h1>${esc(title)}</h1>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div><div class="page-actions">${actions}</div></div>`;
}
export function hero({kicker='Urban Warriors',title,body='',actions='',sideValue='',sideLabel='',dark=false}={}){
  return `<section class="hero ${dark?'dark':''}"><div class="hero-grid"><div><div class="hero-kicker">${esc(kicker)}</div><h1>${esc(title||'')}</h1>${body?`<p>${esc(body)}</p>`:''}${actions?`<div class="hero-actions">${actions}</div>`:''}</div>${sideValue?`<div class="hero-side"><strong>${esc(sideValue)}</strong><span>${esc(sideLabel)}</span></div>`:''}</div></section>`;
}
export function metric(label,value,sub='',light=false){return `<div class="metric ${light?'metric-light':''}"><span>${esc(label)}</span><strong>${esc(value)}</strong>${sub?`<small>${esc(sub)}</small>`:''}</div>`}
export function progress(value){const v=Math.max(0,Math.min(100,Number(value||0)));return `<div class="progress"><span style="width:${v}%"></span></div>`}
export function empty(title='Sin datos',text='No hay registros para mostrar.'){return `<div class="empty"><strong>${esc(title)}</strong><p>${esc(text)}</p></div>`}
export function badge(text,kind='neutral'){return `<span class="badge badge-${esc(kind)}">${esc(text)}</span>`}
function labelRow(row,headers){let i=0;return row.replace(/<td(\s[^>]*)?>/g,(m,attrs='')=>`<td${attrs||''} data-label="${esc(headers[i++]||'')}">`)}
export function table(headers,rows){const labelled=rows.map(r=>labelRow(r,headers));return `<div class="table-wrap"><table><thead><tr>${headers.map(h=>`<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${labelled.join('')}</tbody></table></div>`}
export function card(title,body,actions=''){return `<section class="card"><div class="card-head"><h2>${esc(title)}</h2>${actions?`<div>${actions}</div>`:''}</div>${body}</section>`}
export function quickRow(iconHtml,title,subtitle='',actions=''){const visual=String(iconHtml||'').trim().startsWith('<svg')?iconHtml:esc(iconHtml);return `<div class="quick-row"><div class="quick-icon">${visual}</div><div><strong>${esc(title)}</strong>${subtitle?`<small>${esc(subtitle)}</small>`:''}</div>${actions?`<div class="quick-actions">${actions}</div>`:''}</div>`}
export function profileSwitcher(items,selected){return `<div class="profile-switcher">${items.map(x=>`<button type="button" class="profile-chip ${String(x.id)===String(selected)?'active':''}" data-profile-id="${esc(x.id)}"><span class="user-avatar">${esc(initials(`${x.nombre||''} ${x.apellidos||''}`))}</span><span><strong>${esc(x.nombre||'Alumno')}</strong><small>${esc(x.apellidos||'')}</small></span></button>`).join('')}</div>`}

function fieldHtml(f,val){
  const value=val??f.value??''; const req=f.required?'required':''; const disabled=f.disabled?'disabled':''; const name=esc(f.name);
  const label=`<label for="f-${name}">${esc(f.label)}${f.required?' *':''}</label>`;
  if(f.type==='textarea')return `<div class="field ${f.full?'full':''}">${label}<textarea id="f-${name}" name="${name}" ${req} ${disabled} rows="${f.rows||4}" ${f.maxLength!=null?`maxlength="${esc(f.maxLength)}"`:''} placeholder="${esc(f.placeholder||'')}">${esc(value)}</textarea>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  if(f.type==='select')return `<div class="field ${f.full?'full':''}">${label}<select id="f-${name}" name="${name}" ${req} ${disabled}><option value="">${esc(f.placeholder||'Selecciona')}</option>${(f.options||[]).map(o=>`<option value="${esc(o.value)}" ${String(o.value)===String(value)?'selected':''}>${esc(o.label)}</option>`).join('')}</select>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  if(f.type==='checkbox')return `<div class="field checkbox-field ${f.full?'full':''}"><label><input id="f-${name}" name="${name}" type="checkbox" ${value!==false?'checked':''} ${disabled}><span>${esc(f.label)}</span></label>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  if(f.type==='file')return `<div class="field ${f.full?'full':''}">${label}<div class="file-input-wrap">${icon('upload',{size:18})}<input id="f-${name}" name="${name}" type="file" ${f.accept?`accept="${esc(f.accept)}"`:''} ${req}></div>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  return `<div class="field ${f.full?'full':''}">${label}<input id="f-${name}" name="${name}" type="${esc(f.type||'text')}" value="${esc(value)}" ${req} ${disabled} ${f.min!=null?`min="${esc(f.min)}"`:''} ${f.max!=null?`max="${esc(f.max)}"`:''} ${f.step!=null?`step="${esc(f.step)}"`:''} ${f.maxLength!=null?`maxlength="${esc(f.maxLength)}"`:''} placeholder="${esc(f.placeholder||'')}">${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
}

export function openForm({title,subtitle='',fields=[],initial={},submitText='Guardar',onSubmit,width='720px'}){
  closeModal();
  const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';
  wrap.innerHTML=`<div class="modal" style="--modal-width:${esc(width)}"><div class="modal-head"><div><h2>${esc(title)}</h2>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div><button type="button" class="icon-btn" id="modal-close" aria-label="Cerrar">${icon('close')}</button></div><form id="modal-form" novalidate><div class="modal-error" id="modal-error" hidden></div><div class="form-grid">${fields.map(f=>fieldHtml(f,initial[f.name])).join('')}</div><div class="modal-actions"><button type="button" class="btn btn-ghost" id="modal-cancel">Cancelar</button><button type="submit" class="btn btn-primary" id="modal-submit">${esc(submitText)}</button></div></form></div>`;
  document.body.appendChild(wrap);
  const form=wrap.querySelector('#modal-form'),button=wrap.querySelector('#modal-submit'),errorBox=wrap.querySelector('#modal-error');
  const close=()=>closeModal(); wrap.querySelector('#modal-close').addEventListener('click',close);wrap.querySelector('#modal-cancel').addEventListener('click',close);
  // Los formularios solo se cierran con X o Cancelar. En Android, al volver del
  // selector nativo de archivos puede llegar un toque tardío sobre el fondo del
  // modal; tratarlo como cierre hacía perder el formulario y el borrador.
  form.addEventListener('submit',async e=>{
    e.preventDefault(); e.stopPropagation(); errorBox.hidden=true;
    if(!form.reportValidity())return;
    const fd=new FormData(form),values={};
    for(const f of fields){if(f.type==='checkbox')values[f.name]=form.elements[f.name].checked;else if(f.type==='file')values[f.name]=form.elements[f.name].files?.[0]||null;else values[f.name]=fd.get(f.name);}
    button.disabled=true; const original=button.textContent; button.textContent='Guardando…';
    try{await onSubmit(values,{form,button});button.textContent='Guardado';await new Promise(r=>setTimeout(r,260));close();}
    catch(error){button.disabled=false;button.textContent=original;errorBox.hidden=false;errorBox.textContent=humanError(error);console.error(error);}
  });
  setTimeout(()=>form.querySelector('input:not([type=hidden]),select,textarea')?.focus(),0);
  return {wrap,form};
}
export function openDetail({title='',subtitle='',body='',actions='',width='860px',className=''}){
  closeModal();
  const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';
  wrap.innerHTML=`<div class="modal detail-modal ${esc(className)}" style="--modal-width:${esc(width)}"><div class="modal-head"><div><h2>${esc(title)}</h2>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div><button type="button" class="icon-btn" id="modal-close" aria-label="Cerrar">${icon('close')}</button></div><div class="detail-modal-body">${body}</div>${actions?`<div class="modal-actions detail-actions">${actions}</div>`:''}</div>`;
  document.body.appendChild(wrap);
  const close=()=>closeModal();wrap.querySelector('#modal-close')?.addEventListener('click',close);wrap.addEventListener('click',e=>{if(e.target===wrap)close()});
  return {wrap,close};
}
export function closeModal(){document.getElementById('modal-layer')?.remove();}
export function confirmDialog(title,text,onConfirm,{confirmText='Confirmar',danger=false}={}){openForm({title,subtitle:text,fields:[],submitText:confirmText,onSubmit:async()=>onConfirm(),width:'480px'});if(danger)document.getElementById('modal-submit')?.classList.add('btn-danger');}
export function setError(error){state.error=humanError(error);const box=document.getElementById('global-alerts');if(box){box.innerHTML=alertHtml();bindDismissAlerts();}else{toast(state.error,'error');}console.error(error)}
export function setWarning(text){state.warning=text;const box=document.getElementById('global-alerts');if(box){box.innerHTML=alertHtml();bindDismissAlerts();}}
export function toast(text,kind='ok'){const t=document.createElement('div');t.className=`toast toast-${kind}`;t.textContent=text;document.body.appendChild(t);setTimeout(()=>t.classList.add('show'),10);setTimeout(()=>{t.classList.remove('show');setTimeout(()=>t.remove(),250)},3000);}
