import { esc, humanError } from '../core/utils.js';
import { pageHeader, setMainHtml, setError, toast } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { t } from '../i18n/index.js';

const INDEX_URL='./assets/guides/runtime-index.json?v=20169';
const HERO_URL='./assets/brand-heroes/hero-guides.webp';
let cache=null;
async function loadIndex(){if(cache)return cache;const r=await fetch(INDEX_URL,{cache:'no-cache'});if(!r.ok)throw new Error(`GUIDES_INDEX_${r.status}`);cache=await r.json();return cache;}
const kindLabel=k=>k==='finance'?'Guía de Finanzas':k==='public'?t('prepilot.publicGuide'):k==='territorial'?t('prepilot.territorialGuides'):k==='base'?t('prepilot.baseGuides'):t('prepilot.detailedTerritorial');
const resolvedPdf=(value)=>new URL(String(value||''),document.baseURI).href;
const pdfAssetPath=(value)=>{try{const u=new URL(String(value||''),document.baseURI);const marker='/assets/guides/';const i=u.pathname.indexOf(marker);return i>=0?decodeURIComponent(u.pathname.slice(i+1)):'';}catch{return '';}};
function nativePdf(action,value){const path=pdfAssetPath(value);if(!path||!window.UrbanWarriorsNative)return false;const fn=action==='save'?window.UrbanWarriorsNative.saveBundledPdf:window.UrbanWarriorsNative.openBundledPdf;if(typeof fn!=='function')return false;try{fn.call(window.UrbanWarriorsNative,path);return true;}catch{return false;}}
async function openPdf(value){if(nativePdf('open',value))return;const url=resolvedPdf(value);const win=window.open(url,'_blank','noopener,noreferrer');if(!win){const a=document.createElement('a');a.href=url;a.target='_blank';a.rel='noopener noreferrer';document.body.appendChild(a);a.click();a.remove();}}
async function downloadPdf(value,title='KOMBAX_Guia.pdf'){
  if(nativePdf('save',value))return;
  try{const response=await fetch(resolvedPdf(value),{cache:'no-store'});if(!response.ok)throw new Error(`PDF_${response.status}`);const blob=await response.blob();const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=(String(title||'KOMBAX_Guia').replace(/[^\p{L}\p{N}._-]+/gu,'_').replace(/_+/g,'_').slice(0,120)||'KOMBAX_Guia')+(String(title).toLowerCase().endsWith('.pdf')?'':'.pdf');document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1500);}catch(error){const a=document.createElement('a');a.href=resolvedPdf(value);a.download=(String(title||'KOMBAX_Guia').replace(/[^\p{L}\p{N}._-]+/gu,'_').slice(0,120)||'KOMBAX_Guia')+'.pdf';document.body.appendChild(a);a.click();a.remove();toast(t('prepilot.pdfFallback'),'error');}
}
function card(x,i){return `<article class="kx-guide-card" data-kind="${esc(x.kind)}" data-search="${esc([x.title,x.subtitle,x.scope,x.territory,...(x.consult_triggers||[])].join(' ').toLowerCase())}"><header><span>${esc(kindLabel(x.kind))}</span>${x.case_specific?`<b>${esc(t('prepilot.caseSpecific'))}</b>`:''}</header><h3>${esc(x.title)}</h3>${x.subtitle?`<p>${esc(x.subtitle)}</p>`:''}<small>${esc(x.scope||'')}</small><div class="row-actions"><button class="btn btn-primary btn-sm" type="button" data-guide-open="${i}">${icon('arrowUpRight',{size:14})}${esc(t('prepilot.openPdf'))}</button><button class="btn btn-ghost btn-sm" type="button" data-guide-download="${i}">${icon('download',{size:14})}${esc(t('prepilot.downloadPdf'))}</button></div></article>`;}
export async function renderGuides(){
  setMainHtml(`<div class="loading-card">${esc(t('common.states.loading'))}</div>`);
  try{
    const data=await loadIndex();
    const entries=[...(data.finance_guide?[data.finance_guide]:[]),...(data.entries||[])].filter(x=>x.active!==false);
    const territories=[...new Set(entries.map(x=>x.territory).filter(Boolean))].sort((a,b)=>a.localeCompare(b));
    const manual=data.manual_product||null;
    const masterActions=data.show_master!==false&&data.master_pdf?`<div class="kx-resource-hero-actions"><button class="btn btn-primary" type="button" id="kx-guides-master-open">${esc(t('prepilot.openPdf'))}</button><button class="btn btn-ghost" type="button" id="kx-guides-master-download">${esc(t('prepilot.downloadPdf'))}</button></div>`:'';
    const manualCard=manual?`<section class="kx-manual-product" aria-label="${esc(t('prepilot.manualClubTitle'))}"><div class="kx-manual-product-copy"><span>${esc(t('prepilot.manualProduct'))} · ${esc(manual.edition||'R100.1')}</span><h2>${esc(t('prepilot.manualClubTitle'))}</h2><p>${esc(t('prepilot.manualClubLead'))}</p><div class="kx-manual-product-meta"><b>${esc(t('prepilot.manualIncludedPremium'))}</b><strong>${esc(t('prepilot.manualIndividualPrice'))}</strong></div></div><div class="kx-manual-product-lock"><span>${icon('lock',{size:22})}</span><small>${esc(t('prepilot.manualPrivateNotice'))}</small><button class="btn btn-ghost" type="button" id="kx-manual-info">${esc(t('prepilot.manualComingSoon'))}</button></div></section>`:'';
    setMainHtml(`<section class="kx-resource-hero is-guides" style="--kx-resource-hero:url('${esc(HERO_URL)}')"><div class="kx-resource-hero-copy"><span>KOMBAX</span><h1>${esc(t('prepilot.guidesTitle'))}</h1><p>${esc(t('prepilot.guidesLead'))}</p>${masterActions}</div></section>${pageHeader(t('prepilot.guidesLibrary'),t('prepilot.guidesLibraryLead'))}${manualCard}<section class="kx-guides-toolbar"><input id="kx-guides-search" type="search" placeholder="${esc(t('prepilot.search'))}"><select id="kx-guides-territory"><option value="">${esc(t('prepilot.allTerritories'))}</option>${territories.map(x=>`<option value="${esc(x)}">${esc(x)}</option>`).join('')}</select></section><div id="kx-guides-grid" class="kx-guides-grid">${entries.map(card).join('')}</div>`);
    const apply=()=>{const q=String(document.getElementById('kx-guides-search')?.value||'').trim().toLowerCase(),territory=String(document.getElementById('kx-guides-territory')?.value||'');document.querySelectorAll('.kx-guide-card').forEach(el=>{const match=(!q||el.dataset.search.includes(q))&&(!territory||el.dataset.search.includes(territory.toLowerCase()));el.hidden=!match;});};
    document.getElementById('kx-guides-search')?.addEventListener('input',apply);document.getElementById('kx-guides-territory')?.addEventListener('change',apply);
    document.getElementById('kx-guides-master-open')?.addEventListener('click',()=>openPdf(data.master_pdf));
    document.getElementById('kx-guides-master-download')?.addEventListener('click',()=>downloadPdf(data.master_pdf,'KOMBAX_Guias_Territoriales_Dossier.pdf'));
    document.getElementById('kx-manual-info')?.addEventListener('click',()=>toast(t('prepilot.manualPrivateNotice')));
    document.querySelectorAll('[data-guide-open]').forEach(b=>b.addEventListener('click',()=>{const x=entries[Number(b.dataset.guideOpen)];if(x)openPdf(x.pdf);}));
    document.querySelectorAll('[data-guide-download]').forEach(b=>b.addEventListener('click',()=>{const x=entries[Number(b.dataset.guideDownload)];if(x)downloadPdf(x.pdf,x.title);}));
  }catch(error){setError(error);setMainHtml(`${pageHeader(t('prepilot.guidesTitle'))}<div class="empty-card"><strong>${esc(t('errors.genericTitle'))}</strong><p>${esc(humanError(error)||'GUIDES_INDEX_ERROR')}</p></div>`);}
}
