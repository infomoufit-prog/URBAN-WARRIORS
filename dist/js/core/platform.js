const CLUB_SELECTION_KEY='kombax_selected_club_slug';
const CLUB_PREVIEW_KEY='kombax_selected_club_preview';

export const KOMBAX_BRAND=Object.freeze({
  name:'KOMBAX',
  socialName:'KOMBAX Social',
  showcaseName:'KOMBAX Showcase',
  tagline:'Connect · Compete · Grow',
  symbol:'./assets/brand/kombax-symbol-white.png',
  symbolBlack:'./assets/kombax-symbol.png',
  symbolWhite:'./assets/brand/kombax-symbol-white.png',
  symbolRed:'./assets/brand/kombax-symbol-red.png'
});

export const CLUB_THEMES=Object.freeze({
  'combat-dark':{id:'combat-dark',name:'Combat Dark Neon',description:'Negro carbón, rojo sangre y halo carmesí sutil. Alto contraste premium.',className:'theme-combat-dark'},
  'performance-pro':{id:'performance-pro',name:'Electric Blue Pro',description:'Grafito técnico, azul eléctrico y brillo frío controlado.',className:'theme-performance-pro'},
  'champion-gold':{id:'champion-gold',name:'Gold Luxe',description:'Negro profundo, oro cálido y luminosidad elegante de competición.',className:'theme-champion-gold'},
  'dojo-heritage':{id:'dojo-heritage',name:'Dojo Heritage Glow',description:'Granate profundo, cobre y luz cálida sutil: tradición con acabado contemporáneo.',className:'theme-dojo-heritage'}
});

export const platformFeatures=()=>Object.freeze({
  gateway:window.UW_CONFIG?.features?.kombaxGateway===true,
  directProfiles:window.UW_CONFIG?.features?.directProfiles===true,
  social:window.UW_CONFIG?.features?.kombaxSocial===true,
  showcase:window.UW_CONFIG?.features?.kombaxShowcase===true,
  demoDirectory:window.UW_CONFIG?.features?.demoDirectory===true,
  showcaseDemo:window.UW_CONFIG?.features?.showcaseDemo===true
});

export function selectedClubSlug(){
  try{return localStorage.getItem(CLUB_SELECTION_KEY)||window.UW_CONFIG?.clubSlug||''}catch{return window.UW_CONFIG?.clubSlug||''}
}

export function hasExplicitClubSelection(){try{return Boolean(localStorage.getItem(CLUB_SELECTION_KEY))}catch{return false}}

export function selectedClubPreview(){try{return JSON.parse(localStorage.getItem(CLUB_PREVIEW_KEY)||'null')}catch{return null}}

export function selectClubSlug(slug,preview=null){
  const value=String(slug||'').trim().toLowerCase();
  if(!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(value))throw new Error('Identificador de club no válido.');
  try{localStorage.setItem(CLUB_SELECTION_KEY,value)}catch{}
  if(preview&&typeof preview==='object'){try{localStorage.setItem(CLUB_PREVIEW_KEY,JSON.stringify({...preview,slug:value}))}catch{}}
  return value;
}

export function clearSelectedClub(){try{localStorage.removeItem(CLUB_SELECTION_KEY);localStorage.removeItem(CLUB_PREVIEW_KEY)}catch{}}

export function themeDefinition(themeId){
  const legacy={forge:'combat-dark',crimson:'combat-dark',arena:'champion-gold',pulse:'performance-pro'};
  return CLUB_THEMES[legacy[themeId]||themeId]||CLUB_THEMES['combat-dark'];
}

export function themeFromClub(club){
  const id=String(club?.theme_id||club?.tema||'combat-dark');
  return themeDefinition(id);
}

export function tenantKey(session,suffix=''){
  const club=session?.club_id||'public';
  const user=session?.id||'anonymous';
  return `${club}:${user}:${suffix}`;
}

export function publicPlatformIntroduction(){
  return 'KOMBAX conecta clubes, miembros, competidores, marcas, federaciones y profesionales del mundo de las artes marciales y los deportes de contacto.';
}
