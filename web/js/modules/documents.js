import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, dateFmt } from '../core/utils.js';
import { pageHeader, card, table, empty, badge, openForm, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const TYPES=[
  ['inscripcion_asociacion','Inscripción asociación'],['contrato_alta','Ficha / contrato de alta'],['autorizacion','Autorización'],
  ['consentimiento','Consentimiento'],['tutor','Documentación tutor/a'],['certificado','Certificado'],['medico','Documento médico'],
  ['identidad','Identidad'],['otro','Otro']
];
const typeLabel=(v)=>TYPES.find(x=>x[0]===v)?.[1]||v||'Otro';
const statusKind=(s)=>s==='vigente'?'ok':s==='sustituido'?'warn':'neutral';
const opts=(rows,label=(r)=>`${r.apellidos}, ${r.nombre}`)=>rows.map(r=>({value:r.id,label:label(r)}));
const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));
async function downloadDocument(doc){const blob=await repos.documents.download(doc.storage_path);const href=URL.createObjectURL(blob);const a=document.createElement('a');a.href=href;a.download=doc.nombre||'documento';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(href),1500);}

function uploadFields(members,{includeMember=true}={}){
  return [
    ...(includeMember?[{name:'socio_id',label:'Alumno',type:'select',required:true,options:opts(members)}]:[]),
    {name:'tipo',label:'Tipo de documento',type:'select',required:true,value:'inscripcion_asociacion',options:TYPES.map(([value,label])=>({value,label}))},
    {name:'nombre',label:'Nombre del documento',placeholder:'Ej. Inscripción asociación 2026'},
    {name:'fecha_documento',label:'Fecha del documento',type:'date'},
    {name:'firmado',label:'Documento firmado',type:'checkbox',value:true},
    {name:'visible_familia',label:'Visible para familia/alumno',type:'checkbox',value:true},
    {name:'archivo',label:'Archivo',type:'file',required:true,accept:'.pdf,.jpg,.jpeg,.png,.webp',help:'PDF, JPG, PNG o WEBP · máximo 10 MB · almacenamiento privado.'},
    {name:'observaciones',label:'Observaciones',type:'textarea',full:true}
  ];
}

export async function renderDocuments(){
  setMainHtml('<div class="loading-card">Cargando archivo documental…</div>');
  try{
    const [docs,members]=await Promise.all([repos.documents.list(),repos.members.list()]);
    const can=has(state.session,'document');
    const memberMap=new Map(members.map(m=>[m.id,m]));
    const active=docs.filter(d=>d.estado!=='archivado'&&d.estado!=='sustituido');
    const signed=active.filter(d=>d.firmado).length;
    const rows=docs.map(d=>{
      const m=memberMap.get(d.socio_id)||{};
      const search=`${m.nombre||''} ${m.apellidos||''} ${d.nombre||''} ${typeLabel(d.tipo)} ${d.observaciones||''}`.toLowerCase();
      return `<tr data-doc-row data-search="${esc(search)}" data-status="${esc(d.estado||'vigente')}" data-type="${esc(d.tipo||'otro')}">
        <td><strong>${esc(m.apellidos||'')}, ${esc(m.nombre||'')}</strong></td>
        <td><strong>${esc(d.nombre)}</strong><br><small>${esc(typeLabel(d.tipo))}</small></td>
        <td>${dateFmt(d.fecha_documento||d.creado_en)}</td>
        <td>${badge(d.firmado?'Firmado':'Pendiente',d.firmado?'ok':'warn')}</td>
        <td>${badge(d.estado||'vigente',statusKind(d.estado||'vigente'))}</td>
        <td>${d.visible_familia?badge('Familia','neutral'):badge('Interno','neutral')}</td>
        <td><div class="row-actions"><button class="btn btn-ghost btn-sm view-doc" data-id="${esc(d.id)}">${icon('eye',{size:14})} Ver</button><button class="btn btn-ghost btn-sm download-doc" data-id="${esc(d.id)}">${icon('download',{size:14})} Descargar</button>${can?`<button class="btn btn-ghost btn-sm edit-doc" data-id="${esc(d.id)}">${icon('edit',{size:14})} Ficha</button><button class="btn btn-ghost btn-sm replace-doc" data-id="${esc(d.id)}">${icon('refresh',{size:14})} Sustituir</button>${d.estado==='vigente'?`<button class="btn btn-ghost btn-sm archive-doc" data-id="${esc(d.id)}">Archivar</button>`:''}<button class="btn btn-danger btn-sm delete-doc" data-id="${esc(d.id)}">Eliminar</button>`:''}</div></td>
      </tr>`;
    });
    setMainHtml(`${pageHeader('Archivo documental','Expedientes privados de inscripción, contratos, autorizaciones y documentación de alumnos',can?`<button class="btn btn-primary" id="new-document">${icon('upload',{size:16})} Subir documento</button>`:'','Secretaría · Expedientes')}
      <div class="metrics"><div class="metric"><span>Documentos</span><strong>${docs.length}</strong><small>expediente digital</small></div><div class="metric"><span>Vigentes</span><strong>${active.length}</strong><small>no archivados</small></div><div class="metric"><span>Firmados</span><strong>${signed}</strong><small>confirmados</small></div><div class="metric"><span>Alumnos</span><strong>${new Set(docs.map(d=>d.socio_id)).size}</strong><small>con documentación</small></div></div>
      <div class="filter-bar"><input id="doc-search" type="search" placeholder="Buscar alumno, documento u observaciones…"><select id="doc-type"><option value="">Todos los tipos</option>${TYPES.map(([v,l])=>`<option value="${esc(v)}">${esc(l)}</option>`).join('')}</select><select id="doc-status"><option value="">Todos los estados</option><option value="vigente">Vigente</option><option value="archivado">Archivado</option><option value="sustituido">Sustituido</option></select><span class="badge badge-neutral" id="doc-count">${docs.length} archivos</span></div>
      ${card('Expedientes',rows.length?table(['Alumno','Documento','Fecha','Firma','Estado','Visibilidad','Acciones'],rows):empty('Archivo vacío','Sube la inscripción física o documentación de un alumno para crear su expediente digital.'))}`);

    const reload=()=>renderDocuments();
    const apply=()=>{const q=String(document.getElementById('doc-search')?.value||'').toLowerCase().trim(),t=document.getElementById('doc-type')?.value||'',st=document.getElementById('doc-status')?.value||'';let n=0;document.querySelectorAll('[data-doc-row]').forEach(r=>{const ok=(!q||r.dataset.search.includes(q))&&(!t||r.dataset.type===t)&&(!st||r.dataset.status===st);r.style.display=ok?'':'none';if(ok)n++;});document.getElementById('doc-count').textContent=`${n} archivos`;};
    document.getElementById('doc-search')?.addEventListener('input',apply);document.getElementById('doc-type')?.addEventListener('change',apply);document.getElementById('doc-status')?.addEventListener('change',apply);
    document.getElementById('new-document')?.addEventListener('click',()=>openForm({title:'Subir documento al expediente',subtitle:'El archivo se almacena de forma privada y queda vinculado al alumno.',width:'820px',fields:uploadFields(members),onSubmit:async v=>{await repos.documents.upload(v.socio_id,v.archivo,v);toast('Documento archivado en el expediente');await reload();}}));
    bind('.view-doc',async id=>{try{const d=docs.find(x=>x.id===id);const url=await repos.documents.url(d.storage_path);window.open(url,'_blank','noopener,noreferrer');}catch(e){setError(e)}});
    bind('.download-doc',async id=>{try{const d=docs.find(x=>x.id===id);await downloadDocument(d);toast('Descarga iniciada');}catch(e){setError(e)}});
    bind('.edit-doc',id=>{const d=docs.find(x=>x.id===id);openForm({title:'Editar ficha documental',fields:[{name:'nombre',label:'Nombre',required:true},{name:'tipo',label:'Tipo',type:'select',options:TYPES.map(([value,label])=>({value,label}))},{name:'fecha_documento',label:'Fecha del documento',type:'date'},{name:'firmado',label:'Firmado',type:'checkbox'},{name:'visible_familia',label:'Visible para familia/alumno',type:'checkbox'},{name:'observaciones',label:'Observaciones',type:'textarea',full:true}],initial:d,onSubmit:async v=>{await repos.documents.update(id,v);toast('Ficha documental actualizada');await reload();}})});
    bind('.replace-doc',id=>{const d=docs.find(x=>x.id===id),m=memberMap.get(d.socio_id)||{};openForm({title:'Sustituir documento',subtitle:`${m.nombre||''} ${m.apellidos||''} · el archivo anterior quedará marcado como sustituido.`,width:'820px',fields:uploadFields(members,{includeMember:false}),initial:{tipo:d.tipo,nombre:d.nombre,fecha_documento:d.fecha_documento,firmado:true,visible_familia:d.visible_familia,observaciones:d.observaciones},onSubmit:async v=>{await repos.documents.upload(d.socio_id,v.archivo,{...v,reemplaza_id:id});toast('Documento sustituido con trazabilidad');await reload();}})});
    bind('.archive-doc',id=>confirmDialog('Archivar documento','El archivo seguirá disponible en el histórico del expediente.',async()=>{await repos.documents.archive(id);toast('Documento archivado');await reload();},{confirmText:'Archivar'}));
    bind('.delete-doc',id=>confirmDialog('Eliminar definitivamente','Esta acción elimina la ficha documental y el archivo de Storage. Úsala solo para duplicados o documentos subidos por error.',async()=>{await repos.documents.delete(id);toast('Documento eliminado');await reload();},{confirmText:'Eliminar',danger:true}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Archivo documental')} ${empty('No se pudo cargar el archivo',e.message)}`)}
}
