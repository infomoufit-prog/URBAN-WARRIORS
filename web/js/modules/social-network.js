import { repos } from '../core/repositories.js';
import { esc, humanError } from '../core/utils.js';
import { openForm, toast, setError } from '../ui/components.js';
import { t } from '../i18n/index.js';

export const RELATION_LABEL={
  conexion_kombax:t('social.relations.connection'),
  competidor_club:t('social.relations.fighterClub'),
  club_federacion:t('social.relations.clubFederation'),
  competidor_profesional:t('social.relations.fighterProfessional'),
  marca_club:t('social.relations.brandClub'),
  marca_competidor:t('social.relations.brandFighter'),
  profesional_club:t('social.relations.professionalClub'),
  profesional_evento:t('social.relations.professionalEvent')
};

export function possibleRelations(fromType,toType){
  const a=String(fromType||''),b=String(toType||'');
  const pair=new Set([a,b]);
  const out=['conexion_kombax'];
  if(pair.has('competidor')&&pair.has('club'))out.push('competidor_club');
  if(pair.has('club')&&pair.has('federacion'))out.push('club_federacion');
  if(pair.has('competidor')&&pair.has('profesional'))out.push('competidor_profesional');
  if(pair.has('marca')&&pair.has('club'))out.push('marca_club');
  if(pair.has('marca')&&pair.has('competidor'))out.push('marca_competidor');
  if(pair.has('profesional')&&pair.has('club'))out.push('profesional_club');
  return [...new Set(out)];
}

async function existingRelation(targetId,senders){
  const pages=await Promise.all(senders.map(x=>repos.kombaxSocial.relations(x.id,50).catch(()=>[])));
  for(const rows of pages){
    const found=(rows||[]).find(r=>{
      const touches=String(r.origen_social_id)===String(targetId)||String(r.destino_social_id)===String(targetId);
      return touches&&['pending','confirmed'].includes(String(r.estado||''));
    });
    if(found)return found;
  }
  return null;
}

export async function requestNetworkConnection(target,{onSent}={}){
  try{
    const own=await repos.kombaxSocial.networkProfiles();
    const senders=(Array.isArray(own)?own:[]).filter(x=>String(x.id)!==String(target?.id));
    if(!senders.length){toast(t('social.network.noIdentity'),'error');return null;}
    const existing=await existingRelation(target.id,senders);
    if(existing?.estado==='confirmed'){toast(t('social.network.alreadyInNetwork',{profile:target.nombre_publico||t('social.empty.unavailableTitle')}));return existing;}
    if(existing?.estado==='pending'){toast(t('social.network.alreadyPending'));return existing;}
    const targetType=target?.perfil_tipo||target?.sujeto_tipo||'';
    const modal=openForm({
      title:`${t('social.actions.addNetwork')} · ${target.nombre_publico||t('social.empty.unavailableTitle')}`,
      subtitle:t('social.network.privateConnection'),
      fields:[
        {name:'origen',label:t('social.network.requestAs'),type:'select',required:true,value:senders[0].id,options:senders.map(x=>({value:x.id,label:x.identity_label||x.nombre_publico}))},
        {name:'tipo',label:t('social.network.connectionType'),type:'select',required:true,options:[]},
        {name:'nota',label:t('social.network.optionalMessage'),type:'textarea',full:true,rows:3,maxLength:500,help:t('social.network.messageHelp')}
      ],
      submitText:t('social.actions.addNetwork'),
      onSubmit:async v=>{
        await repos.kombaxSocial.requestRelation(v.origen,target.id,v.tipo||'conexion_kombax',v.nota||'');
        toast(t('social.actions.addNetwork'));
        await onSent?.();
      }
    });
    const source=modal.form.elements.origen,type=modal.form.elements.tipo;
    const fill=()=>{
      const from=senders.find(x=>String(x.id)===String(source.value));
      const choices=possibleRelations(from?.perfil_tipo||from?.sujeto_tipo,targetType);
      type.innerHTML=choices.map(x=>`<option value="${esc(x)}">${esc(RELATION_LABEL[x]||x)}</option>`).join('');
      type.value='conexion_kombax';
    };
    source.addEventListener('change',fill);fill();return modal;
  }catch(error){setError(error);toast(humanError(error)||t('social.network.prepareFailed'),'error');return null;}
}
