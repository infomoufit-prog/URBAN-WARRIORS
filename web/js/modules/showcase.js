import { repos } from '../core/repositories.js';
import { esc, money, dtFmt } from '../core/utils.js';
import { KOMBAX_BRAND } from '../core/platform.js';
import { pageHeader, empty, openForm, openDetail, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { openKombaxPublicProfile } from './public-profile.js';

const PAGE_SIZE=24;
const CTA_LABELS={info:'Más información',contact:'Contactar',shop:'Ir a tienda',web:'Visitar web',where:'Dónde encontrar'};
let items=[];
let categories=[];
let managedBrands=[];
let cursor=null;
let done=false;
let currentQuery='';
let currentCategory='';
let activeView='catalog';

const categoryIcon=slug=>icon(({equipamiento:'dumbbell',protecciones:'shield',textil:'package',nutricion:'activity',tecnologia:'settings',servicios:'users'})[slug]||'sparkles',{size:28});
const safeExternal=url=>/^https:\/\/[^\s]+$/i.test(String(url||''))?String(url):'';
const slugify=value=>String(value||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,80);
const ctaLabel=item=>String(item?.cta_label||'').trim()||CTA_LABELS[item?.cta_tipo]||CTA_LABELS.info;

function showcaseBrand(){
  return `<section class="kombax-showcase-brand"><div class="showcase-brand-symbol"><img src="${esc(KOMBAX_BRAND.symbol)}" alt=""></div><div><span>KOMBAX</span><strong>SHOWCASE</strong><small>DESCUBRE · CONECTA · CRECE</small></div><p>Escaparate profesional de marcas, clubes, productos y servicios del mundo de los deportes de contacto.</p></section>`;
}

function controls(){
  return `<div class="showcase-controls"><div class="showcase-search"><input id="showcase-query" type="search" value="${esc(currentQuery)}" placeholder="Buscar marcas, productos o categorías"><button class="btn btn-primary" id="showcase-search">Buscar</button></div><div class="showcase-categories"><button type="button" data-showcase-category="" class="${currentCategory?'':'active'}">Todo</button>${categories.map(c=>`<button type="button" data-showcase-category="${esc(c.slug)}" class="${currentCategory===c.slug?'active':''}">${esc(c.nombre)}</button>`).join('')}</div></div>`;
}

function cardHtml(item){
  const image=safeExternal(item.imagen_url);
  return `<article class="showcase-item ${item.destacado?'featured':''}" data-showcase-detail="${esc(item.id)}" tabindex="0" role="button" aria-label="Abrir ${esc(item.nombre)}">
    <div class="showcase-item-visual">${image?`<img src="${esc(image)}" alt="${esc(item.nombre)}" loading="lazy">`:`<div>${categoryIcon(item.categoria_slug)}<span>${esc(item.categoria_nombre||'Showcase')}</span></div>`}${item.etiqueta_destacada?`<b>${esc(item.etiqueta_destacada)}</b>`:''}<button class="showcase-save-icon ${item.guardado?'active':''}" type="button" data-showcase-save="${esc(item.id)}" aria-label="${item.guardado?'Quitar de guardados':'Guardar'}">${icon(item.guardado?'bookmarkCheck':'bookmark',{size:18})}</button></div>
    <div class="showcase-item-body"><span class="page-kicker">${esc(item.marca_nombre)} ${item.marca_verificada?icon('shieldCheck',{size:13}):''}</span><h2>${esc(item.nombre)}</h2><p>${esc(item.resumen||'Información disponible en KOMBAX Showcase.')}</p><footer><span>${esc(item.categoria_nombre||'General')}</span>${item.precio_orientativo!=null?`<strong>${money(item.precio_orientativo)} <small>orientativo</small></strong>`:'<strong>'+esc(ctaLabel(item))+'</strong>'}</footer></div>
  </article>`;
}

async function shareItem(item){
  const text=`${item.nombre} · ${item.marca_nombre}`;
  const url=safeExternal(item.visitar_url)||location.href;
  try{
    if(navigator.share){await navigator.share({title:item.nombre,text,url});return;}
    await navigator.clipboard.writeText(`${text} ${url}`);toast('Enlace copiado');
  }catch(error){if(error?.name!=='AbortError')toast('No se pudo compartir esta ficha.','error');}
}

async function toggleSaved(item,force){
  const next=typeof force==='boolean'?force:!item.guardado;
  try{await repos.kombaxShowcase.toggleSaved(item.id,next);item.guardado=next;toast(next?'Guardado en tu Showcase':'Eliminado de guardados');if(activeView==='saved')await renderSaved();else renderCatalog();}
  catch(error){setError(error);toast(error?.message||'No se pudo actualizar el guardado.','error');}
}

async function runPrimaryCta(item){
  const type=item.cta_tipo||'info';
  if(type==='contact'&&item.proveedor_social_id){return openKombaxPublicProfile(item.proveedor_social_id);}
  const external=type==='where'?safeExternal(item.donde_encontrar_url):(type==='shop'||type==='web'?safeExternal(item.visitar_url):'');
  if(external){window.open(external,'_blank','noopener,noreferrer');return;}
  if(type==='contact'){
    const contact=safeExternal(item.contacto_url);if(contact){window.open(contact,'_blank','noopener,noreferrer');return;}
  }
  if(item.proveedor_social_id)return openKombaxPublicProfile(item.proveedor_social_id);
  toast('Toda la información disponible está incluida en esta ficha.');
}

function openItem(item){
  const visit=safeExternal(item.visitar_url),where=safeExternal(item.donde_encontrar_url),contact=safeExternal(item.contacto_url),image=safeExternal(item.imagen_url);
  const gallery=(Array.isArray(item.galeria)?item.galeria:[]).map(safeExternal).filter(Boolean).slice(0,3);
  const galleryHtml=gallery.length?`<div class="showcase-detail-gallery">${gallery.map(u=>`<img src="${esc(u)}" alt="${esc(item.nombre)}" loading="lazy">`).join('')}</div>`:'';
  const {wrap}=openDetail({title:item.nombre,subtitle:`${item.marca_nombre} · ${item.categoria_nombre||'Showcase'}`,className:'showcase-detail',body:`<div class="showcase-detail-grid"><div><div class="showcase-detail-media">${image?`<img src="${esc(image)}" alt="${esc(item.nombre)}">`:`${categoryIcon(item.categoria_slug)}<span>${esc(item.categoria_nombre||'KOMBAX')}</span>`}</div>${galleryHtml}</div><div><span class="page-kicker">INFORMACIÓN</span><p>${esc(item.descripcion||item.resumen||'Sin descripción ampliada.')}</p>${item.precio_orientativo!=null?`<div class="showcase-reference-price"><span>Precio orientativo</span><strong>${money(item.precio_orientativo)}</strong></div>`:''}<div class="showcase-no-commerce">La contratación o compra, cuando exista, se realiza directamente con el club, la marca o su web externa.</div></div></div>`,actions:`<button class="btn btn-primary" id="showcase-primary-cta">${esc(ctaLabel(item))}</button><button class="btn btn-ghost" id="showcase-detail-save">${item.guardado?'Quitar de guardados':'Guardar'}</button><button class="btn btn-ghost" id="showcase-detail-share">Compartir</button>${item.proveedor_social_id?'<button class="btn btn-ghost" id="showcase-provider-profile">Ver perfil</button>':''}${visit&&item.cta_tipo!=='shop'&&item.cta_tipo!=='web'?`<a class="btn btn-ghost" href="${esc(visit)}" target="_blank" rel="noopener noreferrer">Web</a>`:''}${where&&item.cta_tipo!=='where'?`<a class="btn btn-ghost" href="${esc(where)}" target="_blank" rel="noopener noreferrer">Dónde encontrar</a>`:''}${contact&&item.cta_tipo!=='contact'&&!item.proveedor_social_id?`<a class="btn btn-ghost" href="${esc(contact)}" target="_blank" rel="noopener noreferrer">Contacto</a>`:''}`,width:'900px'});
  wrap.querySelector('#showcase-primary-cta')?.addEventListener('click',()=>runPrimaryCta(item));
  wrap.querySelector('#showcase-detail-save')?.addEventListener('click',async e=>{await toggleSaved(item);e.currentTarget.textContent=item.guardado?'Quitar de guardados':'Guardar';});
  wrap.querySelector('#showcase-detail-share')?.addEventListener('click',()=>shareItem(item));
  wrap.querySelector('#showcase-provider-profile')?.addEventListener('click',()=>openKombaxPublicProfile(item.proveedor_social_id));
}

function clubFoundersPromo(){
  return `<section class="kx-founders-promo club" aria-label="Promoción de lanzamiento para clubes"><div class="kx-founders-promo-mark">${icon('dojo',{size:28})}</div><div><span>KOMBAX SHOWCASE · LANZAMIENTO</span><strong>PRIMEROS 20 · CLUBES FUNDADORES</strong><p>Los primeros 20 clubes que completen la verificación KOMBAX quedarán incluidos en una <b>ventaja especial de lanzamiento</b> cuando KOMBAX active su modalidad de suscripción. Próximamente comunicaremos en qué consiste.</p><small>La plaza se determina por el orden de verificación KOMBAX.</small></div></section>`;
}

function bindCatalog(){
  document.getElementById('showcase-search')?.addEventListener('click',()=>{currentQuery=document.getElementById('showcase-query')?.value||'';loadCatalog(false);});
  document.getElementById('showcase-query')?.addEventListener('keydown',e=>{if(e.key==='Enter'){currentQuery=e.currentTarget.value;loadCatalog(false);}});
  document.querySelectorAll('[data-showcase-category]').forEach(b=>b.addEventListener('click',()=>{currentCategory=b.dataset.showcaseCategory||'';loadCatalog(false);}));
  document.querySelectorAll('[data-showcase-detail]').forEach(card=>{const open=()=>{const item=items.find(x=>String(x.id)===String(card.dataset.showcaseDetail));if(item)openItem(item);};card.addEventListener('click',open);card.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();open();}});});
  document.querySelectorAll('[data-showcase-save]').forEach(b=>b.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();const item=items.find(x=>String(x.id)===String(b.dataset.showcaseSave));if(item)toggleSaved(item);}));
  document.getElementById('showcase-more')?.addEventListener('click',()=>loadCatalog(true));
  document.getElementById('showcase-manage')?.addEventListener('click',()=>{activeView='manage';renderManagement();});
  document.getElementById('showcase-saved')?.addEventListener('click',()=>{activeView='saved';renderSaved();});
}

function renderCatalog(){
  const headActions=`<div class="row-actions">${managedBrands.length?'<button type="button" class="btn btn-ghost" id="showcase-manage">Gestionar escaparate</button>':''}<button type="button" class="btn btn-ghost" id="showcase-saved">${icon('bookmark',{size:17})} Guardados</button></div>`;
  setMainHtml(`<div class="kombax-showcase-page">${showcaseBrand()}${pageHeader('Marcas y novedades','Descubre productos y servicios y conecta directamente con quienes los ofrecen.',headActions,'KOMBAX Showcase')}${clubFoundersPromo()}${controls()}${items.length?`<div class="showcase-grid">${items.map(cardHtml).join('')}</div>${done?'':'<button class="btn btn-ghost showcase-more" id="showcase-more">Cargar más</button>'}`:empty('Sin contenido publicado','Las fichas activas aparecerán aquí cuando sus responsables las publiquen.')}</div>`);bindCatalog();
}

async function loadCatalog(append=false){
  if(!append){cursor=null;done=false;items=[];setMainHtml('<div class="loading-card">Cargando KOMBAX Showcase…</div>');}
  try{
    const rows=await repos.kombaxShowcase.list(currentQuery,currentCategory,cursor,PAGE_SIZE);
    items=append?[...items,...rows]:rows;const last=rows.at(-1);if(last)cursor={created:last.publicado_en,id:last.id};done=rows.length<PAGE_SIZE;renderCatalog();
  }catch(error){setError(error);setMainHtml(`${showcaseBrand()}${empty('Showcase no disponible',error?.message||'No se ha podido cargar el escaparate. Inténtalo de nuevo.')}`);}
}

async function renderSaved(){
  setMainHtml(`<div class="kombax-showcase-page">${showcaseBrand()}${pageHeader('Guardados','Tus fichas guardadas para consultarlas más tarde.','<button class="btn btn-ghost" id="showcase-back-catalog">Volver al escaparate</button>','KOMBAX Showcase')}<div id="showcase-saved-list"><div class="loading-card">Cargando guardados…</div></div></div>`);
  document.getElementById('showcase-back-catalog')?.addEventListener('click',()=>{activeView='catalog';loadCatalog(false);});
  const box=document.getElementById('showcase-saved-list');
  try{
    const rows=await repos.kombaxShowcase.saved(100);
    box.innerHTML=rows.length?`<div class="showcase-saved-list">${rows.map(x=>`<article><div>${x.imagen_url?`<img src="${esc(safeExternal(x.imagen_url))}" alt="">`:icon('bookmark',{size:24})}</div><section><span class="page-kicker">${esc(x.marca_nombre)}</span><strong>${esc(x.nombre)}</strong><p>${esc(x.resumen||'')}</p><small>Guardado ${dtFmt(x.guardado_en)}</small></section><button class="btn btn-ghost btn-sm" data-saved-remove="${esc(x.id)}">Quitar</button></article>`).join('')}</div>`:empty('Sin guardados','Guarda una ficha para encontrarla rápidamente aquí.');
    box.querySelectorAll('[data-saved-remove]').forEach(b=>b.addEventListener('click',async()=>{await repos.kombaxShowcase.toggleSaved(b.dataset.savedRemove,false);toast('Eliminado de guardados');await renderSaved();}));
  }catch(error){box.innerHTML=empty('No se pudieron cargar tus guardados',error?.message||'Inténtalo de nuevo.');}
}

function itemEditor(brand,item=null){
  const gallery=Array.isArray(item?.galeria)?item.galeria:[];
  openForm({
    title:item?'Editar ficha informativa':'Nueva ficha informativa',
    subtitle:`${brand.nombre} · ${brand.sujeto_tipo==='club'?'máximo 15':'máximo 30'} fichas visibles`,
    width:'820px',initial:{...(item||{}),quitar_imagen:false},
    fields:[
      {name:'nombre',label:'Nombre',required:true,full:true},
      {name:'slug',label:'Identificador',required:true,value:item?.slug||'',help:'Minúsculas, números y guiones.'},
      {name:'categoria_id',label:'Categoría',type:'select',options:categories.map(c=>({value:c.id,label:c.nombre})),value:item?.categoria_id||''},
      {name:'resumen',label:'Resumen',type:'textarea',rows:3,maxLength:320,full:true},
      {name:'descripcion',label:'Descripción completa',type:'textarea',rows:6,maxLength:3000,full:true},
      {name:'imagen_archivo',label:'Subir imagen principal',type:'file',accept:'image/jpeg,image/png,image/webp',full:true,help:'JPG, PNG o WEBP. KOMBAX optimiza la imagen antes de publicarla.'},
      {name:'imagen_url',label:'O usar imagen principal HTTPS',type:'url',full:true},
      {name:'quitar_imagen',label:'Eliminar imagen principal actual',type:'checkbox',value:false,full:true,help:'Si eliminas o sustituyes una imagen subida a KOMBAX, su archivo anterior también se limpia del almacenamiento.'},
      {name:'galeria_archivo_1',label:'Subir imagen adicional 1',type:'file',accept:'image/jpeg,image/png,image/webp'},
      {name:'galeria_1',label:'O URL adicional 1 HTTPS',type:'url',value:gallery[0]||''},
      {name:'galeria_archivo_2',label:'Subir imagen adicional 2',type:'file',accept:'image/jpeg,image/png,image/webp'},
      {name:'galeria_2',label:'O URL adicional 2 HTTPS',type:'url',value:gallery[1]||''},
      {name:'galeria_archivo_3',label:'Subir imagen adicional 3',type:'file',accept:'image/jpeg,image/png,image/webp'},
      {name:'galeria_3',label:'O URL adicional 3 HTTPS',type:'url',value:gallery[2]||''},
      {name:'precio_orientativo',label:'Precio orientativo opcional',type:'number',min:0,step:'0.01'},
      {name:'cta_tipo',label:'Acción principal',type:'select',value:item?.cta_tipo||'info',options:Object.entries(CTA_LABELS).map(([value,label])=>({value,label}))},
      {name:'cta_label',label:'Texto personalizado de la acción',maxLength:80,value:item?.cta_label||'',help:'Opcional. Si queda vacío se usa el texto estándar.'},
      {name:'visitar_url',label:'Tienda o web (HTTPS)',type:'url',full:true},
      {name:'donde_encontrar_url',label:'Dónde encontrar (HTTPS)',type:'url',full:true},
      {name:'contacto_url',label:'Contacto externo (HTTPS)',type:'url',full:true}
    ],
    submitText:'Guardar borrador',
    onSubmit:async v=>{
      const uploaded=[];
      const oldUrls=[item?.imagen_url,...gallery].filter(Boolean);
      try{
        let imagen=v.quitar_imagen?'':String(v.imagen_url??item?.imagen_url??'').trim();
        if(v.imagen_archivo){const out=await repos.kombaxShowcase.uploadImage(brand.id,v.imagen_archivo);uploaded.push(out.path);imagen=out.url;}
        if(imagen&&!safeExternal(imagen))throw new Error('La imagen principal debe ser una subida válida o una URL HTTPS.');
        const galeria=[];
        for(let i=1;i<=3;i++){
          const file=v[`galeria_archivo_${i}`];let url=String(v[`galeria_${i}`]??gallery[i-1]??'').trim();
          if(file){const out=await repos.kombaxShowcase.uploadImage(brand.id,file);uploaded.push(out.path);url=out.url;}
          if(url){if(!safeExternal(url))throw new Error(`La imagen adicional ${i} debe usar una URL HTTPS válida.`);galeria.push(url);}
        }
        const required=v.cta_tipo==='where'?v.donde_encontrar_url:(v.cta_tipo==='shop'||v.cta_tipo==='web'?v.visitar_url:'');
        if(required&&!safeExternal(required))throw new Error('La acción principal seleccionada necesita una URL HTTPS válida.');
        await repos.kombaxShowcase.saveItem({...v,id:item?.id||null,marca_id:brand.id,slug:v.slug||slugify(v.nombre),imagen_url:imagen,galeria,moneda:'EUR'});
        const retained=new Set([imagen,...galeria].filter(Boolean));
        await repos.kombaxShowcase.removeOwnedImages(oldUrls.filter(u=>!retained.has(u))).catch(()=>{});
        toast('Ficha guardada. Pulsa Publicar para hacerla visible en Showcase.');await renderManagement(brand.id);
      }catch(error){for(const path of uploaded)await repos.kombaxShowcase.removeUploadedImage(path).catch(()=>{});throw error;}
    }
  });
}

async function renderManagement(selectedBrandId=''){
  const brand=managedBrands.find(x=>x.id===selectedBrandId)||managedBrands[0];
  if(!brand){activeView='catalog';return loadCatalog(false);}
  setMainHtml(`<div class="kombax-showcase-page">${showcaseBrand()}${pageHeader('Gestión de Showcase','Crea fichas con imágenes, revísalas como borrador y publícalas cuando estén listas. Una ficha publicada aparece en el escaparate público de KOMBAX.','<button class="btn btn-ghost" id="showcase-back">Volver al escaparate</button>','KOMBAX Showcase')}<div class="showcase-management-head"><label>Espacio gestionado<select id="showcase-brand-select">${managedBrands.map(x=>`<option value="${esc(x.id)}" ${x.id===brand.id?'selected':''}>${esc(x.nombre)} · ${x.sujeto_tipo==='club'?'Club':'Marca'}</option>`).join('')}</select></label><div class="showcase-provider-limit"><strong>${Number(brand.publicados||0)}/${Number(brand.limite_visible||30)}</strong><span>fichas visibles</span></div><button class="btn btn-primary" id="showcase-new-item">+ Nueva ficha</button></div><div id="showcase-managed-items"><div class="loading-card">Cargando fichas…</div></div></div>`);
  document.getElementById('showcase-back')?.addEventListener('click',()=>{activeView='catalog';loadCatalog(false);});document.getElementById('showcase-brand-select')?.addEventListener('change',e=>renderManagement(e.target.value));document.getElementById('showcase-new-item')?.addEventListener('click',()=>itemEditor(brand));
  const box=document.getElementById('showcase-managed-items');
  try{
    const rows=await repos.kombaxShowcase.myItems(brand.id);
    box.innerHTML=rows.length?`<div class="showcase-manage-list">${rows.map(x=>`<article><div><span class="page-kicker">${esc(x.estado)}${x.destacado?' · destacado':''}</span><strong>${esc(x.nombre)}</strong><small>${esc(ctaLabel(x))} · Actualizado ${dtFmt(x.actualizado_en)}</small></div><div class="row-actions"><button class="btn btn-ghost btn-sm" data-showcase-edit="${esc(x.id)}">Editar</button>${x.estado!=='publicado'?`<button class="btn btn-primary btn-sm" data-showcase-state="publicado" data-showcase-id="${esc(x.id)}">Publicar</button>`:`<button class="btn btn-ghost btn-sm" data-showcase-state="archivado" data-showcase-id="${esc(x.id)}">Archivar</button>`}<button class="btn btn-danger btn-sm" data-showcase-delete="${esc(x.id)}">${icon('trash',{size:14})} Eliminar</button></div></article>`).join('')}</div>`:empty('Sin fichas','Crea la primera ficha informativa de este espacio.');
    box.querySelectorAll('[data-showcase-edit]').forEach(b=>b.addEventListener('click',()=>itemEditor(brand,rows.find(x=>x.id===b.dataset.showcaseEdit))));
    box.querySelectorAll('[data-showcase-state]').forEach(b=>b.addEventListener('click',()=>confirmDialog(b.dataset.showcaseState==='publicado'?'Publicar ficha':'Archivar ficha',b.dataset.showcaseState==='publicado'?'La información será visible en el escaparate público.':'La ficha dejará de mostrarse sin eliminar su historial.',async()=>{await repos.kombaxShowcase.itemState(b.dataset.showcaseId,b.dataset.showcaseState);toast(b.dataset.showcaseState==='publicado'?'Ficha publicada':'Ficha archivada');await renderManagement(brand.id);},{confirmText:b.dataset.showcaseState==='publicado'?'Publicar':'Archivar'})));
    box.querySelectorAll('[data-showcase-delete]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Eliminar ficha de Showcase','La ficha desaparecerá de Showcase, del perfil público y de los guardados. Las imágenes subidas por esta cuenta que ya no se usan también se eliminarán del almacenamiento.',async()=>{await repos.kombaxShowcase.deleteItem(b.dataset.showcaseDelete);toast('Ficha e imágenes propias eliminadas');await renderManagement(brand.id);},{confirmText:'Eliminar definitivamente',danger:true})));
  }catch(error){box.innerHTML=empty('No se pudo cargar la gestión',error?.message||'Revisa tus permisos.');}
}

export async function renderShowcase(){
  setMainHtml('<div class="loading-card">Abriendo KOMBAX Showcase…</div>');
  try{[categories,managedBrands]=await Promise.all([repos.kombaxShowcase.categories(),repos.kombaxShowcase.myBrands().catch(()=>[])]);}catch(error){setError(error);setMainHtml(empty('Showcase no disponible',error?.message||'No se ha podido cargar el escaparate. Inténtalo de nuevo.'));return;}
  if(activeView==='manage'&&managedBrands.length)return renderManagement();
  if(activeView==='saved')return renderSaved();
  activeView='catalog';return loadCatalog(false);
}
