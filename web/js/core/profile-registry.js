import { backend } from './backend.js';

export const PROFESSIONAL_SPECIALTIES=Object.freeze([
  {code:'entrenador',name:'Entrenador autónomo'},
  {code:'representante_manager',name:'Representante / Manager'},
  {code:'medico_sanitario',name:'Médico / Sanitario deportivo'},
  {code:'arbitro_juez',name:'Árbitro / Juez'},
  {code:'promotor_organizador',name:'Promotor / Organizador'}
]);

export const DIRECT_PROFILE_TYPES=Object.freeze([
  {id:'club',label:'Club',icon:'club',accent:'#E21D2D',description:'Gestiona tu club, tu equipo y tu comunidad desde un único espacio KOMBAX.',applicationOnly:true,benefits:['Perfil oficial','Gestión del club','Afiliaciones confirmadas']},
  {id:'competidor',label:'Competidor',icon:'fighter',accent:'#E21D2D',description:'Tu identidad como peleador: trayectoria, categoría, club y oportunidades para competir.',benefits:['Identidad deportiva','Fight Cards','Trayectoria y oportunidades']},
  {id:'federacion',label:'Federación',icon:'federation',accent:'#F7F7F5',description:'Representa a tu federación, conecta con clubes y organiza su actividad dentro de KOMBAX.',benefits:['Perfil institucional','Clubes relacionados','Calendario y Events']},
  {id:'profesional',label:'Profesional',icon:'professional',accent:'#8F111B',description:'Presenta tu experiencia y servicios como entrenador, manager, sanitario, árbitro o promotor.',benefits:['Mi actividad','Servicios y agenda','Capacidades por especialidad']},
  {id:'marca',label:'Marca',icon:'brand',accent:'#FF3B4D',description:'Da visibilidad a tu marca, productos y colaboraciones dentro del ecosistema KOMBAX.',benefits:['Marca oficial','Showcase','Equipo de gestores']},
  {id:'media',label:'Media / Creador',icon:'sparkles',accent:'#26D7C7',description:'Publica contenido y haz crecer tu presencia como medio o creador especializado.',benefits:['Publicar en Social','Publicar en Showcase','Identidad de medio o creador']},
  {id:'espectador',label:'Espectador',icon:'spectator',accent:'#A7ABB4',description:'Descubre KOMBAX, sigue la actividad del sector e interactúa con la comunidad.',baseOnly:true,benefits:['Ver Social, Showcase y Events','Likes, comentarios y compartir','Sin publicación propia hasta disponer de una identidad habilitada']}
]);

export const PROFILE_TYPE_LABEL=Object.freeze(Object.fromEntries(DIRECT_PROFILE_TYPES.map(x=>[x.id,x.label])));

let taxonomyCache=null;
export async function loadProfileTaxonomy({refresh=false}={}){
  if(taxonomyCache&&!refresh)return taxonomyCache;
  try{
    const data=await backend.publicRpc('app_kombax_profile_taxonomy_v196',{});
    taxonomyCache=data&&typeof data==='object'?data:null;
  }catch{taxonomyCache=null;}
  return taxonomyCache||{
    profile_types:DIRECT_PROFILE_TYPES.filter(x=>x.id!=='club').map(x=>({code:x.id})),
    professional_specialties:PROFESSIONAL_SPECIALTIES,
    competitor_is_professional_subtype:false,
    version:'r59-local-fallback'
  };
}

export function specialtyOptions(taxonomy=taxonomyCache){
  const rows=taxonomy?.professional_specialties;
  if(Array.isArray(rows)&&rows.length)return rows.map(x=>({value:x.code||x.codigo,label:x.name||x.nombre||x.code||x.codigo}));
  return PROFESSIONAL_SPECIALTIES.map(x=>({value:x.code,label:x.name}));
}
