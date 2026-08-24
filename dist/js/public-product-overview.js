import { featureIcon, icon } from './ui/icons.js';

const PRODUCT_PROFILES = [
  {
    id: 'club',
    icon: 'club',
    label: 'CLUBES',
    badge: 'GESTIÓN + PERFIL',
    title: 'Gestiona el club desde un único entorno.',
    description: 'El perfil público identifica al club dentro de KOMBAX. Desde su área privada gestiona la operativa diaria y mantiene conectada su actividad deportiva.',
    benefits: [
      'Socios, grupos, sesiones y asistencia.',
      'Cuotas, comunicaciones y eventos.',
      'Comunidad del Club y notificaciones.',
      'Perfil público, disciplinas y equipo técnico.'
    ],
    cta: 'Buscar mi club',
    target: 'gateway-club',
    featured: true
  },
  {
    id: 'federation',
    icon: 'federation',
    label: 'FEDERACIONES',
    badge: 'PERFIL INSTITUCIONAL',
    title: 'Una identidad institucional conectada con sus clubes.',
    description: 'El perfil de federación actúa como referencia dentro de KOMBAX y prepara una estructura común para relacionar clubes, actividad y competición.',
    benefits: [
      'Perfil institucional y proceso de verificación.',
      'Directorio y relación con clubes.',
      'Presencia y comunicación dentro del ecosistema.',
      'Calendario, documentos y resultados oficiales, en evolución.'
    ],
    cta: 'Perfil de federación',
    target: 'gateway-direct'
  },
  {
    id: 'competitor',
    icon: 'fighter',
    label: 'COMPETIDORES',
    badge: 'PERFIL DEPORTIVO',
    title: 'Un perfil pensado para competir.',
    description: 'El perfil de competidor reúne identidad deportiva, club, disciplinas y trayectoria. La verificación permite distinguir la información deportiva acreditada.',
    benefits: [
      'Club, disciplinas y datos deportivos.',
      'Trayectoria y participación en eventos.',
      'Verificación KOMBAX cuando corresponda.',
      'Base para resultados y oportunidades deportivas.'
    ],
    cta: 'Perfil de competidor',
    target: 'gateway-direct'
  },
  {
    id: 'brand',
    icon: 'brand',
    label: 'MARCAS',
    badge: 'PERFIL PROFESIONAL',
    title: 'Presencia profesional dentro del ecosistema deportivo.',
    description: 'El perfil de marca separa la identidad corporativa de una cuenta personal y permite presentar contenido y producto dentro de KOMBAX.',
    benefits: [
      'Perfil corporativo y proceso de verificación.',
      'Showcase para contenido y producto.',
      'Visibilidad ante clubes y deportistas.',
      'Colaboraciones y analítica comercial, en evolución.'
    ],
    cta: 'Perfil de marca',
    target: 'gateway-direct',
    wide: true
  }
];

const disciplines = ['Boxeo','Kickboxing','Muay Thai','MMA','Karate','Judo','Jiu-Jitsu','Taekwondo','Grappling','Lucha','Sambo'];

function card(profile) {
  return `<article class="kx-product-card ${profile.featured ? 'is-featured' : ''} ${profile.wide ? 'is-wide' : ''}" data-kx-profile="${profile.id}">
    <div class="kx-product-card-icon" aria-hidden="true">${featureIcon(profile.icon,{size:72})}</div>
    <div class="kx-product-card-body">
      <div class="kx-product-card-meta"><span>${profile.label}</span><b>${profile.badge}</b></div>
      <h3>${profile.title}</h3>
      <p>${profile.description}</p>
      <ul>${profile.benefits.map(item=>`<li>${icon('checkCircle',{size:17})}<span>${item}</span></li>`).join('')}</ul>
    </div>
    <button class="kx-product-card-action" type="button" data-kx-target="${profile.target}" aria-label="${profile.cta}">
      <span>${profile.cta}</span>${icon('arrowUpRight',{size:18})}
    </button>
  </article>`;
}

function overviewMarkup() {
  return `<section class="kx-product-overview" data-kx-product-overview aria-labelledby="kx-product-overview-title">
    <header class="kx-product-overview-head">
      <span>KOMBAX · PRODUCTO</span>
      <h2 id="kx-product-overview-title">Cada perfil tiene una función concreta.</h2>
      <p>Gestión, identidad y actividad deportiva para clubes, federaciones, competidores y marcas de <strong>deportes de contacto y artes marciales</strong>.</p>
    </header>
    <div class="kx-product-grid">${PRODUCT_PROFILES.map(card).join('')}</div>
    <footer class="kx-discipline-rail" aria-label="Disciplinas KOMBAX">
      <div><strong>DEPORTES DE CONTACTO + ARTES MARCIALES</strong><span>${disciplines.map(item=>`<b>${item}</b>`).join('<i></i>')}<i></i><b>y más</b></span></div>
    </footer>
  </section>`;
}

function bindOverview(section) {
  section.querySelectorAll('[data-kx-target]').forEach(button=>button.addEventListener('click',()=>{
    const target=document.getElementById(button.dataset.kxTarget);
    if(target){target.scrollIntoView({behavior:'smooth',block:'center'});setTimeout(()=>target.click(),180);}
  }));
}

function mountOverview() {
  const gateway=document.querySelector('[data-kombax-view="gateway"]');
  if(!gateway||gateway.querySelector('[data-kx-product-overview]'))return;
  const hero=gateway.querySelector('.gateway-hero');
  if(!hero)return;
  hero.insertAdjacentHTML('afterend',overviewMarkup());
  bindOverview(gateway.querySelector('[data-kx-product-overview]'));
}

const observer=new MutationObserver(mountOverview);
observer.observe(document.documentElement,{childList:true,subtree:true});
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mountOverview,{once:true});else mountOverview();
