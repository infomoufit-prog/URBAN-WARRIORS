import {backend} from '../core/backend.js';
import {repos} from '../core/repositories.js';
import {esc,humanError} from '../core/utils.js';
import {openDetail,openForm,toast} from '../ui/components.js';

export function publishProfessionalDocument(credentialId){
 return openForm({title:'Publicar copia documental',subtitle:'Esta copia será visible en el perfil público. No se publica la evidencia privada original. Revisa y oculta datos personales innecesarios antes de subirla.',fields:[{name:'document',label:'Copia para mostrar en público',type:'file',required:true,accept:'application/pdf,image/jpeg,image/png,image/webp'},{name:'authorized',label:'He revisado esta copia y autorizo expresamente su publicación en mi perfil público.',type:'checkbox',required:true}],submitText:'Publicar copia',onSubmit:async values=>{await repos.kombaxProfiles.publishProfessionalDocument(credentialId,values.document,values.authorized);toast('Copia publicada. Oculta la credencial para retirar su acceso público.');}});
}
export async function openProfessionalDocuments(profileId){
 const modal=openDetail({title:'Documentos públicos profesionales',body:'<p>Cargando documentos…</p>'});
 const body=modal.wrap.querySelector('.detail-modal-body');
 try{
  const rows=await repos.kombaxProfiles.professionalPublicDocuments(profileId);
  if(!modal.wrap.isConnected)return;
  body.innerHTML=`<p>Copias elegidas por el titular y asociadas a sus acreditaciones. La copia publicada no sustituye la evidencia privada revisada.</p>${rows.map(d=>`<article class="card"><h3>${esc(d.title)}</h3><p>${esc(d.issuer||'')}</p><button type="button" class="btn btn-primary" data-view-document="${esc(d.credential_id)}">Ver documento</button></article>`).join('')||'<p>No hay copias documentales públicas.</p>'}`;
  body.querySelectorAll('[data-view-document]').forEach(button=>button.addEventListener('click',async()=>{
   button.disabled=true;
   try{
    const blob=await backend.publicDocumentDownload(button.dataset.viewDocument);
    if(!modal.wrap.isConnected)return;
    const url=URL.createObjectURL(blob);
    const detail=openDetail({title:'Copia documental pública',body:blob.type==='application/pdf'?`<iframe title="Documento PDF" sandbox src="${esc(url)}" style="width:100%;height:65vh;border:0"></iframe>`:`<img src="${esc(url)}" alt="Copia documental pública" style="max-width:100%;height:auto">`});
    detail.wrap.addEventListener('kx:modal-before-close',()=>URL.revokeObjectURL(url),{once:true});
   }catch(error){toast(humanError(error),'error');}finally{button.disabled=false;}
  }));
 }catch(error){if(modal.wrap.isConnected)body.innerHTML=`<p role="alert">${esc(humanError(error))}</p>`;}
}
