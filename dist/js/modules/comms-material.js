import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, dateFmt, dtFmt, money } from '../core/utils.js';
import { pageHeader, card, table, empty, badge, openForm, toast, setError, setMainHtml } from '../ui/components.js';

const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));
const options=(rows,label=(r)=>r.nombre)=>rows.map(r=>({value:r.id,label:label(r)}));

export async function renderCommunications(){
  setMainHtml('<div class="loading-card">Cargando comunicaciones…</div>');
  try{
    const items=await repos.communications.list();const can=has(state.session,'communication');
    const rows=items.map(x=>`<tr><td><strong>${esc(x.titulo)}</strong><br><small>${esc(String(x.cuerpo||'').slice(0,100))}${String(x.cuerpo||'').length>100?'…':''}</small></td><td>${esc(x.audiencia||'todos')}</td><td>${badge(x.estado,x.estado==='publicada'?'ok':x.estado==='programada'?'warn':x.estado==='archivada'?'neutral':'neutral')}</td><td>${dtFmt(x.publicada_en||x.programada_para||x.creado_en)}</td><td>${can?`<button class="btn btn-ghost btn-sm edit-comm" data-id="${esc(x.id)}">Editar</button>`:''}</td></tr>`);
    setMainHtml(`${pageHeader('Comunicaciones','Noticias, avisos y eventos',can?'<button class="btn btn-primary" id="new-comm">Nueva publicación</button>':'')}${card('Publicaciones',rows.length?table(['Publicación','Audiencia','Estado','Fecha','Acciones'],rows):empty('Sin comunicaciones'))}`);
    const fields=[{name:'tipo',label:'Tipo',type:'select',value:'noticia',options:['noticia','evento','clase','cartel'].map(x=>({value:x,label:x}))},{name:'titulo',label:'Título',required:true},{name:'audiencia',label:'Audiencia',type:'select',value:'todos',options:['todos','familias','alumnos','monitores','personal'].map(x=>({value:x,label:x}))},{name:'estado',label:'Estado',type:'select',value:'borrador',options:['borrador','programada','publicada','archivada'].map(x=>({value:x,label:x}))},{name:'evento_fecha',label:'Fecha/hora del evento',type:'datetime-local'},{name:'ubicacion',label:'Ubicación'},{name:'imagen_url',label:'URL imagen'},{name:'cuerpo',label:'Contenido',type:'textarea',full:true,required:true,rows:7}];
    const reload=()=>renderCommunications();const open=(x={estado:'borrador',tipo:'noticia',audiencia:'todos'})=>openForm({title:x.id?'Editar publicación':'Nueva publicación',fields,initial:x,onSubmit:async v=>{await repos.communications.save({...x,...v,id:x.id||null});toast('Publicación guardada');await reload();},width:'840px'});
    document.getElementById('new-comm')?.addEventListener('click',()=>open());bind('.edit-comm',id=>open(items.find(x=>x.id===id)));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Comunicaciones')} ${empty('No se pudieron cargar las comunicaciones',e.message)}`)}
}

export async function renderMaterial(){
  setMainHtml('<div class="loading-card">Cargando material…</div>');
  try{
    const [items,variants,orders,disciplines,members]=await Promise.all([repos.material.list(),repos.material.variants(),repos.material.orders(),repos.catalog.disciplines(),repos.members.list()]);const can=has(state.session,'material'),canManage=has(state.session,'materialManage');
    const itemRows=items.map(x=>{const stock=variants.filter(v=>v.material_id===x.id&&v.activa).reduce((s,v)=>s+Number(v.stock||0),Number(x.stock||0));return `<tr><td><strong>${esc(x.nombre)}</strong><br><small>${esc(x.categoria||'')}</small></td><td>${money(x.precio)}</td><td>${stock}</td><td>${badge(x.activo?'Activo':'Inactivo',x.activo?'ok':'neutral')}</td><td><div class="row-actions">${can?`<button class="btn btn-ghost btn-sm edit-material" data-id="${esc(x.id)}">Editar</button><button class="btn btn-ghost btn-sm variant-material" data-id="${esc(x.id)}">Variante</button>`:''}</div></td></tr>`});
    const orderRows=orders.map(o=>`<tr><td>${dateFmt(o.creado_en)}</td><td>${esc(members.find(m=>m.id===o.socio_id)?.nombre||'—')}</td><td>${esc(items.find(i=>i.id===o.material_id)?.nombre||'—')}</td><td>${esc(o.cantidad)}</td><td>${money(o.importe_total)}</td><td>${badge(o.estado,o.estado==='entregado'?'ok':o.estado==='cancelado'?'danger':o.estado==='preparado'?'warn':'neutral')}</td><td>${canManage?`<button class="btn btn-ghost btn-sm status-order" data-id="${esc(o.id)}">Cambiar</button>`:''}</td></tr>`);
    setMainHtml(`${pageHeader('Material','Catálogo, variantes y pedidos',`${can?'<button class="btn btn-primary" id="new-material">Nuevo material</button>':''}<button class="btn btn-ghost" id="request-material">Solicitar material</button>`)}${card('Catálogo',itemRows.length?table(['Artículo','Precio','Stock','Estado','Acciones'],itemRows):empty('Sin material'))}${card('Pedidos',orderRows.length?table(['Fecha','Alumno','Artículo','Cant.','Importe','Estado','Acciones'],orderRows):empty('Sin pedidos'))}`);
    const reload=()=>renderMaterial();
    const itemFields=[{name:'disciplina_id',label:'Disciplina',type:'select',options:options(disciplines.filter(d=>d.activa))},{name:'nombre',label:'Nombre',required:true},{name:'categoria',label:'Categoría'},{name:'precio',label:'Precio',type:'number',step:'0.01',min:0,value:0},{name:'stock',label:'Stock base',type:'number',min:0,value:0},{name:'referencia',label:'Referencia'},{name:'imagen_url',label:'URL imagen'},{name:'descripcion',label:'Descripción',type:'textarea',full:true},{name:'obligatorio',label:'Obligatorio',type:'checkbox',value:false},{name:'activo',label:'Activo',type:'checkbox',value:true}];
    const openItem=(x={activo:true,obligatorio:false})=>openForm({title:x.id?'Editar material':'Nuevo material',fields:itemFields,initial:x,onSubmit:async v=>{await repos.material.save({...x,...v,id:x.id||null});toast('Material guardado');await reload();}});
    document.getElementById('new-material')?.addEventListener('click',()=>openItem());bind('.edit-material',id=>openItem(items.find(x=>x.id===id)));
    bind('.variant-material',id=>openForm({title:'Nueva variante',subtitle:items.find(x=>x.id===id)?.nombre||'',fields:[{name:'talla',label:'Talla'},{name:'color',label:'Color'},{name:'referencia',label:'Referencia'},{name:'stock',label:'Stock',type:'number',min:0,value:0},{name:'activa',label:'Activa',type:'checkbox',value:true}],onSubmit:async v=>{await repos.material.saveVariant({...v,material_id:id});toast('Variante guardada');await reload();}}));
    document.getElementById('request-material')?.addEventListener('click',()=>openForm({title:'Solicitar material',fields:[{name:'socio_id',label:'Alumno',type:'select',required:true,options:options(members,m=>`${m.apellidos}, ${m.nombre}`)},{name:'material_id',label:'Artículo',type:'select',required:true,options:options(items.filter(i=>i.activo))},{name:'variante_id',label:'Variante (opcional)',type:'select',options:options(variants.filter(v=>v.activa),v=>`${items.find(i=>i.id===v.material_id)?.nombre||''} · ${v.talla||''} ${v.color||''}`.trim())},{name:'cantidad',label:'Cantidad',type:'number',min:1,value:1},{name:'observaciones',label:'Observaciones',type:'textarea',full:true}],onSubmit:async v=>{await repos.material.request(v);toast('Solicitud registrada');await reload();}}));
    bind('.status-order',id=>openForm({title:'Actualizar pedido',fields:[{name:'estado',label:'Estado',type:'select',required:true,options:['reservado','preparado','entregado','cancelado'].map(x=>({value:x,label:x}))}],onSubmit:async v=>{await repos.material.orderStatus(id,v.estado);toast('Pedido actualizado');await reload();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Material')} ${empty('No se pudo cargar el material',e.message)}`)}
}

export async function renderNotifications(){
  setMainHtml('<div class="loading-card">Cargando notificaciones…</div>');
  try{
    const items=await repos.notifications.list();
    const rows=items.map(n=>`<tr><td>${n.leida?'':'<span class="dot"></span>'}</td><td><strong>${esc(n.titulo)}</strong><br><small>${esc(n.cuerpo)}</small></td><td>${esc(n.tipo)}</td><td>${dtFmt(n.creado_en)}</td><td>${!n.leida?`<button class="btn btn-ghost btn-sm mark-read" data-id="${esc(n.id)}">Marcar leída</button>`:''}</td></tr>`);
    setMainHtml(`${pageHeader('Notificaciones','Bandeja de avisos')}${card('Notificaciones',rows.length?table(['','Aviso','Tipo','Fecha','Acciones'],rows):empty('Sin notificaciones'))}`);
    bind('.mark-read',async(id,el)=>{el.disabled=true;try{await repos.notifications.markRead(id);toast('Notificación leída');await renderNotifications();}catch(e){setError(e);el.disabled=false;}});
  }catch(e){setError(e);setMainHtml(`${pageHeader('Notificaciones')} ${empty('No se pudieron cargar las notificaciones',e.message)}`)}
}
