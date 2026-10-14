/**
 * KOMBAX Fase 4. Navegación coherente para identidades directas.
 * Este módulo solo presenta rutas ya existentes. La autoridad continúa en Supabase.
 */
import { esc } from '../core/utils.js';
import { icon, featureIcon } from './icons.js';

const SECTIONS={
  competidor:[
    {title:'Actividad deportiva',icon:'fighter',items:['preparation','fight_opportunities','my_licenses','discovery_availability','sport_profile','fight_cards']},
    {title:'Oportunidades y equipo',icon:'users',items:['representation_requests','brand_opportunities','conversations','profile_team']}
  ],
  federacion:[
    {title:'Gestión federativa',icon:'federation',items:['federation_admin','federates','licenses','affiliated_clubs','federation_team']},
    {title:'Administración y planificación',icon:'clipboard',items:['operational_planning','organization_finance','payments','assist_management','migration_guide','plans_services']},
    {title:'Comunicación y relaciones',icon:'network',items:['conversations','communications','documents','profile_team']}
  ],
  profesional:[
    {title:'Actividad profesional',icon:'professional',items:['professional_operations','professional_finance','discovery_availability','schedule','services']},
    {title:'Licencias y oportunidades',icon:'idCard',items:['my_licenses','authorized_licenses','brand_opportunities','representation_requests','conversations','profile_team']},
    {title:'Producción de eventos',icon:'calendar',items:['operational_planning','organizer_events','payments']}
  ],
  marca:[
    {title:'Negocio y catálogo',icon:'brandMark',items:['brand_business','brand_campaigns','brand_collaborations','brand_sponsorships','brand_analytics','brand_team']},
    {title:'Gestión de la marca',icon:'wallet',items:['operational_planning','organization_finance','payments','assist_management','migration_guide','plans_services','profile_team']},
    {title:'Relaciones',icon:'message',items:['conversations']}
  ],
  media:[
    {title:'Actividad del creador',icon:'image',items:['content_center','seller_center','profile_team']},
    {title:'Comunidad',icon:'network',items:['conversations','saved']}
  ],
  espectador:[
    {title:'Mi actividad',icon:'user',items:['saved','event_interests','notifications']}
  ]
};

const DEFAULT_ICONS={
  public_profile:'user',conversations:'message',organization_finance:'wallet',operational_planning:'clipboard',
  seller_center:'shoppingBag',professional_operations:'professional',professional_finance:'wallet',
  representation_requests:'users',federation_admin:'federation',federates:'users',licenses:'idCard',
  federation_team:'users',my_licenses:'idCard',account_licenses:'idCard',authorized_licenses:'shieldCheck',
  affiliated_clubs:'dojo',payments:'wallet',plans_services:'layers',assist_management:'sparkles',
  migration_guide:'folder',discovery_availability:'mapPin',preparation:'fighter',fight_opportunities:'fighter',
  brand_business:'brandMark',brand_campaigns:'megaphone',brand_collaborations:'network',
  brand_sponsorships:'heart',brand_analytics:'chart',brand_team:'users',brand_opportunities:'network',
  content_center:'image',profile_team:'users',saved:'heart',event_interests:'calendar',
  notifications:'bell',privacy_support:'shield',resources:'sparkles',sport_profile:'fighter',fight_cards:'fighter'
};

export const managedIdentityNavigationTypes=Object.freeze(Object.keys(SECTIONS));

/** Pure data model. No privileges are granted, inferred or persisted here. */
export function managedNavigationModel({profile={},modules=[],allowed=()=>true,actionable=new Set(),canManageTeam=false,canOpen=()=>true}={}){
  const type=String(profile?.tipo||'').toLowerCase();
  const eligible=new Set((Array.isArray(modules)?modules:[]).filter(m=>typeof m==='string'&&m.length));
  eligible.add('privacy_support');
  if(canManageTeam)eligible.add('profile_team');
  const items=[],used=new Set();
  const add=(m)=>{
    if(!eligible.has(m)||used.has(m))return null;
    used.add(m);
    const permitted=allowed(m);
    const ready=(actionable.has(m)||m==='profile_team'||m==='privacy_support')&&canOpen(m);
    const result={id:m,available:!!permitted&&!!ready,reason:!permitted?'Según capacidades':!ready?'Vista previa':''};
    items.push(result);return result;
  };
  const sections=[];
  for(const section of SECTIONS[type]||[]){
    const available=section.items.map(add).filter(Boolean);
    if(available.length)sections.push({...section,items:available});
  }
  const remaining=[...eligible].filter(m=>!used.has(m)&&!['public_profile','social','events','showcase'].includes(m)&&!(m==='seller_center'&&eligible.has('showcase'))&&!(m==='organizer_events'&&eligible.has('events')));
  const other=remaining.map(add).filter(Boolean);
  if(other.length)sections.push({title:'Otras herramientas',icon:'layers',items:other});
  return {type,sections,items};
}

export function managedNavigationHtml({profile={},modules=[],allowed=()=>true,actionable=new Set(),canManageTeam=false,canOpen=()=>true,labels={},meta={},resourceLabel='Recursos',resourceSubtitle='Guías'}={}){
  const source=new Set((Array.isArray(modules)?modules:[]).filter(Boolean));
  const model=managedNavigationModel({profile,modules,allowed,actionable,canManageTeam,canOpen});
  const label=m=>m==='profile_team'?'Equipo y permisos':m==='privacy_support'?'Privacidad y soporte':labels[m]||m;
  const button=(item)=>{
    const m=item.id;
    const isAvailable=item.available;
    return `<button class="nav-item nav-club-item kx-profile-module-link kx-premium-nav-link ${isAvailable?'':'kx-premium-nav-preview'}" type="button" data-module="${esc(m)}"${isAvailable?'':` aria-description="${esc(item.reason)}"`}><span aria-hidden="true">${icon(DEFAULT_ICONS[m]||'layers',{size:18})}</span><span class="kx-premium-nav-link-copy"><b>${esc(label(m))}</b>${isAvailable?'':`<small>${esc(item.reason)}</small>`}</span></button>`;
  };
  const privateModules=(ids)=>ids.filter(m=>source.has(m)).map(m=>({id:m,available:allowed(m)&&actionable.has(m)&&canOpen(m),reason:allowed(m)?'Vista previa':'Según capacidades'}));
  const product=(m,accent,symbol,children=[])=>source.has(m)?`<details class="club-nav-accordion product-nav-accordion ${accent}"><summary><span class="club-nav-icon">${icon(symbol,{size:20})}</span><span class="club-nav-copy"><b>${esc(label(m))}</b></span><span class="club-nav-chevron">${icon('chevronRight',{size:17})}</span></summary><div class="club-nav-panel product-nav-panel">${[{id:m,available:allowed(m)&&canOpen(m),reason:allowed(m)?'Vista previa':'Según capacidades'},...privateModules(children)].map(button).join('')}</div></details>`:'';
  const summary=(section,index)=>`<details class="club-nav-accordion kx-premium-nav-group ${index===0?'kx-profile-identity-accordion':''}" ${index===0?'open':''}><summary><span class="club-nav-icon">${icon(section.icon,{size:19})}</span><span class="club-nav-copy"><b>${esc(section.title)}</b><small>${esc(section.items.length)} herramientas</small></span><span class="club-nav-chevron">${icon('chevronRight',{size:17})}</span></summary><div class="club-nav-panel kx-premium-nav-panel">${section.items.map(button).join('')}</div></details>`;
  return `<div class="kx-profile-context-nav kx-premium-profile-nav" data-nav-type="${esc(model.type)}" role="group" aria-label="Navegación de ${esc(meta.title||'mi identidad')}">
    <div class="kx-premium-nav-caption"><span>${esc(meta.eyebrow||'MI ESPACIO')}</span><strong>${esc(meta.title||'Mi perfil')}</strong><small>${esc(profile.nombre_publico||meta.title||'')}</small></div>
    <button class="nav-item nav-primary kx-premium-nav-home" type="button" data-module="overview">${icon('home',{size:20})}<b>Inicio · Mi espacio</b></button>
    ${source.has('public_profile')?button({id:'public_profile',available:allowed('public_profile')&&canOpen('public_profile'),reason:'Vista previa'}):''}
    ${model.sections.map(summary).join('')}
    ${source.has('social')?`<button type="button" class="nav-item nav-primary kx-profile-product-social" data-module="social"><span>${icon('network',{size:20})}</span><b>KOMBAX Social</b></button>`:''}
    ${product('events','events-product-nav','arena',['organizer_events'])}
    ${product('showcase','showcase-product-nav','spotlight',['seller_center'])}
    <details class="kx-sidebar-resources"><summary><span class="kx-resources-icon">${icon('sparkles',{size:20})}</span><span class="kx-resources-label"><b>${esc(resourceLabel)}</b><small>${esc(resourceSubtitle)}</small></span><span class="kx-resources-chevron">${icon('chevronRight',{size:17})}</span></summary><div class="kx-sidebar-resources-panel"><button type="button" data-kx-profile-resource>${esc(resourceLabel)}</button></div></details>
    <button class="nav-item kx-premium-nav-explore" type="button" data-module="explore">${icon('compass',{size:20})}<b>Explorar KOMBAX</b></button>
  </div>`;
}
