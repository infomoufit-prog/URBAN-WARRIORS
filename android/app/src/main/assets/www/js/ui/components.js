import { esc, humanError } from '../core/utils.js';
import { state } from '../core/state.js';
import { rolesLabel } from '../core/permissions.js';

export function setAppHtml(html){document.getElementById('app').innerHTML=html;}
export function setMainHtml(html){const el=document.getElementById('main-view');if(el)el.innerHTML=html;}

export function alertHtml(){
  const bits=[];
  if(state.error)bits.push(`<div class="alert alert-error"><strong>Error</strong><span>${esc(state.error)}</span><button type="button" data-dismiss-alert aria-label="Cerrar">×</button></div>`);
  if(state.warning)bits.push(`<div class="alert alert-warning"><strong>Atención</strong><span>${esc(state.warning)}</span><button type="button" data-dismiss-alert aria-label="Cerrar">×</button></div>`);
  return bits.join('');
}
export function bindDismissAlerts(){document.querySelectorAll('[data-dismiss-alert]').forEach(b=>b.addEventListener('click',()=>{state.clearError();b.closest('.alert')?.remove();}));}

export function shell(navItems,active){
  const s=state.session;
  return `<div class="app-shell">
    <aside class="sidebar" id="sidebar">
      <div class="brand-block"><img src="./assets/urban-warriors-logo.png" alt="Urban Warriors"><div><strong>URBAN WARRIORS</strong><small>2.0 RC</small></div></div>
      <nav class="nav-list">${navItems.map(n=>`<button type="button" class="nav-item ${active===n.id?'active':''}" data-nav="${esc(n.id)}"><span>${n.icon}</span><b>${esc(n.label)}</b></button>`).join('')}</nav>
      <div class="sidebar-foot"><span>${esc(s?.nombre||'')}</span><small>${esc(rolesLabel(s?.roles||[s?.rol]))}</small><button type="button" class="btn btn-ghost btn-sm" id="logout-btn">Cerrar sesión</button></div>
    </aside>
    <section class="content-shell">
      <header class="topbar"><button type="button" class="icon-btn mobile-only" id="menu-btn">☰</button><div><strong>${esc(s?.club?.nombre||'Urban Warriors')}</strong><small>${esc(window.UW_CONFIG.release.version)}</small></div><div class="connection-pill"><span class="dot"></span> Supabase</div></header>
      <div id="global-alerts">${alertHtml()}</div>
      <main id="main-view" class="main-view"><div class="loading-card">Cargando…</div></main>
    </section>
  </div>`;
}

export function pageHeader(title,subtitle='',actions=''){
  return `<div class="page-head"><div><h1>${esc(title)}</h1>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div><div class="page-actions">${actions}</div></div>`;
}
export function metric(label,value,sub=''){return `<div class="metric"><span>${esc(label)}</span><strong>${esc(value)}</strong>${sub?`<small>${esc(sub)}</small>`:''}</div>`}
export function empty(title='Sin datos',text='No hay registros para mostrar.'){return `<div class="empty"><strong>${esc(title)}</strong><p>${esc(text)}</p></div>`}
export function badge(text,kind='neutral'){return `<span class="badge badge-${esc(kind)}">${esc(text)}</span>`}
export function table(headers,rows){return `<div class="table-wrap"><table><thead><tr>${headers.map(h=>`<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>`}
export function card(title,body,actions=''){return `<section class="card"><div class="card-head"><h2>${esc(title)}</h2>${actions?`<div>${actions}</div>`:''}</div>${body}</section>`}

function fieldHtml(f,val){
  const value=val??f.value??''; const req=f.required?'required':''; const disabled=f.disabled?'disabled':''; const name=esc(f.name);
  const label=`<label for="f-${name}">${esc(f.label)}${f.required?' *':''}</label>`;
  if(f.type==='textarea')return `<div class="field ${f.full?'full':''}">${label}<textarea id="f-${name}" name="${name}" ${req} ${disabled} rows="${f.rows||4}" placeholder="${esc(f.placeholder||'')}">${esc(value)}</textarea>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  if(f.type==='select')return `<div class="field ${f.full?'full':''}">${label}<select id="f-${name}" name="${name}" ${req} ${disabled}><option value="">${esc(f.placeholder||'Selecciona')}</option>${(f.options||[]).map(o=>`<option value="${esc(o.value)}" ${String(o.value)===String(value)?'selected':''}>${esc(o.label)}</option>`).join('')}</select></div>`;
  if(f.type==='checkbox')return `<div class="field checkbox-field ${f.full?'full':''}"><label><input id="f-${name}" name="${name}" type="checkbox" ${value!==false?'checked':''} ${disabled}><span>${esc(f.label)}</span></label>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  if(f.type==='file')return `<div class="field ${f.full?'full':''}">${label}<input id="f-${name}" name="${name}" type="file" ${f.accept?`accept="${esc(f.accept)}"`:''} ${req}></div>`;
  return `<div class="field ${f.full?'full':''}">${label}<input id="f-${name}" name="${name}" type="${esc(f.type||'text')}" value="${esc(value)}" ${req} ${disabled} ${f.min!=null?`min="${esc(f.min)}"`:''} ${f.max!=null?`max="${esc(f.max)}"`:''} ${f.step!=null?`step="${esc(f.step)}"`:''} placeholder="${esc(f.placeholder||'')}">${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
}

export function openForm({title,subtitle='',fields=[],initial={},submitText='Guardar',onSubmit,width='720px'}){
  closeModal();
  const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';
  wrap.innerHTML=`<div class="modal" style="--modal-width:${esc(width)}"><div class="modal-head"><div><h2>${esc(title)}</h2>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div><button type="button" class="icon-btn" id="modal-close">×</button></div><form id="modal-form" novalidate><div class="modal-error" id="modal-error" hidden></div><div class="form-grid">${fields.map(f=>fieldHtml(f,initial[f.name])).join('')}</div><div class="modal-actions"><button type="button" class="btn btn-ghost" id="modal-cancel">Cancelar</button><button type="submit" class="btn btn-primary" id="modal-submit">${esc(submitText)}</button></div></form></div>`;
  document.body.appendChild(wrap);
  const form=wrap.querySelector('#modal-form'),button=wrap.querySelector('#modal-submit'),errorBox=wrap.querySelector('#modal-error');
  const close=()=>closeModal(); wrap.querySelector('#modal-close').addEventListener('click',close);wrap.querySelector('#modal-cancel').addEventListener('click',close);
  wrap.addEventListener('click',e=>{if(e.target===wrap)close()});
  form.addEventListener('submit',async e=>{
    e.preventDefault(); e.stopPropagation(); errorBox.hidden=true;
    if(!form.reportValidity())return;
    const fd=new FormData(form),values={};
    for(const f of fields){ if(f.type==='checkbox')values[f.name]=form.elements[f.name].checked; else if(f.type==='file')values[f.name]=form.elements[f.name].files?.[0]||null; else values[f.name]=fd.get(f.name); }
    button.disabled=true; const original=button.textContent; button.textContent='Guardando…';
    try{await onSubmit(values,{form,button});button.textContent='Guardado ✓';await new Promise(r=>setTimeout(r,250));close();}
    catch(error){button.disabled=false;button.textContent=original;errorBox.hidden=false;errorBox.textContent=humanError(error);console.error(error);}
  });
  setTimeout(()=>form.querySelector('input:not([type=hidden]),select,textarea')?.focus(),0);
  return {wrap,form};
}
export function closeModal(){document.getElementById('modal-layer')?.remove();}

export function confirmDialog(title,text,onConfirm,{confirmText='Confirmar',danger=false}={}){
  openForm({title,subtitle:text,fields:[],submitText:confirmText,onSubmit:async()=>onConfirm(),width:'480px'});
  if(danger)document.getElementById('modal-submit')?.classList.add('btn-danger');
}

export function setError(error){state.error=humanError(error);const box=document.getElementById('global-alerts');if(box){box.innerHTML=alertHtml();bindDismissAlerts();}else{toast(state.error,'error');}console.error(error)}
export function setWarning(text){state.warning=text;const box=document.getElementById('global-alerts');if(box){box.innerHTML=alertHtml();bindDismissAlerts();}}
export function toast(text,kind='ok'){
  const t=document.createElement('div');t.className=`toast toast-${kind}`;t.textContent=text;document.body.appendChild(t);setTimeout(()=>t.classList.add('show'),10);setTimeout(()=>{t.classList.remove('show');setTimeout(()=>t.remove(),250)},3000);
}
