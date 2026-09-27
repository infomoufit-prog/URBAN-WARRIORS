import { esc, humanError } from '../core/utils.js';
import { setMainHtml, setAppHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { renderConsulting } from './consulting.js';
import { t, getLocale } from '../i18n/index.js';

const COLLECTIONS_URL='./assets/guides/resource-collections.json?v=20150';
const USAGE_URL='./assets/guides/usage-guides.json?v=20150';
const SECTIONS=['usage','knowledge','territories','consulting'];
let cached=null;

async function data(){
  if(cached)return cached;
  const [collections,usage]=await Promise.all([fetch(COLLECTIONS_URL,{cache:'no-cache'}),fetch(USAGE_URL,{cache:'no-cache'})]);
  if(!collections.ok||!usage.ok)throw new Error(t('prepilot.rcLibraryError'));
  cached={collections:await collections.json(),usage:await usage.json()};
  return cached;
}
const pdfUrl=value=>new URL(String(value||''),document.baseURI).href;
function nativePdf(action,value){
  try{
    const url=new URL(value,document.baseURI),marker='/assets/guides/',at=url.pathname.indexOf(marker);
    if(at<0||!window.UrbanWarriorsNative)return false;
    const name=decodeURIComponent(url.pathname.slice(at+1));
    const fn=action==='save'?window.UrbanWarriorsNative.saveBundledPdf:window.UrbanWarriorsNative.openBundledPdf;
    if(typeof fn!=='function')return false;
    fn.call(window.UrbanWarriorsNative,name);
    return true;
  }catch{return false;}
}
function openPdf(value){
  if(nativePdf('open',value))return;
  const a=document.createElement('a');a.href=pdfUrl(value);a.target='_blank';a.rel='noopener noreferrer';
  document.body.appendChild(a);a.click();a.remove();
}
async function downloadPdf(value,title){
  if(nativePdf('save',value))return;
  const response=await fetch(pdfUrl(value));if(!response.ok)throw new Error(t('prepilot.rcDownloadError'));
  const blob=await response.blob(),url=URL.createObjectURL(blob),a=document.createElement('a');
  a.href=url;a.download=(String(title||'KOMBAX_Guia').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-zA-Z0-9_-]+/g,'_').slice(0,90)||'KOMBAX_Guia')+'.pdf';
  document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),2000);
}
const actions=(pdf,title)=>'<div class="kx-resource-actions">'
  +'<button type="button" class="btn btn-primary btn-sm" data-kx-pdf-open="'+esc(pdf)+'">'+icon('arrowUpRight',{size:15})+esc(t('prepilot.rcReadPdf'))+'</button>'
  +'<button type="button" class="btn btn-ghost btn-sm" data-kx-pdf-download="'+esc(pdf)+'" data-kx-pdf-title="'+esc(title)+'">'+icon('download',{size:15})+esc(t('prepilot.rcDownload'))+'</button></div>';

function usageCards(guides){
  return guides.map(g=>'<article class="kx-center-card" data-kx-usage-card data-search="'+esc([g.title,g.audience,g.lead,...g.chapters.flatMap(x=>[x.title,x.purpose,...x.steps])].join(' ').toLowerCase())+'">'
    +'<span class="kx-center-card-type">'+esc(t('prepilot.rcUsageType'))+'</span><h3>'+esc(g.title)+'</h3><p>'+esc(g.lead)+'</p>'
    +'<small>'+esc(g.audience)+' · '+esc(t('prepilot.rcChapters',{count:g.chapters.length}))+'</small>'
    +'<div class="kx-resource-actions"><button type="button" class="btn btn-primary btn-sm" data-kx-usage-read="'+esc(g.id)+'">'+icon('fileText',{size:15})+esc(t('prepilot.rcReadHere'))+'</button>'
    +'<button type="button" class="btn btn-ghost btn-sm" data-kx-pdf-download="'+esc(g.pdf)+'" data-kx-pdf-title="'+esc(g.title)+'">'+icon('download',{size:15})+'PDF</button></div></article>').join('');
}
function usageReader(guide,intro){
  return '<div class="kx-usage-reader-head"><div><span>'+esc(t('prepilot.rcUsageType'))+'</span><h3>'+esc(guide.title)+'</h3><p>'+esc(guide.lead)+'</p></div>'
    +'<button type="button" class="btn btn-ghost btn-sm" id="kx-usage-close">'+esc(t('prepilot.rcCloseRead'))+'</button></div>'
    +'<p class="kx-usage-intro">'+esc(intro)+'</p>'
    +'<div class="kx-usage-chapters">'+guide.chapters.map((ch,i)=>'<details class="kx-usage-chapter" '+(i===0?'open':'')+'>'
      +'<summary><b>'+String(i+1).padStart(2,'0')+'</b><span>'+esc(ch.title)+'</span>'+icon('chevronRight',{size:17})+'</summary>'
      +'<div><p class="kx-usage-purpose">'+esc(ch.purpose||'')+'</p><ol>'+ch.steps.map(step=>'<li>'+esc(step)+'</li>').join('')+'</ol>'
      +'<div class="kx-usage-context"><article><strong>'+esc(t('prepilot.rcUsageExample'))+'</strong><p>'+esc(ch.example||'')+'</p></article><article><strong>'+esc(t('prepilot.rcUsageCheck'))+'</strong><p>'+esc(ch.check||'')+'</p></article></div>'
      +'<p class="kx-usage-note">'+esc(ch.note)+'</p></div></details>').join('')+'</div>';
}
function collectionCards(groups){
  return groups.map((g,i)=>'<article class="kx-center-card kx-collection-card"><span class="kx-center-card-type">'+esc(t('prepilot.rcKnowledgeType'))+' · '+String(i+1).padStart(2,'0')+'</span>'
    +'<h3>'+esc(g.title)+'</h3><p>'+esc(g.subtitle)+'</p><small>'+esc(t('prepilot.rcTopics',{count:g.chapters.length}))+' · '+esc(g.audience)+'</small>'
    +'<ul>'+g.chapters.map(ch=>'<li>'+esc(ch)+'</li>').join('')+'</ul>'+actions(g.pdf,g.title)+'</article>').join('');
}
function section(key,title,sub,content,open){
  return '<details class="kx-center-section" data-kx-section="'+key+'" '+(open?'open':'')+'>'
    +'<summary><span class="kx-center-section-icon">'+icon({usage:'fileText',knowledge:'folder',territories:'mapPin',consulting:'sparkles'}[key],{size:20})+'</span>'
    +'<span class="kx-center-section-copy"><strong>'+title+'</strong><small>'+sub+'</small></span>'
    +'<span class="kx-center-chevron">'+icon('chevronRight',{size:20})+'</span></summary>'
    +'<div class="kx-center-section-body">'+content+'</div></details>';
}
function frame(model,active){
  const {collections,usage}=model;
  const territories=[...collections.territories].sort((a,b)=>a.territory.localeCompare(b.territory,'es'));
  const languageNote=getLocale()==='es'?'':'<p class="kx-center-language-note">'+esc(t('prepilot.rcSpanishContentNotice'))+'</p>';
  return '<section class="kx-resource-center"><header class="kx-center-hero"><div><span>'+esc(t('prepilot.resources'))+'</span><h1>'+esc(t('prepilot.rcHeroTitle'))+'</h1>'
    +'<p>'+esc(t('prepilot.rcHeroLead'))+'</p></div>'
    +'<div class="kx-center-hero-mark" aria-hidden="true">'+icon('sparkles',{size:38})+'</div></header>'+languageNote
    +'<div class="kx-center-stack">'
    +section('usage',esc(t('prepilot.rcLearn')),esc(t('prepilot.rcGuideCount',{count:usage.guides.length})),
      '<div class="kx-center-intro">'+esc(t('prepilot.rcLearnLead'))+'</div>'
      +'<label class="kx-center-search-label">'+esc(t('prepilot.rcSearchUsage'))+'<input type="search" id="kx-usage-search" placeholder="'+esc(t('prepilot.rcSearchPlaceholder'))+'"></label>'
      +'<div class="kx-center-grid" id="kx-usage-grid">'+usageCards(usage.guides)+'</div><div class="kx-usage-reader" id="kx-usage-reader" hidden></div>',active==='usage')
    +section('knowledge',esc(t('prepilot.rcKnowledge')),esc(t('prepilot.rcKnowledgeCount')),
      '<div class="kx-center-intro">'+esc(collections.reader_help)+'</div><div class="kx-center-grid kx-center-knowledge-grid">'
      +collectionCards(collections.collections)+'</div><aside class="kx-center-manual"><span>'+esc(t('prepilot.rcManualPremium'))+'</span><div><strong>'+esc(t('prepilot.rcClubManualTitle'))+'</strong><p>'+esc(t('prepilot.rcClubManualLead'))+'</p></div>'+icon('lock',{size:22})+'</aside>',active==='knowledge')
    +section('territories',esc(t('prepilot.rcTerritories')),esc(t('prepilot.rcTerritoryCount')),
      '<div class="kx-center-intro">'+esc(t('prepilot.rcTerritoryInstruction'))+'</div>'
      +'<label class="kx-center-search-label">'+esc(t('prepilot.rcTerritoryLabel'))+'<select id="kx-territory-select"><option value="">'+esc(t('prepilot.rcSelectTerritory'))+'</option>'
      +territories.map((x,i)=>'<option value="'+i+'">'+esc(x.territory)+'</option>').join('')+'</select></label>'
      +'<div id="kx-territory-result" class="kx-territory-result"></div>',active==='territories')
    +section('consulting',esc(t('prepilot.consulting')),esc(t('prepilot.rcConsultSub')),
      '<div id="kx-center-consulting"><div class="loading-card">'+esc(t('prepilot.rcOpeningConsult'))+'</div></div>',active==='consulting')
    +'</div></section>';
}

export async function renderResourceCenter({section:requested='usage',standalone=false,onBack=null}={}){
  const active=SECTIONS.includes(requested)?requested:'usage';
  if(standalone)setAppHtml('<main class="kx-center-standalone"><button type="button" class="btn btn-ghost" id="kx-center-back">'+esc(t('prepilot.rcBack'))+'</button><div id="main-view" class="main-view"></div></main>');
  setMainHtml('<div class="loading-card">'+esc(t('prepilot.rcOpening'))+'</div>');
  try{
    const model=await data();
    setMainHtml(frame(model,active));
    document.getElementById('kx-center-back')?.addEventListener('click',()=>onBack?.());
    const sections=[...document.querySelectorAll('[data-kx-section]')];
    let consultLoaded=false;const consult=()=>{if(consultLoaded)return;consultLoaded=true;return renderConsulting({container:document.getElementById('kx-center-consulting')});};
    sections.forEach(el=>el.addEventListener('toggle',()=>{
      if(!el.open)return;
      sections.forEach(other=>{if(other!==el)other.open=false;});
      if(el.dataset.kxSection==='consulting')consult();
      document.querySelectorAll('[data-resource-target]').forEach(button=>button.classList.toggle('active',button.dataset.resourceTarget===el.dataset.kxSection));
      try{sessionStorage.setItem('kx_resource_section',el.dataset.kxSection)}catch{}
    }));
    if(active==='consulting')consult();
    document.querySelectorAll('[data-kx-pdf-open]').forEach(b=>b.addEventListener('click',()=>openPdf(b.dataset.kxPdfOpen)));
    document.querySelectorAll('[data-kx-pdf-download]').forEach(b=>b.addEventListener('click',()=>downloadPdf(b.dataset.kxPdfDownload,b.dataset.kxPdfTitle).catch(error=>{alert(humanError(error));})));
    const usageSearch=document.getElementById('kx-usage-search');
    usageSearch?.addEventListener('input',()=>{
      const query=usageSearch.value.trim().toLocaleLowerCase('es');
      document.querySelectorAll('[data-kx-usage-card]').forEach(card=>{card.hidden=Boolean(query)&&!card.dataset.search.includes(query);});
    });
    document.querySelectorAll('[data-kx-usage-read]').forEach(b=>b.addEventListener('click',()=>{
      const guide=model.usage.guides.find(x=>x.id===b.dataset.kxUsageRead),reader=document.getElementById('kx-usage-reader');
      if(!guide||!reader)return;
      reader.innerHTML=usageReader(guide,model.usage.intro);reader.hidden=false;
      reader.querySelector('#kx-usage-close')?.addEventListener('click',()=>{reader.hidden=true;reader.innerHTML='';});
      reader.scrollIntoView({behavior:'smooth',block:'start'});
    }));
    const choice=document.getElementById('kx-territory-select'),target=document.getElementById('kx-territory-result');
    const territories=[...model.collections.territories].sort((a,b)=>a.territory.localeCompare(b.territory,'es'));
    choice?.addEventListener('change',()=>{
      const entry=territories[Number(choice.value)];
      target.innerHTML=choice.value!==''&&entry?'<article class="kx-center-card"><span class="kx-center-card-type">'+esc(t('prepilot.rcTerritoryType'))+'</span><h3>'+esc(entry.territory)+'</h3>'
        +'<p>'+esc(t('prepilot.rcTerritoryCardLead'))+'</p>'+actions(entry.pdf,entry.title)+'</article>':'';
      target.querySelector('[data-kx-pdf-open]')?.addEventListener('click',b=>openPdf(b.currentTarget.dataset.kxPdfOpen));
      target.querySelector('[data-kx-pdf-download]')?.addEventListener('click',b=>downloadPdf(b.currentTarget.dataset.kxPdfDownload,b.currentTarget.dataset.kxPdfTitle).catch(error=>alert(humanError(error))));
    });
  }catch(error){
    setMainHtml('<div class="empty-card"><strong>'+esc(t('prepilot.rcOpenError'))+'</strong><p>'+esc(humanError(error))+'</p></div>');
  }
}
