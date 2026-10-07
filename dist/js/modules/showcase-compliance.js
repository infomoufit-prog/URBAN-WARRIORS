import {repos} from '../core/repositories.js';
import {openForm,toast} from '../ui/components.js';

export async function reviewProductCompliance(item,{onSaved=()=>{}}={}){
 const snapshot=await repos.kombaxShowcase.productComplianceEditor(item.id),p=snapshot?.product;
 if(!p){toast('El vendedor aún no ha presentado la ficha de seguridad');return;}
 return openForm({title:'Revisión de seguridad del producto',subtitle:item.title||item.nombre||'',width:'850px',fields:[
  {name:'snapshot',label:'Ficha presentada por el vendedor',type:'textarea',disabled:true,full:true,rows:14,value:[['Tipo de producto',p.category_code],['Fabricante',p.manufacturer_name],['Dirección postal del fabricante',p.manufacturer_postal_address],['Correo del fabricante',p.manufacturer_email],['Nombre del responsable en la UE',p.eu_responsible_person_name],['Dirección postal del responsable en la UE',p.eu_responsible_person_postal_address],['Correo del responsable en la UE',p.eu_responsible_person_email],['Modelo o referencia',p.model_reference],['Advertencias de seguridad',p.safety_warnings],['Instrucciones de seguridad',p.safety_instructions],['Documentación',(p.compliance_documents||[]).map(d=>typeof d==='string'?d:d?.url||d?.storage_path||d?.private_path||'').filter(Boolean).join('\n')]].filter(([,v])=>v).map(([k,v])=>k+': '+v).join('\n\n')},
  {name:'decision',label:'Decisión de revisión',type:'select',required:true,options:[{value:'request_information',label:'Solicitar información'},{value:'approve',label:'Aprobar ficha de seguridad'},{value:'remove',label:'Retirar por seguridad'}]},
  {name:'note',label:'Motivo de la revisión',type:'textarea',required:true,minLength:10,maxLength:4000,full:true},
  {name:'reviewed',label:'He revisado la ficha y su documentación antes de decidir',type:'checkbox',value:false,required:true,full:true}
 ],submitText:'Registrar revisión',onSubmit:async values=>{
  if(!values.reviewed||!['approve','request_information','remove'].includes(values.decision))return;
  await repos.kombaxShowcase.reviewProductCompliance(item.id,values.decision,values.note);
  toast('Revisión registrada');await onSaved();
 }});
}

export async function openProductCompliance(item,{publish=false,onSaved=()=>{}}={}){
 const [snapshot,rules]=await Promise.all([repos.kombaxShowcase.productComplianceEditor(item.id),repos.kombaxShowcase.complianceRules()]);
 const p=snapshot?.product||{},documents=Array.isArray(p.compliance_documents)?p.compliance_documents:[];
 const field=(name,label,extra={})=>({name,label,value:p[name]??'',...extra});
 const modal=openForm({title:'Ficha de seguridad del producto',subtitle:'Completa los datos del producto. Las categorías restringidas requieren revisión antes de publicar.',width:'850px',fields:[
  field('category_code','Tipo de producto',{type:'select',required:true,options:[{value:'',label:'Selecciona el tipo de producto'},...(rules||[]).map(r=>({value:r.category_code,label:r.label}))]}),
  field('manufacturer_name','Fabricante'),field('manufacturer_postal_address','Dirección postal del fabricante',{full:true}),field('manufacturer_email','Correo del fabricante',{type:'email'}),field('manufacturer_country','País del fabricante (ISO)',{maxLength:2}),
  field('manufacturer_in_eu','El fabricante está establecido en la UE',{type:'checkbox',value:p.manufacturer_in_eu===true,full:true}),
  field('eu_responsible_person_name','Nombre del responsable en la UE'),field('eu_responsible_person_postal_address','Dirección postal del responsable en la UE',{full:true}),field('eu_responsible_person_email','Correo del responsable en la UE',{type:'email'}),
  field('model_reference','Modelo o referencia'),field('country_of_origin','País de origen (ISO)',{maxLength:2}),
  field('ce_marking_confirmed','Confirmo el marcado CE cuando corresponda',{type:'checkbox',value:p.ce_marking_confirmed===true,full:true}),
  field('safety_warnings','Advertencias de seguridad',{type:'textarea',maxLength:4000,full:true}),field('safety_instructions','Instrucciones de seguridad',{type:'textarea',maxLength:8000,full:true}),
  {name:'documentation_urls',label:'Enlaces HTTPS a documentación del producto',type:'textarea',full:true,help:'Un enlace por línea. Los documentos existentes se conservan; un enlace no equivale a una acreditación verificada.'}
 ],submitText:publish?'Guardar y solicitar publicación':'Guardar ficha de seguridad',onSubmit:async values=>{
  const rule=(rules||[]).find(r=>r.category_code===values.category_code);if(!rule)throw new Error('Selecciona el tipo de producto');
  const links=String(values.documentation_urls||'').split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
  if(links.some(x=>{try{const u=new URL(x);return u.protocol!=='https:'||Boolean(u.username||u.password);}catch{return true;}}))throw new Error('Usa enlaces HTTPS válidos para la documentación');
  const docs=[...documents,...links.filter(url=>!documents.some(d=>d?.url===url)).map(url=>({url,source:'seller_declared_link'}))];
  if(rule.documentation_required&&!docs.length)throw new Error('Añade la documentación requerida para este producto');
  const out=await repos.kombaxShowcase.saveProductCompliance(item.id,{...p,...values,compliance_documents:docs});
  if(publish&&out?.commerce_ready===true){await repos.kombaxShowcase.itemState(item.id,'publicado');toast('Ficha publicada');}
  else toast(out?.data?.moderation_state==='pending_review'?'Ficha enviada a revisión':out?.commerce_ready===true?'Ficha de seguridad guardada':'Ficha guardada; completa los datos requeridos');
  await onSaved();
 }});
 const update=()=>{
  const f=modal.form,r=(rules||[]).find(x=>x.category_code===f.elements.category_code.value),nonEu=!f.elements.manufacturer_in_eu.checked;
  for(const name of ['manufacturer_name','manufacturer_postal_address','manufacturer_email'])f.elements[name].required=Boolean(r?.manufacturer_required);
  for(const name of ['eu_responsible_person_name','eu_responsible_person_postal_address','eu_responsible_person_email']){const needed=Boolean(r?.eu_responsible_person_when_non_eu&&nonEu);f.elements[name].required=needed;f.elements[name].closest('.field').hidden=!needed;}
  f.elements.ce_marking_confirmed.required=r?.ce_requirement==='required';f.elements.safety_warnings.required=Boolean(r?.warnings_required);
  f.elements.documentation_urls.required=Boolean(r?.documentation_required&&!documents.length);
 };modal.form.addEventListener('change',update);update();return modal;
}
