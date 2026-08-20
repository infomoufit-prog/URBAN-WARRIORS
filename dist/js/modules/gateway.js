import { backend, client } from '../core/backend.js';
import { DEMO_CLUBS } from '../core/demo-directory.js';
import { KOMBAX_BRAND, platformFeatures, publicPlatformIntroduction, themeDefinition } from '../core/platform.js';
import { esc } from '../core/utils.js';
import { setAppHtml, openDetail, openForm, closeModal, setError, toast, confirmDialog } from '../ui/components.js';
import { icon, featureIcon } from '../ui/icons.js';
import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { renderKombaxSocial } from './kombax-social.js';
import { renderShowcase } from './showcase.js';
import { openPasswordRecovery } from './auth-recovery.js';
import { openAuthenticatedPasswordChange } from './account-security.js';
import { openKombaxPublicProfile } from './public-profile.js';
// Compatibilidad de regresión histórica 20023–20026: «Crear o acceder a un perfil KOMBAX» · «ALTA + VERIFICACIÓN» · «Crear perfil» · «Espectador continúa cerrado».

const directTypes=[
  {id:'club',label:'Club',icon:'club',accent:'#E21D2D',description:'Club oficial KOMBAX: gestión privada, comunidad, perfil público y afiliaciones confirmadas.',applicationOnly:true,benefits:['Perfil oficial','Gestión del club','Afiliaciones confirmadas']},
  {id:'competidor',label:'Competidor',icon:'fighter',accent:'#E21D2D',description:'Perfil oficial para peleadores y competidores. Permite solicitar verificación KOMBAX, conservar la continuidad con Miembro y desarrollar una identidad deportiva propia.',benefits:['Insignia KOMBAX','Perfil deportivo avanzado','Trayectoria y oportunidades']},
  {id:'marca',label:'Marca',icon:'brand',accent:'#FF3B4D',description:'Identidad corporativa verificada con Showcase, publicaciones y capacidades comerciales futuras.',benefits:['Marca oficial','Showcase','Analítica y oportunidades']},
  {id:'federacion',label:'Federación',icon:'federation',accent:'#F7F7F5',description:'Identidad institucional verificada para clubes, calendario, documentos y resultados oficiales futuros.',benefits:['Perfil institucional','Directorio de clubes','Calendario y documentos']},
  {id:'profesional',label:'Profesional / Representante',icon:'professional',accent:'#8F111B',description:'Perfil reservado para una fase posterior. No recibe insignia KOMBAX en 20.044.',disabled:true},
  {id:'espectador',label:'Espectador',icon:'spectator',accent:'#A7ABB4',description:'Identidad de observación reservada. Continúa cerrada hasta certificar edad, privacidad y alcance.',disabled:true}
];

const TYPE_LABEL=Object.fromEntries(directTypes.map(x=>[x.id,x.label]));
const WORKFLOW_LABEL={
  draft:'Borrador',submitted:'Enviada',under_review:'En revisión',needs_information:'Falta información',
  verified:'Verificado',limited:'Limitado',suspended:'Suspendido',rejected:'Rechazado',withdrawn:'Retirada'
};
const workflowTone=stateValue=>stateValue==='verified'?'ok':stateValue==='rejected'||stateValue==='suspended'?'danger':stateValue==='needs_information'||stateValue==='limited'?'warn':'neutral';


const mark=({compact=false}={})=>`<div class="gateway-brand ${compact?'compact':''}"><span class="gateway-brand-symbol"><img src="${esc(KOMBAX_BRAND.symbolWhite||KOMBAX_BRAND.symbol)}" alt=""></span><div><strong>${esc(KOMBAX_BRAND.name)}</strong><small>${esc(KOMBAX_BRAND.tagline)}</small></div></div>`;

export function renderKombaxGateway({onClubDirectory,onDirectProfiles}){
  setAppHtml(`<main class="kombax-gateway gateway-premium" data-kombax-view="gateway">
    <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
    <section class="gateway-hero premium-surface gateway-brand-stage">
      <div class="gateway-brand-watermark" aria-hidden="true">
        <span class="gateway-brand-watermark-symbol"><img src="${esc(KOMBAX_BRAND.symbolRed||KOMBAX_BRAND.symbolWhite||KOMBAX_BRAND.symbol)}" alt=""></span>
        <span class="gateway-brand-watermark-word">${esc(KOMBAX_BRAND.name)}</span>
        <span class="gateway-brand-watermark-tagline">${esc(KOMBAX_BRAND.tagline)}</span>
      </div>
      <header class="gateway-topline">${mark()}</header>
      <div class="gateway-intro">
        <span class="gateway-eyebrow">KOMBAX · DEPORTES DE CONTACTO</span>
        <h1>LA PLATAFORMA PROFESIONAL DE LOS DEPORTES DE CONTACTO</h1>
        <p>${esc(publicPlatformIntroduction())}</p>
        <p class="gateway-intro-secondary">Una identidad global para entrar en tu club, competir, conectar y crecer dentro de un ecosistema diseñado para el deporte real.</p>
      </div>
      <div class="gateway-paths" role="group" aria-label="Accesos KOMBAX">
        <button class="gateway-path primary" id="gateway-club" type="button">
          <span class="gateway-path-icon">${featureIcon('club',{size:68})}</span>
          <span class="gateway-path-copy"><em>ACCESO DE CLUB</em><strong>Entrar con mi club</strong><small>Busca tu club y abre su entorno privado de gestión.</small></span>
          <span class="gateway-path-arrow">${icon('arrowUpRight',{size:22})}</span>
        </button>
        <button class="gateway-path" id="gateway-direct" type="button">
          <span class="gateway-path-icon">${featureIcon('identity',{size:68})}</span>
          <span class="gateway-path-copy"><em>IDENTIDAD GLOBAL</em><strong>Solicitar o gestionar un perfil KOMBAX</strong><small>Club, Competidor, Marca o Federación con verificación separada del autorregistro.</small></span>
          <span class="gateway-path-arrow">${icon('arrowUpRight',{size:22})}</span>
        </button>
      </div>
      <footer class="gateway-footer" aria-label="CONNECT · COMPETE · GROW"><span>CONNECT</span><i></i><span>COMPETE</span><i></i><span>GROW</span><b>Built for combat sports</b></footer>
    </section>
  </main>`);
  document.getElementById('gateway-club')?.addEventListener('click',onClubDirectory);
  document.getElementById('gateway-direct')?.addEventListener('click',onDirectProfiles);
}

async function searchClubs(query=''){
  let remote=[];
  try{const rows=await client.rpc('app_buscar_clubes_kombax_v040',{p_query:query,p_limit:40});if(Array.isArray(rows))remote=rows;}catch(error){if(!/404|schema cache|could not find|app_buscar_clubes_kombax_v040/i.test(String(error?.message||'')))throw error;}
  const local=platformFeatures().demoDirectory?DEMO_CLUBS:DEMO_CLUBS.filter(x=>!x.demo);
  const term=String(query||'').trim().toLowerCase();
  const filtered=local.filter(c=>!term||[c.nombre,c.slug,c.ciudad,c.provincia,...(c.disciplinas||[])].some(x=>String(x||'').toLowerCase().includes(term)));
  const bySlug=new Map(filtered.map(c=>[c.slug,c]));for(const row of remote)bySlug.set(row.slug,{...bySlug.get(row.slug),...row,demo:false});
  return [...bySlug.values()].sort((a,b)=>Number(a.demo)-Number(b.demo)||String(a.nombre).localeCompare(String(b.nombre),'es'));
}

function demoDetail(club){
  const {wrap}=openDetail({title:club.nombre,subtitle:'Club de ejemplo',body:`<div class="demo-club-detail ${esc(themeDefinition(club.theme_id).className)}"><span>CLUB DE EJEMPLO</span><h3>${esc(club.lema||'')}</h3><p>${esc([club.ciudad,club.provincia].filter(Boolean).join(', '))}</p><div>${(club.disciplinas||[]).map(x=>`<b>${esc(x)}</b>`).join('')}</div><small>Este club es ilustrativo y no admite inicio de sesión.</small></div>`,actions:'<button class="btn btn-primary" id="close-demo-club">Entendido</button>'});
  wrap.querySelector('#close-demo-club')?.addEventListener('click',closeModal);
}

export async function renderClubDirectory({onBack,onSelect}){
  setAppHtml(`<main class="kombax-gateway directory-mode gateway-premium" data-kombax-view="directory">
    <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
    <section class="gateway-directory premium-surface">
      <div class="gateway-directory-top"><button class="gateway-icon-button" id="directory-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span class="gateway-directory-step">CLUB ACCESS / 01</span></div>
      <header><span class="gateway-eyebrow">ENTRAR CON MI CLUB</span><h1>Encuentra tu club</h1><p>Busca por nombre, ubicación o disciplina. Cada club conserva su identidad, sus datos y sus permisos.</p></header>
      <div class="directory-search">
        <label class="directory-search-field"><span>${icon('search',{size:20})}</span><input id="club-search" type="search" autocomplete="off" placeholder="Nombre, ubicación o disciplina" aria-label="Buscar club"></label>
        <button class="btn btn-primary" id="club-search-button" type="button">${icon('search',{size:17})} Buscar</button>
        <button class="btn btn-ghost" id="club-link-button" type="button">${icon('qr',{size:17})} Abrir enlace / QR</button>
      </div>
      <div class="directory-meta"><span><b class="live-dot"></b> Directorio KOMBAX</span><span>Selecciona un club para continuar</span></div>
      <div id="club-directory-results" class="club-directory-results"><div class="gateway-skeleton"><i></i><i></i><i></i></div></div>
      
    </section>
  </main>`);
  document.getElementById('directory-back')?.addEventListener('click',onBack);
  const input=document.getElementById('club-search'),box=document.getElementById('club-directory-results');
  const load=async()=>{box.innerHTML='<div class="gateway-skeleton"><i></i><i></i><i></i></div>';try{const clubs=await searchClubs(input.value);box.innerHTML=clubs.length?clubs.map(c=>`<button class="club-directory-card ${esc(themeDefinition(c.theme_id).className)} ${c.demo?'is-demo':'is-real'}" type="button" data-slug="${esc(c.slug)}"><span class="club-directory-logo">${c.logo_url?`<img src="${esc(c.logo_url)}" alt="">`:esc(String(c.nombre||'K').slice(0,2).toUpperCase())}</span><span class="club-directory-copy"><span class="club-card-heading"><strong>${esc(c.nombre)}</strong>${c.demo?'<b>EJEMPLO</b>':'<b class="real-club">DISPONIBLE</b>'}</span><small>${esc([c.ciudad,c.provincia].filter(Boolean).join(' · ')||c.lema||'')}</small><em>${esc((c.disciplinas||[]).join(' · '))}</em></span><span class="club-directory-arrow">${icon('chevronRight',{size:20})}</span></button>`).join(''):'<div class="empty premium-empty"><strong>Sin resultados</strong><p>Prueba otro nombre, ubicación o disciplina.</p></div>';box.querySelectorAll('[data-slug]').forEach(button=>button.addEventListener('click',()=>{const club=clubs.find(c=>c.slug===button.dataset.slug);if(club?.demo)demoDetail(club);else if(club)onSelect(club);}));}catch(error){box.innerHTML='<div class="empty premium-empty"><strong>No se pudo consultar el directorio</strong><p>Comprueba la conexión e inténtalo de nuevo.</p><button class="btn btn-ghost btn-sm" id="directory-retry" type="button">Reintentar</button></div>';document.getElementById('directory-retry')?.addEventListener('click',load);setError(error);}};
  document.getElementById('club-search-button')?.addEventListener('click',load);input.addEventListener('keydown',e=>{if(e.key==='Enter')load();});
  document.getElementById('club-link-button')?.addEventListener('click',()=>openForm({title:'Abrir enlace o QR de club',subtitle:'Pega el enlace codificado en el QR o escribe el identificador del club.',fields:[{name:'value',label:'Enlace o identificador',required:true}],submitText:'Localizar club',onSubmit:async v=>{let slug=String(v.value||'').trim().toLowerCase();try{const url=new URL(slug,location.href);slug=url.searchParams.get('club')||url.pathname.split('/').filter(Boolean).pop()||slug;}catch{}slug=slug.replace(/[^a-z0-9-]/g,'');const clubs=await searchClubs(slug),club=clubs.find(c=>c.slug===slug);if(!club)throw new Error('No se encontró un club con ese enlace o identificador.');if(club.demo){closeModal();demoDetail(club);}else onSelect(club);}}));
  await load();
}

function globalAuthenticated(){return state.session?.scope==='kombax'&&Boolean(state.session?.id);}

function openGlobalAuth({onBack,pendingType='',mode='login'}={}){
  if(mode==='register'){
    openForm({
      title:'Crear cuenta KOMBAX',subtitle:'La cuenta global no te da una insignia ni crea un club automáticamente. La verificación es un proceso separado.',
      width:'720px',
      fields:[
        {name:'nombre',label:'Nombre',required:true},{name:'apellidos',label:'Apellidos',required:true},
        {name:'email',label:'Email',type:'email',required:true},{name:'password',label:'Contraseña',type:'password',required:true,help:'Mínimo 6 caracteres.'},
        {name:'age',label:'Confirmo que tengo al menos 16 años para crear esta cuenta',type:'checkbox',value:false,required:true,full:true}
      ],
      submitText:'Crear cuenta',
      onSubmit:async v=>{
        if(!v.age)throw new Error('Debes confirmar la edad mínima para crear una cuenta autónoma.');
        if(String(v.password||'').length<6)throw new Error('La contraseña debe tener al menos 6 caracteres.');
        const result=await backend.registerGlobalAccount(v);
        if(result.confirmationRequired){
          sessionStorage.setItem('kombax_pending_profile_type',pendingType||'');
          toast('Cuenta creada. Confirma el email y después accede a KOMBAX.');
          renderDirectProfiles({onBack});
          return;
        }
        toast('Cuenta KOMBAX creada');
        await renderDirectProfileHub({onBack,pendingType});
      }
    });
    return;
  }
  const authModal=openForm({
    title:'Acceder a KOMBAX',subtitle:'Acceso a tu identidad global. No cambia ni mezcla los datos privados de tus clubes.',
    fields:[
      {name:'email',label:'Email',type:'email',required:true},
      {name:'password',label:'Contraseña',type:'password',required:true}
    ],
    submitText:'Entrar',
    onSubmit:async v=>{await backend.signInGlobal(v.email,v.password);toast('Sesión KOMBAX iniciada');await renderDirectProfileHub({onBack,pendingType:pendingType||sessionStorage.getItem('kombax_pending_profile_type')||''});}
  });
  const recover=document.createElement('button');recover.type='button';recover.className='btn btn-ghost';recover.textContent='He olvidado mi contraseña';
  recover.addEventListener('click',()=>openPasswordRecovery({prefillEmail:authModal.form.elements.email?.value||'',onComplete:()=>openGlobalAuth({onBack,pendingType,mode:'login'})}));
  authModal.form.querySelector('.modal-actions')?.prepend(recover);
}

function authChoice({onBack,pendingType=''}) {
  const type=TYPE_LABEL[pendingType]||'perfil KOMBAX';
  const {wrap}=openDetail({
    title:`Continuar como ${type}`,
    subtitle:'Necesitas una cuenta KOMBAX para guardar una solicitud o un perfil.',
    width:'620px',
    body:'<div class="gateway-auth-explain"><strong>Una cuenta no equivale a un perfil verificado.</strong><p>KOMBAX separa autenticación, solicitud, revisión e insignia. Ningún autorregistro puede concederse permisos sensibles.</p></div>',
    actions:'<button class="btn btn-primary" id="kx-auth-login">Ya tengo cuenta</button><button class="btn btn-ghost" id="kx-auth-register">Crear cuenta KOMBAX</button>'
  });
  wrap.querySelector('#kx-auth-login')?.addEventListener('click',()=>openGlobalAuth({onBack,pendingType,mode:'login'}));
  wrap.querySelector('#kx-auth-register')?.addEventListener('click',()=>openGlobalAuth({onBack,pendingType,mode:'register'}));
}

function profileFields(type,profile={},memberProfiles=[]){
  const fields=[
    {name:'nombre_publico',label:type==='marca'?'Nombre oficial':type==='federacion'?'Nombre institucional':'Nombre público',required:true,full:true,value:profile.nombre_publico||''},
    {name:'descripcion',label:'Presentación pública',type:'textarea',rows:5,maxLength:1600,full:true,value:profile.descripcion||'',help:'No incluyas teléfono, email, domicilio, fecha de nacimiento ni documentación privada.'},
    {name:'ubicacion',label:'Ubicación pública',value:profile.ubicacion||''},
    {name:'disciplinas',label:'Disciplinas',value:(profile.disciplinas||[]).join(', '),help:'Separadas por comas; máximo 12.'},
    {name:'categoria',label:type==='competidor'?'Categoría / nivel':'Especialidad / categoría',value:profile.categoria||''},
    {name:'club_declarado',label:type==='competidor'?'Club deportivo declarado':'Entidad o vínculo principal',value:profile.club_declarado||''},
    {name:'web_publica',label:'Web pública HTTPS',type:'url',full:true,value:profile.web_publica||''}
  ];
  if(type==='competidor')fields.splice(2,0,{name:'miembro_social_id',label:'Continuidad con mi perfil de Miembro',type:'select',value:memberProfiles.find(x=>String(x.identidad_social_id||'')===String(profile.origen_identidad_social_id||''))?.id||'',options:[{value:'',label:'Competidor independiente'},...memberProfiles.map(x=>({value:x.id,label:`Convertir ${x.nombre_publico} en Competidor (conserva Social)`}))],full:true,help:'Si eliges tu identidad de Miembro, KOMBAX conservará el mismo perfil Social, publicaciones y Relaciones al activar Competidor.'});
  return fields;
}

function applicationFields(type,profile=null,application=null){
  const data=application?.datos_publicos||{};
  const verify=application?.datos_verificacion||{};
  const fields=[{name:'nombre_publico',label:type==='club'?'Nombre del club':`Nombre público de ${TYPE_LABEL[type]||type}`,required:true,full:true,value:application?.nombre_publico||profile?.nombre_publico||''}];
  if(type==='competidor')fields.push(
    {name:'ubicacion',label:'Ubicación pública',value:data.ubicacion||profile?.ubicacion||''},
    {name:'disciplinas',label:'Disciplina(s)',required:true,value:Array.isArray(data.disciplinas)?data.disciplinas.join(', '):(profile?.disciplinas||[]).join(', ')},
    {name:'categoria',label:'Categoría / nivel',value:data.categoria||profile?.categoria||''},
    {name:'club_declarado',label:'Club',value:data.club_declarado||profile?.club_declarado||''},
    {name:'nombre_legal',label:'Nombre legal · privado',required:true,value:verify.nombre_legal||''},
    {name:'fecha_nacimiento',label:'Fecha de nacimiento · privada',type:'date',value:verify.fecha_nacimiento||'',help:profile?.origen_identidad_social_id?'Si vienes de un Club, prevalece la edad verificada por el Club.':'Alta autónoma de Competidor: 16+.'},
    {name:'email',label:'Email de verificación · privado',type:'email',required:true,value:verify.email||''}
  );
  if(type==='marca')fields.push(
    {name:'categoria',label:'Categoría comercial',required:true,value:data.categoria||profile?.categoria||''},
    {name:'web_publica',label:'Web corporativa HTTPS',type:'url',required:true,value:data.web_publica||profile?.web_publica||''},
    {name:'razon_social',label:'Razón social · privada',required:true,value:verify.razon_social||''},
    {name:'tax_id',label:'CIF / VAT · privado',value:verify.tax_id||''},
    {name:'email_corporativo',label:'Email corporativo · privado',type:'email',required:true,value:verify.email_corporativo||''},
    {name:'responsable',label:'Responsable autorizado',required:true,value:verify.responsable||''},
    {name:'rol_responsable',label:'Cargo',required:true,value:verify.rol_responsable||''}
  );
  if(type==='federacion')fields.push(
    {name:'pais',label:'País',required:true,value:data.pais||''},{name:'territorio',label:'Territorio / ámbito',required:true,value:data.territorio||profile?.ubicacion||''},
    {name:'disciplinas',label:'Disciplina(s)',required:true,value:Array.isArray(data.disciplinas)?data.disciplinas.join(', '):(profile?.disciplinas||[]).join(', ')},
    {name:'web_publica',label:'Web institucional HTTPS',type:'url',required:true,value:data.web_publica||profile?.web_publica||''},
    {name:'nombre_legal',label:'Nombre legal de la entidad · privado',required:true,value:verify.nombre_legal||''},
    {name:'email_oficial',label:'Email oficial · privado',type:'email',required:true,value:verify.email_oficial||''},
    {name:'registro_entidad',label:'Registro / número oficial · privado',required:true,value:verify.registro_entidad||''},
    {name:'responsable',label:'Representante autorizado',required:true,value:verify.responsable||''},{name:'rol_responsable',label:'Cargo',required:true,value:verify.rol_responsable||''}
  );
  if(type==='club')fields.push(
    {name:'lema',label:'Lema público',value:data.lema||''},{name:'descripcion',label:'Presentación pública',type:'textarea',rows:4,maxLength:1600,full:true,value:data.descripcion||'',help:'Será la presentación inicial del perfil público del Club.'},
    {name:'ubicacion',label:'Ubicación pública',required:true,value:data.ubicacion||''},{name:'ciudad',label:'Ciudad',value:data.ciudad||''},{name:'provincia',label:'Provincia / región',value:data.provincia||''},{name:'pais',label:'País',required:true,value:data.pais||'España'},
    {name:'disciplinas',label:'Disciplina(s)',required:true,value:Array.isArray(data.disciplinas)?data.disciplinas.join(', '):String(data.disciplinas||''),help:'Separadas por comas; máximo 12.'},
    {name:'web_publica',label:'Web HTTPS',type:'url',value:data.web_publica||''},{name:'instagram',label:'Instagram público',value:data.instagram||''},{name:'tiktok',label:'TikTok público',value:data.tiktok||''},{name:'youtube',label:'YouTube público',value:data.youtube||''},
    {name:'forma_entidad',label:'Tipo de club / entidad · privado',type:'select',value:verify.forma_entidad||'club_deportivo',options:[{value:'club_deportivo',label:'Club deportivo'},{value:'asociacion',label:'Asociación'},{value:'autonomo',label:'Profesional / autónomo'},{value:'gimnasio',label:'Gimnasio / centro deportivo'},{value:'escuela',label:'Escuela deportiva'},{value:'otro',label:'Otro'}]},
    {name:'nombre_legal',label:'Nombre legal · privado',required:true,value:verify.nombre_legal||''},{name:'cif',label:'CIF / identificación fiscal · privado',value:verify.cif||verify.tax_id||'',help:'Opcional en la verificación inicial. No todos los clubes operan con la misma forma jurídica.'},
    {name:'email_oficial',label:'Email oficial · privado',type:'email',required:true,value:verify.email_oficial||''},{name:'telefono',label:'Teléfono oficial · privado',required:true,value:verify.telefono||''},{name:'direccion',label:'Dirección administrativa o zona de actividad · privada',value:verify.direccion||'',full:true,help:'Puede ser la dirección del centro o una referencia de zona. La ubicación pública ya identifica la población.'},
    {name:'responsable',label:'Responsable del club',required:true,value:verify.responsable||''},{name:'rol_responsable',label:'Cargo / relación con el club',required:true,value:verify.rol_responsable||''}
  );
  if(type==='club')fields.push({name:'tipo_acreditacion',label:'Tipo de acreditación',type:'select',required:true,value:'Documento del club / centro',options:[{value:'Licencia / acreditación federativa',label:'Licencia / acreditación federativa'},{value:'Registro de club o asociación',label:'Registro de club o asociación'},{value:'Documento fiscal o legal',label:'Documento fiscal o legal'},{value:'Documento del club / centro',label:'Documento del club / centro'},{value:'Otro documento acreditativo',label:'Otro documento acreditativo'}],full:true});
  fields.push(
    {name:'evidencia',label:type==='club'?'Cómo podemos comprobar que el club existe y que puedes representarlo':'Cómo podemos verificar esta identidad',type:'textarea',rows:4,maxLength:1200,required:true,full:true,value:verify.evidencia||'',help:type==='club'?'Indica web, red social oficial, federación, registro, centro deportivo u otra referencia contrastable. Estos datos son privados.':'Describe fuentes verificables. KOMBAX no publica estos datos.'},
    {name:'documento',label:type==='club'?'Documento acreditativo privado':'Documento acreditativo',type:'file',accept:'.pdf,image/jpeg,image/png,image/webp',full:true,help:type==='club'?'Adjunta una acreditación razonable del club o de la representación. No es obligatorio que sea documentación empresarial compleja. PDF/JPG/PNG/WEBP, máximo 15 MB.':'Es obligatorio disponer de al menos un documento antes del envío. PDF/JPG/PNG/WEBP, máximo 15 MB; almacenamiento privado.'},
    {name:'declaration',label:'Declaro que la información es correcta y que estoy autorizado para representar esta identidad',type:'checkbox',value:application?.declaracion_aceptada===true,required:true,full:true}
  );
  return fields;
}

async function saveAndSubmitApplication(type,{profile=null,application=null,onBack}={}){
  openForm({
    title:application?.estado==='needs_information'?'Completar solicitud':`Solicitar perfil ${TYPE_LABEL[type]||type}`,
    subtitle:'La solicitud se estudia antes de conceder la identidad oficial. Pagar nunca concede la insignia automáticamente.',
    width:'900px',fields:applicationFields(type,profile,application),submitText:'Guardar y enviar',
    onSubmit:async v=>{
      if(!v.declaration)throw new Error('Debes confirmar la declaración de identidad y representación.');
      const list=String(v.disciplinas||'').split(',').map(x=>x.trim()).filter(Boolean).slice(0,12);
      const datos_publicos={ubicacion:v.ubicacion||'',ciudad:v.ciudad||'',provincia:v.provincia||'',disciplinas:list,categoria:v.categoria||'',club_declarado:v.club_declarado||'',territorio:v.territorio||'',pais:v.pais||'',web_publica:v.web_publica||'',lema:v.lema||'',descripcion:v.descripcion||'',instagram:v.instagram||'',tiktok:v.tiktok||'',youtube:v.youtube||''};
      const datos_verificacion={responsable:v.responsable||'',rol_responsable:v.rol_responsable||'',evidencia:v.evidencia||'',forma_entidad:v.forma_entidad||'',nombre_legal:v.nombre_legal||'',fecha_nacimiento:v.fecha_nacimiento||'',email:v.email||'',razon_social:v.razon_social||'',tax_id:v.tax_id||'',cif:v.cif||'',email_corporativo:v.email_corporativo||'',email_oficial:v.email_oficial||'',telefono:v.telefono||'',direccion:v.direccion||'',registro_entidad:v.registro_entidad||''};
      const saved=await repos.kombaxProfiles.saveApplication({solicitud_id:application?.id||null,tipo:type,perfil_directo_id:profile?.id||null,nombre_publico:v.nombre_publico,datos_publicos,datos_verificacion,declaracion_aceptada:true});
      const row=saved?.data||saved;const id=row?.id||application?.id;if(!id)throw new Error('No se pudo verificar el identificador de la solicitud guardada.');
      if(v.documento)await repos.kombaxProfiles.uploadVerificationDocument(id,type==='club'?(v.tipo_acreditacion||'Documento acreditativo'):'acreditacion',v.documento);
      await repos.kombaxProfiles.submitApplication(id);toast('Solicitud enviada a revisión KOMBAX');await renderDirectProfileHub({onBack});
    }
  });
}

function profileEditor(type,{profile=null,onBack,memberProfiles=[]}={}){
  openForm({
    title:profile?'Editar perfil KOMBAX':`Preparar solicitud ${TYPE_LABEL[type]||type}`,
    subtitle:type==='competidor'?'Puedes evolucionar tu Miembro actual sin perder publicaciones ni Relaciones. La insignia exige revisión y activación del servicio.':'Primero preparas la identidad. La verificación y el servicio se activan por separado.',
    width:'840px',initial:profile||{},fields:profileFields(type,profile||{},memberProfiles),submitText:'Guardar borrador',
    onSubmit:async v=>{
      const disciplinas=String(v.disciplinas||'').split(',').map(x=>x.trim()).filter(Boolean).slice(0,12);
      const result=await repos.kombaxProfiles.saveProfile({perfil_directo_id:profile?.id||null,tipo,nombre_publico:v.nombre_publico,descripcion:v.descripcion||'',ubicacion:v.ubicacion||'',disciplinas,categoria:v.categoria||'',club_declarado:v.club_declarado||'',web_publica:v.web_publica||'',miembro_social_id:v.miembro_social_id||null});
      toast(profile?'Perfil actualizado':'Borrador de solicitud creado');const saved=result?.data||result;if(!profile&&saved?.id)sessionStorage.setItem('kombax_new_profile_id',saved.id);
      await renderDirectProfileHub({onBack});
    }
  });
}

async function openAlbum(profile,{onBack}={}){
  const rows=await repos.kombaxProfiles.album(profile.id);
  const photos=rows.filter(x=>x.tipo==='photo'&&x.estado!=='removed');
  const videos=rows.filter(x=>x.tipo==='video'&&x.estado!=='removed');
  const avatar=rows.find(x=>x.tipo==='avatar'&&x.estado!=='removed');
  const banner=rows.find(x=>x.tipo==='banner'&&x.estado!=='removed');
  const mediaUrl=m=>m?backend.publicUrl('kombax-public-media',m.storage_path):'';
  const tile=m=>`<article class="kx-album-tile">${m.tipo==='video'?`<video src="${esc(mediaUrl(m))}" preload="metadata" controls></video>`:`<img src="${esc(mediaUrl(m))}" alt="">`}<footer><span>${esc(m.tipo)}</span><button class="btn btn-ghost btn-sm" data-kx-media-remove="${esc(m.id)}">Retirar</button></footer></article>`;
  const {wrap}=openDetail({
    title:`Álbum · ${profile.nombre_publico}`,
    subtitle:`${photos.length}/10 fotos · ${videos.length}/3 vídeos · vídeo máximo 15 s`,
    width:'980px',
    body:`<div class="kx-album-hero">${avatar?`<img class="kx-avatar-preview" src="${esc(mediaUrl(avatar))}" alt="">`:'<span class="kx-avatar-preview placeholder">KX</span>'}${banner?`<img class="kx-banner-preview" src="${esc(mediaUrl(banner))}" alt="">`:'<div class="kx-banner-preview placeholder">BANNER</div>'}</div><div class="row-actions kx-album-actions"><button class="btn btn-primary btn-sm" data-kx-upload="photo">+ Foto</button><button class="btn btn-ghost btn-sm" data-kx-upload="video">+ Vídeo</button><button class="btn btn-ghost btn-sm" data-kx-upload="avatar">Avatar</button><button class="btn btn-ghost btn-sm" data-kx-upload="banner">Banner</button></div><div class="kx-album-grid">${[...photos,...videos].map(tile).join('')||'<div class="empty"><strong>Álbum vacío</strong><p>Las fotos y vídeos públicos aparecerán aquí.</p></div>'}</div>`,
    actions:'<button class="btn btn-ghost" id="kx-album-close">Cerrar</button>'
  });
  wrap.querySelector('#kx-album-close')?.addEventListener('click',closeModal);
  wrap.querySelectorAll('[data-kx-upload]').forEach(button=>button.addEventListener('click',()=>{
    const type=button.dataset.kxUpload;
    openForm({
      title:`Subir ${type==='photo'?'foto':type==='video'?'vídeo':type}`,
      subtitle:type==='video'?'El vídeo se valida antes de guardar: máximo 15 segundos.':'Las imágenes se optimizan antes de almacenarse.',
      fields:[{name:'file',label:'Archivo',type:'file',required:true,accept:type==='video'?'video/mp4,video/webm,video/quicktime':'image/jpeg,image/png,image/webp',full:true}],
      submitText:'Subir',
      onSubmit:async v=>{await repos.kombaxProfiles.uploadMedia(profile.id,type,v.file);toast('Multimedia guardada');closeModal();await openAlbum(profile,{onBack});}
    });
  }));
  wrap.querySelectorAll('[data-kx-media-remove]').forEach(button=>button.addEventListener('click',()=>{
    const media=rows.find(x=>x.id===button.dataset.kxMediaRemove);if(!media)return;
    confirmDialog('Eliminar multimedia','Dejará de mostrarse en el perfil. El registro mantiene trazabilidad.',async()=>{await repos.kombaxProfiles.removeMedia(media);toast('Multimedia eliminada');closeModal();await openAlbum(profile,{onBack});},{confirmText:'Eliminar',danger:true});
  }));
}

function applicationCard(app,profile,onBack){
  const stateLabel=WORKFLOW_LABEL[app.estado]||app.estado;
  return `<article class="kx-application-card"><header><div><span>VERIFICACIÓN</span><strong>${esc(TYPE_LABEL[app.tipo]||app.tipo)}</strong></div><b class="kx-state ${esc(workflowTone(app.estado))}">${esc(stateLabel)}</b></header><p>${esc(app.nombre_publico)}</p>${app.motivo_revision?`<div class="kx-review-note">${esc(app.motivo_revision)}</div>`:''}<footer>${['draft','needs_information'].includes(app.estado)?`<button class="btn btn-primary btn-sm" data-kx-application-edit="${esc(app.id)}">Completar / enviar</button>`:''}${['submitted','under_review','needs_information'].includes(app.estado)?`<button class="btn btn-ghost btn-sm" data-kx-application-withdraw="${esc(app.id)}">Retirar</button>`:''}</footer></article>`;
}

async function openGlobalDeletionCenter(){
  try{
    const rows=await repos.accountDeletion.list().catch(()=>[]);const open=rows.filter(x=>['requested','in_review','needs_information','confirmed'].includes(x.estado));
    const modal=openDetail({title:'Eliminar cuenta KOMBAX',subtitle:'Solicitud trazable de datos y cuenta',width:'720px',body:`<div class="kx-deletion-center"><div class="alert alert-warning"><strong>No se borra trazabilidad legal de forma indiscriminada</strong><span>La solicitud afecta a tu cuenta y datos eliminables. Los registros sujetos a obligaciones legales se conservan únicamente durante el periodo aplicable.</span></div>${open.length?`<div class="kx-deletion-list">${open.map(r=>`<article><strong>${esc(r.alcance==='account'?'Cuenta personal':r.alcance)}</strong><span>${esc(r.estado)}</span>${['requested','needs_information'].includes(r.estado)?`<button class="btn btn-ghost btn-sm" data-kx-delete-cancel="${esc(r.id)}">Cancelar</button>`:''}</article>`).join('')}</div>`:'<p class="muted">No hay solicitudes abiertas.</p>'}<p><a href="./delete-account.html" target="_blank" rel="noopener noreferrer">Ver recurso público de eliminación</a></p></div>`,actions:'<button class="btn btn-danger" id="kx-delete-request">Solicitar eliminación de mi cuenta</button>'});
    modal.wrap.querySelector('#kx-delete-request')?.addEventListener('click',()=>openForm({title:'Solicitar eliminación',subtitle:'Puedes indicar un motivo opcional.',fields:[{name:'motivo',label:'Motivo',type:'textarea',rows:4,full:true,maxLength:1200}],submitText:'Enviar solicitud',onSubmit:async v=>{await repos.accountDeletion.request({alcance:'account',motivo:v.motivo||''});toast('Solicitud registrada');closeModal();setTimeout(openGlobalDeletionCenter,180);}}));
    modal.wrap.querySelectorAll('[data-kx-delete-cancel]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Cancelar solicitud','La solicitud dejará de tramitarse.',async()=>{await repos.accountDeletion.cancel(b.dataset.kxDeleteCancel);toast('Solicitud cancelada');closeModal();setTimeout(openGlobalDeletionCenter,180);},{confirmText:'Cancelar solicitud'})));
  }catch(error){setError(error);}
}

async function openGlobalArea(renderer,{onBack,title}){
  setAppHtml(`<div class="kx-global-module-shell"><header class="kx-global-module-top"><button class="gateway-icon-button" id="kx-global-area-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span>${esc(title)}</span></header><main id="main-view" class="main-view"><div class="loading-card">Abriendo ${esc(title)}…</div></main></div>`);
  document.getElementById('kx-global-area-back')?.addEventListener('click',()=>renderDirectProfileHub({onBack}));
  try{await renderer();}catch(error){setError(error);}
}

export async function renderDirectProfileHub({onBack,pendingType=''}={}){
  if(!globalAuthenticated()){renderDirectProfiles({onBack});return;}
  setAppHtml(`<main class="kombax-gateway direct-mode gateway-premium" data-kombax-view="profile-hub"><div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div><section class="gateway-directory premium-surface"><div class="gateway-directory-top"><button class="gateway-icon-button" id="kx-hub-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span class="gateway-directory-step">KOMBAX ID / CUENTA</span></div><div class="kx-hub-loading"><strong>Cargando identidad KOMBAX…</strong></div></section></main>`);
  document.getElementById('kx-hub-back')?.addEventListener('click',onBack);
  try{
    const [profiles,applications,socialProfiles,managedClubs]=await Promise.all([repos.kombaxProfiles.mine(),repos.kombaxProfiles.applications(),repos.kombaxSocial.myProfiles().catch(()=>[]),repos.kombaxProfiles.clubs().catch(()=>[])]);
    const memberProfiles=(socialProfiles||[]).filter(x=>x.sujeto_tipo==='miembro');
    const profileById=new Map(profiles.map(x=>[x.id,x]));
    const clubById=new Map((managedClubs||[]).map(x=>[x.club_id,x]));
    const identityCount=profiles.length+(managedClubs||[]).length;
    setAppHtml(`<main class="kombax-gateway direct-mode gateway-premium" data-kombax-view="profile-hub">
      <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
      <section class="gateway-directory premium-surface">
        <div class="gateway-directory-top"><button class="gateway-icon-button" id="kx-hub-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span class="gateway-directory-step">KOMBAX ID / CUENTA</span></div>
        <header class="kx-hub-header"><div><span class="gateway-eyebrow">IDENTIDAD GLOBAL</span><h1>${esc(state.session?.nombre||'Mi KOMBAX')}</h1><p>Gestiona perfiles, solicitudes y multimedia sin mezclar los datos administrativos de tus clubes.</p></div><div class="kx-account-actions"><span>${esc(state.session?.email||'')}</span><button class="btn btn-ghost btn-sm" id="kx-global-change-password">Cambiar contraseña</button><button class="btn btn-ghost btn-sm" id="kx-global-logout">Cerrar sesión</button></div></header>
        <div class="kx-hub-actions"><button class="btn btn-primary" id="kx-new-profile">+ Solicitar perfil</button><button class="btn btn-ghost" id="kx-open-social">KOMBAX Social</button><button class="btn btn-ghost" id="kx-open-showcase">Showcase</button><button class="btn btn-ghost" id="kx-account-privacy">Privacidad y eliminación</button></div>
        <section class="kx-hub-section"><div class="kx-section-title"><div><span>PERFILES</span><h2>Mis identidades</h2></div><small>${identityCount} identidad${identityCount===1?'':'es'}</small></div>
          ${identityCount?`<div class="kx-profile-owned-grid">${(managedClubs||[]).map(c=>`<article class="kx-profile-owned kx-club-identity"><header><div class="direct-profile-icon">${featureIcon('club',{size:44})}</div><div><span>CLUB</span><strong>${esc(c.nombre_publico)}</strong><small>${esc([c.ciudad,c.provincia,c.pais].filter(Boolean).join(' · ')||'Perfil oficial de club')}</small></div><b class="kx-state ${c.activo?'ok':'warn'}">${c.activo?'Activo':'Inactivo'}</b></header><p>${esc(c.descripcion||c.lema||'Completa el perfil público de tu Club desde su entorno de gestión.')}</p><div class="kx-profile-tags">${(c.disciplinas||[]).slice(0,4).map(x=>`<span>${esc(x)}</span>`).join('')}<span>Club KOMBAX</span></div><footer><button class="btn btn-primary btn-sm" data-kx-club-enter="${esc(c.club_id)}">Gestionar club</button>${c.social_profile_id?`<button class="btn btn-ghost btn-sm" data-kx-club-public="${esc(c.club_id)}">Ver perfil público</button>`:''}<button class="btn btn-ghost btn-sm" data-kx-club-security="${esc(c.club_id)}">Seguridad y acceso</button></footer></article>`).join('')}${profiles.map(p=>`<article class="kx-profile-owned"><header><div class="direct-profile-icon">${featureIcon(directTypes.find(x=>x.id===p.tipo)?.icon||'identity',{size:44})}</div><div><span>${esc(TYPE_LABEL[p.tipo]||p.tipo)}</span><strong>${esc(p.nombre_publico)}</strong><small>${esc(p.ubicacion||'Sin ubicación pública')}</small></div><b class="kx-state ${esc(workflowTone(p.workflow_estado))}">${esc(WORKFLOW_LABEL[p.workflow_estado]||p.workflow_estado)}</b></header><p>${esc(p.descripcion||'Completa la presentación pública de este perfil.')}</p><div class="kx-profile-tags">${(p.disciplinas||[]).slice(0,4).map(x=>`<span>${esc(x)}</span>`).join('')}<span>${esc(p.verificacion_estado==='verificado'?(p.servicio_estado==='activa'||p.servicio_estado==='prueba'?'Insignia activa':'Verificado · pendiente de servicio'):'Sin insignia')}</span></div><footer><button class="btn btn-ghost btn-sm" data-kx-profile-edit="${esc(p.id)}">Editar</button><button class="btn btn-ghost btn-sm" data-kx-profile-security="${esc(p.id)}">Seguridad y acceso</button>${['activa','prueba'].includes(p.servicio_estado)?`<button class="btn btn-ghost btn-sm" data-kx-profile-album="${esc(p.id)}">Álbum</button>`:''}${!applications.some(a=>a.perfil_directo_id===p.id&&['submitted','under_review','verified'].includes(a.estado))?`<button class="btn btn-primary btn-sm" data-kx-profile-verify="${esc(p.id)}">Solicitar verificación</button>`:''}</footer></article>`).join('')}</div>`:'<div class="premium-empty"><strong>Aún no tienes identidades KOMBAX</strong><p>Solicita una identidad oficial como Club, Competidor, Marca o Federación. Club crea un entorno real de gestión después de la verificación del Administrador KOMBAX. Competidor puede partir de tu identidad Miembro o crearse como perfil independiente y siempre requiere revisión antes de obtener insignia. Miembro conserva su ficha Social pública enriquecida.</p></div>'}
        </section>
        <section class="kx-hub-section"><div class="kx-section-title"><div><span>REVISIÓN</span><h2>Solicitudes</h2></div><small>${applications.length} solicitud${applications.length===1?'':'es'}</small></div>${applications.length?`<div class="kx-application-grid">${applications.map(a=>applicationCard(a,profileById.get(a.perfil_directo_id),onBack)).join('')}</div>`:'<div class="premium-empty compact"><strong>Sin solicitudes</strong><p>Las verificaciones enviadas aparecerán aquí con su estado.</p></div>'}</section>
        <div class="gateway-safety-note"><span class="gateway-safety-icon">${icon('shieldCheck',{size:22})}</span><div><strong>Verificación separada del autorregistro</strong><p>Crear una cuenta o un perfil nunca concede una insignia, un club ni permisos sensibles. La revisión es explícita y trazable.</p></div></div>
      </section>
    </main>`);
    document.getElementById('kx-hub-back')?.addEventListener('click',onBack);
    document.getElementById('kx-global-change-password')?.addEventListener('click',()=>openAuthenticatedPasswordChange({onComplete:()=>renderDirectProfiles({onBack})}));
    document.getElementById('kx-global-logout')?.addEventListener('click',async()=>{await backend.signOut();toast('Sesión cerrada');renderDirectProfiles({onBack});});
    document.getElementById('kx-new-profile')?.addEventListener('click',()=>chooseProfileType({onBack,memberProfiles}));
    document.getElementById('kx-open-social')?.addEventListener('click',()=>openGlobalArea(renderKombaxSocial,{onBack,title:'KOMBAX Social'}));
    document.getElementById('kx-open-showcase')?.addEventListener('click',()=>openGlobalArea(renderShowcase,{onBack,title:'KOMBAX Showcase'}));
    document.getElementById('kx-account-privacy')?.addEventListener('click',openGlobalDeletionCenter);
    document.querySelectorAll('[data-kx-profile-edit]').forEach(b=>{const p=profileById.get(b.dataset.kxProfileEdit);b.addEventListener('click',()=>profileEditor(p.tipo,{profile:p,onBack,memberProfiles}));});
    document.querySelectorAll('[data-kx-profile-security]').forEach(b=>b.addEventListener('click',()=>openAuthenticatedPasswordChange({onComplete:()=>renderDirectProfiles({onBack})})));
    document.querySelectorAll('[data-kx-club-enter]').forEach(b=>b.addEventListener('click',async()=>{const c=clubById.get(b.dataset.kxClubEnter);if(!c)return;try{await backend.switchClub(c.slug);toast(`Entrando en ${c.nombre_publico}`);window.location.reload();}catch(error){setError(error);}}));
    document.querySelectorAll('[data-kx-club-public]').forEach(b=>b.addEventListener('click',()=>{const c=clubById.get(b.dataset.kxClubPublic);if(c?.social_profile_id)openKombaxPublicProfile(c.social_profile_id);}));
    document.querySelectorAll('[data-kx-club-security]').forEach(b=>b.addEventListener('click',()=>openAuthenticatedPasswordChange({onComplete:()=>renderDirectProfiles({onBack})})));
    document.querySelectorAll('[data-kx-profile-verify]').forEach(b=>{const p=profileById.get(b.dataset.kxProfileVerify);b.addEventListener('click',()=>saveAndSubmitApplication(p.tipo,{profile:p,onBack}));});
    document.querySelectorAll('[data-kx-profile-album]').forEach(b=>{const p=profileById.get(b.dataset.kxProfileAlbum);b.addEventListener('click',()=>openAlbum(p,{onBack}).catch(setError));});
    document.querySelectorAll('[data-kx-application-edit]').forEach(b=>{const a=applications.find(x=>x.id===b.dataset.kxApplicationEdit),p=profileById.get(a?.perfil_directo_id);b.addEventListener('click',()=>saveAndSubmitApplication(a.tipo,{profile:p,application:a,onBack}));});
    document.querySelectorAll('[data-kx-application-withdraw]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Retirar solicitud','La solicitud dejará de revisarse. El historial no se falsifica ni se elimina.',async()=>{await repos.kombaxProfiles.withdrawApplication(b.dataset.kxApplicationWithdraw);toast('Solicitud retirada');await renderDirectProfileHub({onBack});},{confirmText:'Eliminar',danger:true})));
    if(pendingType&&directTypes.some(t=>t.id===pendingType&&!t.disabled)&&['competidor','marca','federacion'].includes(pendingType))profileEditor(pendingType,{onBack,memberProfiles});
    else if(pendingType==='club'&&!applications.some(a=>a.tipo==='club'&&['submitted','under_review','needs_information'].includes(a.estado)))saveAndSubmitApplication('club',{onBack});
    sessionStorage.removeItem('kombax_pending_profile_type');
  }catch(error){setError(error);renderDirectProfiles({onBack});}
}

function chooseProfileType({onBack,memberProfiles=[]}={}){
  const available=directTypes.filter(x=>!x.disabled);
  const {wrap}=openDetail({title:'Solicitar perfil oficial KOMBAX',subtitle:'Puedes solicitar Club, Competidor, Marca o Federación. La insignia y las capacidades verificadas solo se activan después de la revisión KOMBAX.',width:'820px',body:`<div class="kx-type-picker">${available.map(t=>`<button type="button" data-kx-pick="${esc(t.id)}"><span>${featureIcon(t.icon,{size:42})}</span><strong>${esc(t.label)}</strong><small>${esc(t.description)}</small><em>${(t.benefits||[]).map(x=>`✓ ${esc(x)}`).join(' · ')}</em></button>`).join('')}</div>`});
  wrap.querySelectorAll('[data-kx-pick]').forEach(b=>b.addEventListener('click',()=>b.dataset.kxPick==='club'?saveAndSubmitApplication('club',{onBack}):profileEditor(b.dataset.kxPick,{onBack,memberProfiles})));
}

export function renderDirectProfiles({onBack}){
  if(globalAuthenticated()){renderDirectProfileHub({onBack});return;}
  setAppHtml(`<main class="kombax-gateway direct-mode gateway-premium" data-kombax-view="profiles">
    <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
    <section class="gateway-directory premium-surface">
      <div class="gateway-directory-top"><button class="gateway-icon-button" id="direct-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span class="gateway-directory-step">KOMBAX ID / 02</span></div>
      <header><span class="gateway-eyebrow">IDENTIDAD KOMBAX</span><h1>Elige el tipo de perfil</h1><p>Cuenta, perfil, verificación y capacidades son capas separadas. Están disponibles Club, Competidor, Marca y Federación. Profesional / Representante y Espectador permanecen reservados temporalmente.</p></header>
      <div class="direct-profile-grid">${directTypes.map(t=>`<button class="direct-profile-card ${t.disabled?'is-disabled':''}" type="button" style="--profile-accent:${t.accent}" data-profile-type="${esc(t.id)}" ${t.disabled?'disabled':''}><div class="direct-profile-icon">${featureIcon(t.icon,{size:58})}</div><div class="direct-profile-copy"><span>${esc(t.disabled?'RESERVADO':t.applicationOnly?'SOLICITUD DE CLUB':'SOLICITUD + REVISIÓN')}</span><h2>${esc(t.label)}</h2><p>${esc(t.description)}</p></div><footer><b>${t.disabled?`${icon('lock',{size:13})} PENDIENTE`:`${icon('shieldCheck',{size:13})} SOLICITAR`}</b><span>${icon('chevronRight',{size:18})}</span></footer></button>`).join('')}</div>
      <div class="gateway-safety-note"><span class="gateway-safety-icon">${icon('shieldCheck',{size:22})}</span><div><strong>Sin verificación automática</strong><p>Una cuenta registrada no equivale a perfil verificado. La solicitud de Club tampoco activa el espacio automáticamente. Profesional / Representante y Espectador siguen desactivados durante esta fase. Competidor ya admite solicitud y verificación KOMBAX.</p></div></div>
      <div class="kx-direct-auth-row"><button class="btn btn-ghost" id="kx-existing-account">Ya tengo cuenta KOMBAX</button></div>
    </section>
  </main>`);
  document.getElementById('direct-back')?.addEventListener('click',onBack);
  document.querySelectorAll('[data-profile-type]:not(:disabled)').forEach(card=>card.addEventListener('click',()=>authChoice({onBack,pendingType:card.dataset.profileType})));
  document.getElementById('kx-existing-account')?.addEventListener('click',()=>openGlobalAuth({onBack,mode:'login'}));
}
