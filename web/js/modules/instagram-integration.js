import {backend} from '../core/backend.js';
import {esc} from '../core/utils.js';
import {openDetail,confirmDialog,toast,closeModal} from '../ui/components.js';

export const instagramEnabled=()=>window.UW_CONFIG?.integrations?.instagram?.enabled===true;
const FLOW_PREFIX='kx_meta_flow:';
export const flowStorageKey=id=>`${FLOW_PREFIX}${id}`;
const hex=bytes=>Array.from(bytes,x=>x.toString(16).padStart(2,'0')).join('');
const call=body=>backend.invokeFunction('meta-instagram',body,60000);
const statusLabel={not_connected:'No conectado',connected:'Conectado',expired:'Autorización caducada',revoked:'Autorización retirada',error:'Requiere revisión'};
const jobLabel={creating:'Preparando',processing:'Procesando en Instagram',publishing:'Enviando a Instagram',published:'Publicado en Instagram',failed:'No publicado',uncertain:'Resultado pendiente de revisión'};

export async function startInstagramConnection(socialId){
 if(!instagramEnabled())throw new Error('La conexión con Instagram todavía no está habilitada.');
 const canonical=new URL(window.UW_CONFIG?.release?.webUrl||'https://kombax.es');
 if(location.origin!==canonical.origin)throw new Error('Conecta Instagram desde la web KOMBAX autenticada. Después podrás utilizar la conexión desde tus dispositivos.');
 const proof=hex(crypto.getRandomValues(new Uint8Array(32))),proof_hash=hex(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(proof))));
 const response=await call({action:'begin',social_id:socialId,proof_hash});
 const url=new URL(response.url);if(url.origin!=='https://www.facebook.com'||!url.pathname.endsWith('/dialog/oauth'))throw new Error('No se ha podido iniciar la conexión.');
 // Only a short-lived browser binding; never tokens, App Secret or OAuth codes.
 for(let i=sessionStorage.length-1;i>=0;i--){const key=sessionStorage.key(i);if(key?.startsWith(FLOW_PREFIX)){try{if(JSON.parse(sessionStorage.getItem(key)).expires<Date.now())sessionStorage.removeItem(key);}catch{sessionStorage.removeItem(key);}}}
 sessionStorage.setItem(flowStorageKey(response.flow_id),JSON.stringify({proof,social_id:socialId,expires:Date.now()+10*60*1000}));
 location.assign(url.toString());
}

export async function openInstagramIntegration(identity){
 if(!identity?.id)return;
 if(!instagramEnabled()){openDetail({title:'Instagram',subtitle:identity.nombre_publico,body:'<p>Integración preparada para pruebas. La conexión estará disponible cuando administración complete la configuración y el despliegue.</p>'});return;}
 try{
  const data=await call({action:'status',social_id:identity.id});
  const modal=openDetail({title:'Instagram · Redes sociales',subtitle:identity.nombre_publico,
   body:`<p><strong>${esc(statusLabel[data.status]||'Requiere revisión')}</strong>${data.username?` · @${esc(data.username)}`:''}</p><p>Conecta una cuenta profesional vinculada a una página de Facebook. Esta conexión pertenece solo a esta identidad. Cada publicación requiere tu confirmación.</p>${(data.publications||[]).length?`<details><summary>Últimos envíos a Instagram</summary>${data.publications.map(j=>`<p>${esc(jobLabel[j.status]||'Requiere revisión')}${j.media_id?` · ${esc(j.media_id)}`:''}${j.status==='processing'?` <button class="btn btn-ghost btn-sm" data-instagram-job="${esc(j.id)}">Comprobar envío</button>`:''}</p>`).join('')}</details>`:''}`,
   actions:`${location.origin==='https://appassets.androidplatform.net'?'<a class="btn btn-primary" href="https://kombax.es" target="_blank" rel="noopener noreferrer">Conectar desde la web KOMBAX</a>':`<button class="btn btn-primary" data-instagram-connect>${data.status==='connected'?'Volver a conectar':'Conectar Instagram'}</button>`}${data.status==='connected'?'<button class="btn btn-ghost" data-instagram-verify>Comprobar conexión</button>':''}${data.status!=='not_connected'?'<button class="btn btn-danger" data-instagram-disconnect>Desconectar</button>':''}`});
  const run=async work=>{try{await work();}catch{toast('No se ha podido completar la operación. Inténtalo de nuevo.','error');}};
  modal.wrap.querySelector('[data-instagram-connect]')?.addEventListener('click',()=>run(()=>startInstagramConnection(identity.id)));
  modal.wrap.querySelector('[data-instagram-verify]')?.addEventListener('click',()=>run(async()=>{await call({action:'verify',social_id:identity.id});toast('Conexión comprobada');closeModal();await openInstagramIntegration(identity);}));
  modal.wrap.querySelector('[data-instagram-disconnect]')?.addEventListener('click',()=>confirmDialog('Desconectar Instagram',`Se retirará la conexión de ${identity.nombre_publico}. No elimina publicaciones ya enviadas a Instagram ni afecta a otras identidades.`,()=>run(async()=>{await call({action:'disconnect',social_id:identity.id});toast('Instagram desconectado');closeModal();}),{confirmText:'Desconectar'}));
  modal.wrap.querySelectorAll('[data-instagram-job]').forEach(b=>b.addEventListener('click',()=>run(async()=>{b.disabled=true;const result=await call({action:'publication_status',social_id:identity.id,job_id:b.dataset.instagramJob});toast(jobLabel[result.job.status]||'Requiere revisión');closeModal();await openInstagramIntegration(identity);})));
 }catch{toast('No se ha podido consultar Instagram. Comprueba que administras esta identidad y vuelve a intentarlo.','error');}
}

export async function publishPostToInstagram(post,identity){
 if(!instagramEnabled()||!identity?.id||post.autor_id!==identity.id)return;
 try{
  const status=await call({action:'status',social_id:identity.id});
  if(status.status!=='connected'){await openInstagramIntegration(identity);return;}
  const modal=openDetail({title:'Publicar también en Instagram',subtitle:`${identity.nombre_publico} · @${status.username}`,
   body:`<p>${esc(post.texto||'')}</p><p>Se enviará la imagen JPEG original y este texto. La imagen debe tener un formato admitido por Instagram. El encuadre visual de KOMBAX no modifica el archivo original.</p><p>Esta acción crea una publicación externa. Retirarla después en KOMBAX no elimina la copia de Instagram.</p>`,
   actions:'<button class="btn btn-primary" data-instagram-publish>Confirmar publicación en Instagram</button>'});
  modal.wrap.querySelector('[data-instagram-publish]')?.addEventListener('click',async e=>{
   const button=e.currentTarget;button.disabled=true;
   try{const result=await call({action:'publish',social_id:identity.id,post_id:post.id,confirm:true});toast(jobLabel[result.job.status]||'Requiere revisión');closeModal();}
   catch{toast('No se ha podido completar el envío. Consulta el estado de Instagram antes de volver a intentarlo.','error');button.disabled=false;}
  });
 }catch{toast('No se ha podido consultar Instagram. Inténtalo de nuevo.','error');}
}
