import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, humanError } from '../core/utils.js';
import { pageHeader, setMainHtml, setError, empty } from '../ui/components.js';
import { t } from '../i18n/index.js';

function subject(){const s=state.session||{};if(s.federation_profile_id)return ['federation',s.federation_profile_id];if(s.club_id)return ['club',s.club_id];if(s.support_entity_type&&s.support_entity_id)return [s.support_entity_type,s.support_entity_id];return [null,null];}
export async function renderPrivateTraining(){
  setMainHtml(`<div class="loading-card">${esc(t('common.states.loading'))}</div>`);
  const [type,id]=subject();if(!type||!id){setMainHtml(`${pageHeader(t('prepilot.trainingTitle'),t('prepilot.trainingLead'))}${empty(t('prepilot.trainingDisabled'),t('prepilot.trainingDisabledBody'))}`);return;}
  try{const data=await repos.privateTraining.status(type,id);if(!data?.enabled){setMainHtml(`${pageHeader(t('prepilot.trainingTitle'),t('prepilot.trainingLead'))}<div class="alert alert-info"><strong>${esc(t('prepilot.trainingDisabled'))}</strong><span>${esc(t('prepilot.trainingDisabledBody'))}</span></div>`);return;}
    const programs=Array.isArray(data.programs)?data.programs:[];setMainHtml(`${pageHeader(t('prepilot.trainingTitle'),t('prepilot.trainingLead'))}<div class="kx-training-programs">${programs.length?programs.map(p=>`<article><span>${esc(p.status||'private')}</span><h3>${esc(p.title)}</h3><p>${esc(p.description||'')}</p><small>${Number(p.module_count||0)} · ${esc(t('prepilot.programs'))}</small></article>`).join(''):empty(t('prepilot.noPrograms'))}</div>`);
  }catch(error){setError(error);setMainHtml(`${pageHeader(t('prepilot.trainingTitle'))}${empty(t('errors.genericTitle'),humanError(error))}`);}
}
