import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, dateFmt, dtFmt, money } from '../core/utils.js';
import { pageHeader, quickRow, card, table, empty, badge, openForm, openDetail, closeModal, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));
const options=(rows,label=(r)=>r.nombre)=>rows.map(r=>({value:r.id,label:label(r)}));
const kindLabel=(x)=>({noticia:'Noticia',evento:'Evento',clase:'Clase',cartel:'Cartel'}[x]||x||'Noticia');
const audienceLabel=(x)=>({todos:'Todo el club',familias:'Familias y alumnado',monitores:'Monitores'}[x]||x||'Todo el club');
const orderLabel=(x)=>({reservado:'Solicitado',pendiente_validacion:'Pendiente de validación',preparado:'Preparado',validado:'Validado y cargado',entregado:'Entregado',cancelado:'Cancelado'}[x]||x||'Solicitado');
const isDirection=()=>((state.session?.roles?.length?state.session.roles:[state.session?.rol]).filter(Boolean)).includes('direccion');
const forceConfirm=(title,subtitle,onConfirm)=>openForm({title,subtitle:`${subtitle} Escribe ELIMINAR para confirmar.`,fields:[{name:'confirmacion',label:'Confirmación',required:true,placeholder:'ELIMINAR',help:'Esta acción elimina también el histórico relacionado y no se puede deshacer.'}],submitText:'Eliminar todo definitivamente',onSubmit:async v=>{if(String(v.confirmacion||'').trim().toUpperCase()!=='ELIMINAR')throw new Error('Escribe ELIMINAR exactamente para confirmar.');return onConfirm();}});

function communicationDetail(x,{can=false,reload=()=>{}}={}){
  const when=x.evento_fecha||x.publicada_en||x.programada_para||x.creado_en;
  const body=`<article class="publication-detail">
    ${x.imagen_url?`<div class="publication-cover"><img src="${esc(x.imagen_url)}" alt="${esc(x.titulo||'Publicación')}"></div>`:`<div class="publication-cover publication-cover-placeholder"><span>${icon('shield',{size:64})}</span><strong>URBAN WARRIORS</strong></div>`}
    <div class="publication-detail-content">
      <div class="detail-badges">${badge(kindLabel(x.tipo),'neutral')} ${badge(audienceLabel(x.audiencia),'neutral')} ${badge(x.estado||'publicada',x.estado==='publicada'?'ok':x.estado==='programada'?'warn':x.estado==='archivada'?'neutral':'neutral')}</div>
      <div class="publication-meta-grid">
        <div><small>Fecha</small><strong>${esc(dtFmt(when))}</strong></div>
        ${x.ubicacion?`<div><small>Ubicación</small><strong>${icon('mapPin',{size:14})} ${esc(x.ubicacion)}</strong></div>`:''}
      </div>
      <div class="publication-copy">${String(x.cuerpo||'').split(/\n+/).filter(Boolean).map(p=>`<p>${esc(p)}</p>`).join('')||'<p class="muted">Sin contenido adicional.</p>'}</div>
    </div>
  </article>`;
  const actions=can?`<button class="btn btn-ghost detail-edit">${icon('edit',{size:16})} Editar</button>${x.estado!=='archivada'?`<button class="btn btn-ghost detail-archive">${icon('archive',{size:16})} Archivar</button>`:''}<button class="btn btn-danger detail-delete">${icon('trash',{size:16})} Eliminar</button>`:'';
  const modal=openDetail({title:x.titulo||'Publicación',subtitle:`${kindLabel(x.tipo)} · ${audienceLabel(x.audiencia)}`,body,actions,width:'920px',className:'publication-modal'});
  if(can){
    modal.wrap.querySelector('.detail-edit')?.addEventListener('click',()=>{closeModal();openCommunicationForm(x,reload)});
    modal.wrap.querySelector('.detail-archive')?.addEventListener('click',()=>confirmDialog('Archivar publicación','La publicación dejará de aparecer en el feed habitual, pero conservará su trazabilidad.',async()=>{await repos.communications.save({...x,estado:'archivada'});toast('Publicación archivada');closeModal();await reload();},{confirmText:'Archivar'}));
    modal.wrap.querySelector('.detail-delete')?.addEventListener('click',()=>confirmDialog('Eliminar publicación y contenido','Se eliminarán la publicación, sus avisos vinculados y la imagen almacenada en el espacio multimedia del club. Esta acción es definitiva.',async()=>{await repos.communications.delete(x.id);toast('Publicación e imagen eliminadas');closeModal();await reload();},{confirmText:'Eliminar definitivamente',danger:true}));
  }
}

const commFields=[
  {name:'tipo',label:'Tipo',type:'select',value:'noticia',options:['noticia','evento','clase','cartel'].map(x=>({value:x,label:kindLabel(x)}))},
  {name:'titulo',label:'Título',required:true},
  {name:'audiencia',label:'Audiencia',type:'select',value:'todos',options:[{value:'todos',label:'Todo el club'},{value:'familias',label:'Familias y alumnado'},{value:'monitores',label:'Monitores'}]},
  {name:'estado',label:'Estado',type:'select',value:'borrador',options:[{value:'borrador',label:'Borrador'},{value:'programada',label:'Programada'},{value:'publicada',label:'Publicar ahora'},{value:'archivada',label:'Archivada'}]},
  {name:'evento_fecha',label:'Fecha/hora del evento o publicación programada',type:'datetime-local'},
  {name:'ubicacion',label:'Ubicación'},
  {name:'imagen',label:'Imagen de portada',type:'file',accept:'image/jpeg,image/png,image/webp,image/gif',help:'JPG, PNG, WEBP o GIF · máximo 5 MB. Al reemplazarla se elimina el archivo anterior de Storage.'},
  {name:'quitar_imagen',label:'Quitar imagen actual',type:'checkbox',value:false},
  {name:'cuerpo',label:'Contenido',type:'textarea',full:true,required:true,rows:8}
];
function openCommunicationForm(x={estado:'borrador',tipo:'noticia',audiencia:'todos'},reload=()=>{}){
  openForm({title:x.id?'Editar publicación':'Nueva publicación',subtitle:x.imagen_url?'Puedes conservar, sustituir o eliminar la imagen actual.':'Publica una noticia, evento, clase o cartel con imagen.',fields:commFields,initial:{...x,quitar_imagen:false},onSubmit:async v=>{
    const oldImage=x.imagen_url||'';let imageUrl=v.quitar_imagen?'':oldImage;let uploaded='';
    try{if(v.imagen){uploaded=await repos.communications.uploadImage(v.imagen);imageUrl=uploaded;}const saved=await repos.communications.save({...x,...v,imagen_url:imageUrl,id:x.id||null});if(oldImage&&oldImage!==imageUrl)await repos.communications.removeImage(oldImage).catch(()=>{});window.dispatchEvent(new CustomEvent('uw-notifications-changed'));toast(v.estado==='publicada'?'Publicación guardada y notificada':v.estado==='programada'?'Publicación programada':'Publicación guardada');await reload();return saved;}catch(e){if(uploaded)await repos.communications.removeImage(uploaded).catch(()=>{});throw e;}
  },width:'840px'});
}

export async function renderCommunications(){
  setMainHtml('<div class="loading-card">Cargando comunicaciones…</div>');
  try{
    const items=await repos.communications.list();const can=has(state.session,'communication');
    const visible=can?items:items.filter(x=>x.estado==='publicada');
    const feed=visible.map(x=>`<article class="feed-card publication-card" data-id="${esc(x.id)}"><button class="feed-open" data-id="${esc(x.id)}" aria-label="Abrir ${esc(x.titulo||'publicación')}"><div class="feed-media">${x.imagen_url?`<img src="${esc(x.imagen_url)}" alt="">`:`<div class="feed-placeholder brand-feed-placeholder">${icon('shield',{size:42})}<span>UW</span></div>`}</div><div class="feed-body"><div>${badge(kindLabel(x.tipo),'neutral')} ${can?badge(x.estado,x.estado==='publicada'?'ok':x.estado==='programada'?'warn':'neutral'):''}</div><h3>${esc(x.titulo)}</h3><p>${esc(String(x.cuerpo||'').slice(0,210))}${String(x.cuerpo||'').length>210?'…':''}</p><div class="feed-meta"><span>${esc(audienceLabel(x.audiencia))} · ${dtFmt(x.evento_fecha||x.publicada_en||x.programada_para||x.creado_en)}</span><span class="feed-more">Leer más ${icon('chevronRight',{size:14})}</span></div></div></button>${can?`<div class="feed-admin-actions"><button class="btn btn-ghost btn-sm edit-comm" data-id="${esc(x.id)}">${icon('edit',{size:14})} Editar</button><button class="btn btn-ghost btn-sm archive-comm" data-id="${esc(x.id)}">${icon('archive',{size:14})} Archivar</button><button class="btn btn-danger btn-sm delete-comm" data-id="${esc(x.id)}">${icon('trash',{size:14})} Eliminar</button></div>`:''}</article>`).join('');
    setMainHtml(`${pageHeader('Comunicaciones',can?'Feed editorial, noticias, eventos y carteles · el borrado elimina también la imagen de Storage':'Noticias, eventos y avisos del club',can?'<button class="btn btn-ghost" id="cleanup-comms">'+icon('trash',{size:16})+' Limpiar antiguas</button><button class="btn btn-primary" id="new-comm">'+icon('plus',{size:16})+' Nueva publicación</button>':'','Contenido')}<div class="feed">${feed||empty('Sin comunicaciones')}</div>`);
    const reload=()=>renderCommunications();
    document.getElementById('new-comm')?.addEventListener('click',()=>openCommunicationForm(undefined,reload));
    document.getElementById('cleanup-comms')?.addEventListener('click',()=>openForm({title:'Limpiar publicaciones antiguas',subtitle:'Elimina contenido antiguo y sus imágenes físicas de Storage. Por seguridad, las publicaciones publicadas solo se incluyen si marcas expresamente la opción.',fields:[{name:'antes_de',label:'Eliminar anteriores a',type:'date',required:true},{name:'incluir_publicadas',label:'Incluir también publicaciones ya publicadas',type:'checkbox',value:false,help:'No afecta a publicaciones programadas. Esta acción es definitiva.'}],submitText:'Limpiar contenido antiguo',onSubmit:async v=>{const out=await repos.communications.cleanupOld(v.antes_de,v.incluir_publicadas===true);toast(`${Number(out?.deleted_count||0)} publicaciones antiguas eliminadas`);await reload();}}));
    bind('.feed-open',id=>communicationDetail(items.find(x=>x.id===id),{can,reload}));
    bind('.edit-comm',id=>openCommunicationForm(items.find(x=>x.id===id),reload));
    bind('.archive-comm',id=>{const x=items.find(i=>i.id===id);confirmDialog('Archivar publicación','La publicación se conserva, pero deja de mostrarse en el feed habitual.',async()=>{await repos.communications.save({...x,estado:'archivada'});toast('Publicación archivada');await reload();},{confirmText:'Archivar'})});
    bind('.delete-comm',id=>{const x=items.find(i=>i.id===id);confirmDialog('Eliminar publicación y contenido','Se borrarán esta publicación, sus avisos vinculados y su imagen física de Storage. Esta acción no se puede deshacer.',async()=>{await repos.communications.delete(id);toast('Publicación e imagen eliminadas');await reload();},{confirmText:'Eliminar definitivamente',danger:true})});
  }catch(e){setError(e);setMainHtml(`${pageHeader('Comunicaciones')} ${empty('No se pudieron cargar las comunicaciones',e.message)}`)}
}

function productDetail(product,{variants=[],members=[],can=false,canManage=false,reload=()=>{}}={}){
  const ownVariants=variants.filter(v=>v.material_id===product.id&&v.activa);
  const stock=ownVariants.length?ownVariants.reduce((s,v)=>s+Number(v.stock||0),0):Number(product.stock||0);
  const body=`<article class="product-detail">
    <div class="product-detail-media">${product.imagen_url?`<img src="${esc(product.imagen_url)}" alt="${esc(product.nombre)}">`:`<div class="product-detail-placeholder">${icon('shield',{size:70})}<strong>URBAN WARRIORS</strong></div>`}</div>
    <div class="product-detail-info"><div class="page-kicker">${esc(product.categoria||'Material del club')}</div><h2>${esc(product.nombre)}</h2><p>${esc(product.descripcion||'Material oficial Urban Warriors.')}</p><div class="product-detail-price">${money(product.precio)}</div><div class="product-stock ${stock>0?'in':'out'}">${stock>0?`${stock} unidades disponibles`:'Consulta disponibilidad'}</div>
      ${ownVariants.length?`<div class="variant-grid">${ownVariants.map(v=>`<div class="variant-chip"><strong>${esc([v.talla,v.color].filter(Boolean).join(' · ')||v.referencia||'Variante')}</strong><small>${Number(v.stock||0)} uds.${v.referencia?` · ${esc(v.referencia)}`:''}</small></div>`).join('')}</div>`:''}
    </div>
  </article>`;
  let actions='';
  if(can)actions=`<button class="btn btn-ghost detail-edit-material">${icon('edit',{size:16})} Editar</button><button class="btn btn-ghost detail-variant-material">${icon('plus',{size:16})} Añadir variante</button>${product.activo?`<button class="btn btn-ghost detail-archive-material">${icon('archive',{size:16})} Desactivar</button>`:''}<button class="btn btn-danger detail-delete-material">${icon('trash',{size:16})} Eliminar</button>${isDirection()?`<button class="btn btn-danger detail-force-delete-material">${icon('trash',{size:16})} Eliminar todo</button>`:''}`;
  else actions=`<button class="btn btn-primary detail-request-material">${icon('shoppingBag',{size:16})} Solicitar material</button>`;
  const modal=openDetail({title:product.nombre,subtitle:`${product.categoria||'Material'} · ${money(product.precio)}`,body,actions,width:'900px',className:'product-modal'});
  if(can){
    modal.wrap.querySelector('.detail-edit-material')?.addEventListener('click',()=>{closeModal();openMaterialForm(product,reload)});
    modal.wrap.querySelector('.detail-variant-material')?.addEventListener('click',()=>{closeModal();openVariantForm(product,reload)});
    modal.wrap.querySelector('.detail-archive-material')?.addEventListener('click',()=>confirmDialog('Desactivar material','El artículo dejará de mostrarse a familias y alumnado, pero conservará pedidos e histórico.',async()=>{await repos.material.save({...product,activo:false});toast('Material desactivado');closeModal();await reload();},{confirmText:'Desactivar'}));
    modal.wrap.querySelector('.detail-delete-material')?.addEventListener('click',()=>confirmDialog('Eliminar material','Se eliminará si no tiene pedidos o entregas. La imagen del producto también se borrará del almacenamiento.',async()=>{await repos.material.delete(product.id);toast('Material e imagen eliminados');closeModal();await reload();},{confirmText:'Eliminar definitivamente',danger:true}));
    modal.wrap.querySelector('.detail-force-delete-material')?.addEventListener('click',()=>forceConfirm('Eliminar material y todo su histórico','Se borrarán también pedidos, entregas, variantes y la imagen del producto.',async()=>{await repos.material.forceDelete(product.id);toast('Material, histórico e imagen eliminados');closeModal();await reload();}));
  }else modal.wrap.querySelector('.detail-request-material')?.addEventListener('click',()=>{closeModal();openMaterialRequest(product.id,{members,variants,items:[product],reload})});
}

const itemFields=(disciplines)=>[
  {name:'disciplina_id',label:'Disciplina',type:'select',options:options(disciplines.filter(d=>d.activa))},
  {name:'nombre',label:'Nombre',required:true},{name:'categoria',label:'Categoría'},
  {name:'precio',label:'Precio',type:'number',step:'0.01',min:0,value:0},{name:'stock',label:'Stock base',type:'number',min:0,value:0},{name:'referencia',label:'Referencia'},
  {name:'imagen',label:'Imagen del producto',type:'file',accept:'image/jpeg,image/png,image/webp,image/gif',help:'JPG, PNG, WEBP o GIF · máximo 5 MB. Si sustituyes la imagen, la anterior se elimina de Storage.'},
  {name:'quitar_imagen',label:'Quitar imagen actual',type:'checkbox',value:false},
  {name:'descripcion',label:'Descripción',type:'textarea',full:true,rows:5},{name:'obligatorio',label:'Obligatorio',type:'checkbox',value:false},{name:'activo',label:'Activo',type:'checkbox',value:true}
];
let _materialDisciplines=[];
function openMaterialForm(x={activo:true,obligatorio:false},reload=()=>{}){
  openForm({title:x.id?'Editar material':'Nuevo material',subtitle:x.imagen_url?'Puedes conservar, sustituir o eliminar la imagen actual.':'Añade una fotografía para una tienda más visual.',fields:itemFields(_materialDisciplines),initial:{...x,quitar_imagen:false},onSubmit:async v=>{const oldImage=x.imagen_url||'';let imageUrl=v.quitar_imagen?'':oldImage;let uploaded='';try{if(v.imagen){uploaded=await repos.material.uploadImage(v.imagen);imageUrl=uploaded;}await repos.material.save({...x,...v,imagen_url:imageUrl,id:x.id||null});if(oldImage&&oldImage!==imageUrl)await repos.material.removeImage(oldImage).catch(()=>{});toast('Material guardado');await reload();}catch(e){if(uploaded)await repos.material.removeImage(uploaded).catch(()=>{});throw e;}},width:'760px'});
}
function openVariantForm(product,reload=()=>{}){
  openForm({title:'Nueva variante',subtitle:product?.nombre||'',fields:[{name:'talla',label:'Talla'},{name:'color',label:'Color'},{name:'referencia',label:'Referencia'},{name:'stock',label:'Stock',type:'number',min:0,value:0},{name:'activa',label:'Activa',type:'checkbox',value:true}],onSubmit:async v=>{await repos.material.saveVariant({...v,material_id:product.id});toast('Variante guardada');await reload();}});
}
function openMaterialRequest(materialId='',ctx={}){
  const {members=[],variants=[],items=[],reload=()=>{},canManage=false}=ctx;
  if(!members.length){toast('No hay un alumno vinculado disponible para esta solicitud.','error');return;}
  const activeItems=items.filter(i=>i.activo!==false);
  const fields=[{name:'socio_id',label:'Alumno',type:'select',required:true,options:options(members,m=>`${m.apellidos||''}, ${m.nombre}`.replace(/^, /,''))},{name:'material_id',label:'Artículo',type:'select',required:true,value:materialId,options:options(activeItems)},{name:'variante_id',label:'Talla / color (opcional)',type:'select',options:[]},{name:'cantidad',label:'Cantidad',type:'number',min:1,value:1},{name:'observaciones',label:'Observaciones',type:'textarea',full:true,placeholder:'Talla aproximada, consulta o detalle para secretaría…'},...(canManage?[{name:'validar_ahora',label:'Validar ahora, descontar stock y generar cargo',type:'checkbox',value:false,full:true,help:'Si no lo marcas, quedará pendiente para que otra persona autorizada lo valide.'}]:[])];
  const modal=openForm({title:canManage?'Registrar retirada de material':'He cogido este material',subtitle:canManage?'Puedes dejarla pendiente o validarla de forma atómica.':'El club validará la retirada antes de descontar stock y generar el cargo.',fields,submitText:canManage?'Registrar retirada':'Enviar para validar',onSubmit:async v=>{const out=await repos.material.request(v);toast(out?.estado==='validado'?'Retirada validada y cargo generado':'Retirada pendiente de validación');await reload();}});
  const materialSelect=modal.form.elements.material_id,variantSelect=modal.form.elements.variante_id;
  const refreshVariants=()=>{const mid=materialSelect.value;const opts=variants.filter(v=>v.activa&&v.material_id===mid);variantSelect.innerHTML='<option value="">Sin variante</option>'+opts.map(v=>`<option value="${esc(v.id)}">${esc([v.talla,v.color].filter(Boolean).join(' · ')||v.referencia||'Variante')} · stock ${Number(v.stock||0)}</option>`).join('');};
  materialSelect.addEventListener('change',refreshVariants);refreshVariants();
}

export async function renderMaterial(){
  setMainHtml('<div class="loading-card">Cargando material…</div>');
  try{
    const [items,variants,orders,disciplines,members]=await Promise.all([repos.material.list(),repos.material.variants(),repos.material.orders(),repos.catalog.disciplines(),repos.members.list()]);const can=has(state.session,'material'),canManage=has(state.session,'materialManage');_materialDisciplines=disciplines;
    const visible=items.filter(x=>x.activo||can);
    const products=visible.map(x=>{const own=variants.filter(v=>v.material_id===x.id&&v.activa);const stock=own.length?own.reduce((sum,v)=>sum+Number(v.stock||0),0):Number(x.stock||0);return `<article class="product-card ${x.activo===false?'product-inactive':''}"><button class="product-open" data-id="${esc(x.id)}"><div class="product-media">${x.imagen_url?`<img src="${esc(x.imagen_url)}" alt="">`:`<div class="feed-placeholder product-brand-placeholder">${icon('shield',{size:42})}<span>UW</span></div>`}</div><div class="product-body"><div class="page-kicker">${esc(x.categoria||'Material')}</div><h3>${esc(x.nombre)}</h3><small class="muted">${esc(String(x.descripcion||'').slice(0,90))}</small><div class="product-price">${money(x.precio)}</div><div class="product-stock-line"><small>${stock>0?`${stock} disponibles`:'Consultar stock'}</small>${x.activo===false?badge('Desactivado','neutral'):''}</div><span class="product-more">Ver detalles ${icon('chevronRight',{size:14})}</span></div></button></article>`}).join('');
    const orderRows=orders.map(o=>{const v=variants.find(x=>x.id===o.variante_id);const pending=['reservado','pendiente_validacion','preparado'].includes(o.estado);return `<tr><td>${dateFmt(o.creado_en)}</td><td>${esc(members.find(m=>m.id===o.socio_id)?.nombre||'—')}</td><td><strong>${esc(items.find(i=>i.id===o.material_id)?.nombre||'—')}</strong>${v?`<small class="muted">${esc([v.talla,v.color].filter(Boolean).join(' · '))}</small>`:''}</td><td>${esc(o.cantidad)}</td><td>${money(o.importe_total)}</td><td>${badge(orderLabel(o.estado),o.estado==='validado'||o.estado==='entregado'?'ok':o.estado==='cancelado'?'danger':pending?'warn':'neutral')}</td><td>${canManage&&pending?`<div class="row-actions"><button class="btn btn-primary btn-sm validate-material-order" data-id="${esc(o.id)}">Validar y generar cargo</button><button class="btn btn-danger btn-sm cancel-material-order" data-id="${esc(o.id)}">Cancelar</button></div>`:o.cuota_id?`<a class="btn btn-ghost btn-sm" href="#fees">Ver cargo</a>`:''}</td></tr>`});
    setMainHtml(`${pageHeader(can?'Material':'Tienda del club',can?'Catálogo, variantes y pedidos':'Material oficial, equipación y solicitudes',`${can?'<button class="btn btn-primary" id="new-material">'+icon('plus',{size:16})+' Nuevo material</button>':''}<button class="btn btn-ghost" id="request-material">${icon('shoppingBag',{size:16})} Solicitar material</button>`,'Contenido')}<section class="store-hero"><div><span class="page-kicker">Urban Warriors Store</span><h2>Equípate para entrenar.</h2><p>Consulta material oficial, tallas y disponibilidad. Envía tu solicitud directamente al club.</p></div><div class="store-hero-mark">${icon('shield',{size:58})}<strong>UW</strong></div></section><div class="material-grid">${products||empty('Sin material')}</div><div style="height:18px"></div>${card(canManage?'Pedidos':'Mis pedidos',orderRows.length?table(['Fecha','Alumno','Artículo','Cant.','Importe','Estado','Acciones'],orderRows):empty('Sin pedidos','Las solicitudes que realices aparecerán aquí con su estado.'))}`);
    const reload=()=>renderMaterial();
    document.getElementById('new-material')?.addEventListener('click',()=>openMaterialForm(undefined,reload));
    document.getElementById('request-material')?.addEventListener('click',()=>openMaterialRequest('',{members,variants,items:visible,reload,canManage}));
    bind('.product-open',id=>productDetail(items.find(x=>x.id===id),{variants,members,can,canManage,reload}));
    bind('.validate-material-order',id=>confirmDialog('Validar retirada y generar cargo','La operación descontará stock, registrará la entrega y añadirá la deuda del material al estado de cuenta.',async()=>{await repos.material.orderStatus(id,'validado');toast('Retirada validada y cargo generado');window.dispatchEvent(new CustomEvent('uw-notifications-changed'));await reload();},{confirmText:'Validar y generar cargo'}));
    bind('.cancel-material-order',id=>confirmDialog('Cancelar retirada','No se descontará stock ni se generará ningún cargo.',async()=>{await repos.material.orderStatus(id,'cancelado');toast('Retirada cancelada');await reload();},{confirmText:'Cancelar retirada',danger:true}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Material')} ${empty('No se pudo cargar el material',e.message)}`)}
}

const notificationRoute=(route)=>({fees:'finance',materials:'material',home:'dashboard'}[String(route||'')]||String(route||'dashboard'));

export async function renderNotifications(){
  setMainHtml('<div class="loading-card">Cargando notificaciones…</div>');
  try{
    const items=await repos.notifications.list();
    const nativePush=Boolean(window.UrbanWarriorsNative?.getNotificationPermissionState);
    const permissionState=nativePush?String(window.UrbanWarriorsNative.getNotificationPermissionState()||'prompt'):'unavailable';
    const pushAction=nativePush?`<button class="btn btn-ghost" id="notification-permission">${permissionState==='granted'?'Notificaciones activadas':permissionState==='settings'||permissionState==='rationale'?'Abrir ajustes de notificaciones':'Activar notificaciones'}</button>`:'';
    const category=(n)=>n.requiere_accion===true?'accion':n.tipo==='reserva_sesion'||n.tipo==='sesion_cambio'||n.tipo==='clase'?'sesiones':n.tipo==='comunidad'?'comunidad':n.tipo==='comunicacion'||n.tipo==='evento'?'comunicaciones':'otros';
    const grouped=new Map();for(const n of items){const key=category(n);const g=grouped.get(key)||{key,items:[],unread:0};g.items.push(n);if(!n.leida)g.unread++;grouped.set(key,g);}
    const labels={accion:'Requiere acción',sesiones:'Sesiones y asistencia',comunidad:'Comunidad del Club',comunicaciones:'Comunicaciones',otros:'Otros avisos'};
    const ordered=[...grouped.values()].sort((a,b)=>(a.key==='accion'?-1:0)-(b.key==='accion'?-1:0));
    const groupCards=ordered.map(g=>{
      const canBulk=g.key!=='accion'&&g.unread>0;
      const initialLimit=g.key==='accion'?20:12;
      const renderRow=n=>{
        const route=notificationRoute(n.ruta);
        const action=n.requiere_accion
          ? `<button class="btn btn-primary btn-sm review-notification" data-id="${esc(n.id)}" data-route="${esc(route)}">${icon('chevronRight',{size:14})} Revisar</button>`
          : `${n.ruta?`<a class="btn btn-ghost btn-sm" href="#${esc(route)}">Ver</a>`:''}${!n.leida?`<button class="btn btn-primary btn-sm mark-read" data-id="${esc(n.id)}">Leída</button>`:badge('Leída','neutral')}`;
        return quickRow(icon(n.tipo==='evento'?'calendar':n.tipo==='comunicacion'?'megaphone':n.tipo==='comunidad'?'sparkles':'bell'),n.titulo,n.cuerpo||`${n.tipo} · ${dtFmt(n.creado_en)}`,action);
      };
      const visibleRows=g.items.slice(0,initialLimit).map(renderRow).join('');
      const extraRows=g.items.slice(initialLimit).map(renderRow).join('');
      const more=extraRows?`<details class="notification-more"><summary>Ver ${g.items.length-initialLimit} avisos más</summary><div class="quick-list">${extraRows}</div></details>`:'';
      return `<section class="notification-group ${g.key==='accion'?'notification-group-action':''}"><header><div><span class="page-kicker">${esc(labels[g.key]||g.key)}</span><h3>${g.items.length} avisos</h3><small>${g.unread} sin leer${g.key==='accion'?' · abre cada tarea para revisarla':''}</small></div><div class="row-actions">${canBulk?`<button class="btn btn-ghost btn-sm mark-group" data-category="${esc(g.key)}">Marcar informativas del grupo</button>`:''}</div></header><div class="quick-list">${visibleRows}</div>${more}</section>`;
    }).join('');
    const unread=items.filter(n=>!n.leida).length;const actionUnread=items.filter(n=>!n.leida&&n.requiere_accion===true).length;const informativeUnread=items.filter(n=>!n.leida&&n.requiere_accion!==true).length;
    setMainHtml(`${pageHeader('Notificaciones','Limpia avisos informativos sin perder tareas pendientes',`${pushAction}${informativeUnread?'<button class="btn btn-primary" id="mark-all-read">Marcar informativas como leídas</button>':''}`,'Cuenta')}<div class="metrics"><div class="metric"><span>Sin leer</span><strong>${unread}</strong><small>${informativeUnread} informativas</small></div><div class="metric"><span>Requieren acción</span><strong>${actionUnread}</strong><small>solo desaparecen al revisarlas</small></div><div class="metric"><span>Grupos</span><strong>${grouped.size}</strong><small>categorías activas</small></div></div>${actionUnread?'<div class="alert alert-warning notification-action-note"><strong>Hay tareas pendientes</strong><span>“Marcar informativas como leídas” nunca oculta estas tareas. Abre “Revisar” para atenderlas.</span></div>':''}<div class="notification-groups">${groupCards||empty('Sin notificaciones')}</div>`);
    bind('.mark-read',async(id,el)=>{el.disabled=true;try{await repos.notifications.markRead(id);window.dispatchEvent(new CustomEvent('uw-notifications-changed'));toast('Notificación leída');await renderNotifications();}catch(e){setError(e);el.disabled=false;}});
    document.getElementById('mark-all-read')?.addEventListener('click',async()=>{try{const out=await repos.notifications.markInformative();window.dispatchEvent(new CustomEvent('uw-notifications-changed'));toast(`${Number(out?.marcadas_informativas||0)} avisos informativos marcados como leídos`);await renderNotifications();}catch(e){setError(e)}});
    document.querySelectorAll('.mark-group').forEach(b=>b.addEventListener('click',async()=>{try{const cat=b.dataset.category;const group=[...grouped.values()].find(g=>g.key===cat);for(const t of [...new Set((group?.items||[]).filter(n=>!n.leida&&n.requiere_accion!==true).map(n=>n.tipo))])await repos.notifications.markGroup(t);window.dispatchEvent(new CustomEvent('uw-notifications-changed'));toast('Avisos informativos del grupo marcados como leídos');await renderNotifications();}catch(e){setError(e)}}));
    document.querySelectorAll('.review-notification').forEach(b=>b.addEventListener('click',async()=>{if(b.disabled)return;b.disabled=true;try{await repos.notifications.review(b.dataset.id);window.dispatchEvent(new CustomEvent('uw-notifications-changed'));const route=notificationRoute(b.dataset.route);if(location.hash!==`#${route}`)location.hash=`#${route}`;else window.dispatchEvent(new HashChangeEvent('hashchange'));}catch(e){setError(e);b.disabled=false;}}));
    document.getElementById('notification-permission')?.addEventListener('click',()=>{try{if(permissionState==='granted'||permissionState==='settings'||permissionState==='rationale'){window.UrbanWarriorsNative.openNotificationSettings();toast('Revisa el permiso global de Urban Warriors en Ajustes');}else{window.UrbanWarriorsNative.requestNotifications();toast('Android mostrará la solicitud oficial de notificaciones');}setTimeout(()=>renderNotifications(),900);}catch(e){setError(e)}});
  }catch(e){setError(e);setMainHtml(`${pageHeader('Notificaciones')} ${empty('No se pudieron cargar las notificaciones',e.message)}`)}
}
