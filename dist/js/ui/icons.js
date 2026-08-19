const paths = {
  home:'<path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10.5V20h13v-9.5"/><path d="M9 20v-6h6v6"/>',
  layers:'<path d="m12 2 9 5-9 5-9-5 9-5Z"/><path d="m3 12 9 5 9-5"/><path d="m3 17 9 5 9-5"/>',
  users:'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  user:'<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  userPlus:'<path d="M15 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8" cy="7" r="4"/><path d="M19 8v6M16 11h6"/>',
  calendar:'<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  checkCircle:'<circle cx="12" cy="12" r="9"/><path d="m8 12 2.7 2.7L16 9.5"/>',
  chart:'<path d="M4 19V9M10 19V5M16 19v-7M22 19H2"/>',
  wallet:'<path d="M3 6h15a2 2 0 0 1 2 2v10H5a2 2 0 0 1-2-2V6Z"/><path d="M3 8V5a2 2 0 0 1 2-2h12"/><path d="M16 12h6v4h-6a2 2 0 1 1 0-4Z"/>',
  bell:'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M10 21h4"/>',
  megaphone:'<path d="m3 11 14-5v12L3 13v-2Z"/><path d="M11.5 16.3 13 21H8l-1.6-6.1"/><path d="M21 9v6"/>',
  message:'<path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4v8Z"/>',
  heart:'<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8Z"/>',
  clipboard:'<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V2h6v2M9 10h6M9 14h6"/>',
  package:'<path d="m21 8-9 5-9-5 9-5 9 5Z"/><path d="M3 8v9l9 5 9-5V8M12 13v9"/>',
  settings:'<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6 1.7 1.7 0 0 0 10 3V2.8h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z"/>',
  activity:'<path d="M3 12h4l2-6 4 12 2-6h6"/>',
  shieldCheck:'<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>',
  shield:'<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/>',
  chevronLeft:'<path d="m15 18-6-6 6-6"/>',
  chevronRight:'<path d="m9 18 6-6-6-6"/>',
  download:'<path d="M12 3v12M7 10l5 5 5-5"/><path d="M4 21h16"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  more:'<circle cx="5" cy="12" r="1" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/><circle cx="19" cy="12" r="1" fill="currentColor" stroke="none"/>',
  menu:'<path d="M4 7h16M4 12h16M4 17h16"/>',
  close:'<path d="m6 6 12 12M18 6 6 18"/>',
  alert:'<path d="M12 3 2.5 20h19L12 3Z"/><path d="M12 9v5M12 17.5v.01"/>',
  fileText:'<path d="M6 2h8l4 4v16H6V2Z"/><path d="M14 2v5h5M9 13h6M9 17h6"/>',
  qr:'<rect x="3" y="3" width="6" height="6"/><rect x="15" y="3" width="6" height="6"/><rect x="3" y="15" width="6" height="6"/><path d="M15 15h2v2h-2zM19 15h2v6h-2M15 19h2v2h-2"/>',
  upload:'<path d="M12 16V4M7 9l5-5 5 5"/><path d="M4 20h16"/>',
  image:'<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="m21 15-5-5L5 20"/>',
  edit:'<path d="M12 20h9"/><path d="m16.5 3.5 4 4L8 20l-5 1 1-5L16.5 3.5Z"/>',
  search:'<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
  logOut:'<path d="M10 17l5-5-5-5M15 12H3"/><path d="M14 3h6v18h-6"/>',
  creditCard:'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h3"/>',
  dumbbell:'<path d="M6 9v6M3 10v4M18 9v6M21 10v4M6 12h12"/>',
  eye:'<path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6S2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="2.5"/>',
  refresh:'<path d="M20 7v5h-5"/><path d="M4 17v-5h5"/><path d="M6.1 9A7 7 0 0 1 18.5 6.5L20 12M4 12l1.5 5.5A7 7 0 0 0 17.9 15"/>',
  trash:'<path d="M4 7h16M9 7V4h6v3M7 7l1 14h8l1-14M10 11v6M14 11v6"/>',
  archive:'<rect x="3" y="5" width="18" height="5" rx="1"/><path d="M5 10v10h14V10M10 14h4"/>',
  folder:'<path d="M3 6h7l2 2h9v11H3V6Z"/>',
  shoppingBag:'<path d="M5 8h14l-1 13H6L5 8Z"/><path d="M9 10V6a3 3 0 0 1 6 0v4"/>',
  mapPin:'<path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',

  dojo:'<path d="M3 20h18M5 20v-9l7-6 7 6v9M8 20v-6h8v6M4 11h16M9 8h6"/>',
  idCard:'<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="8" cy="11" r="2.2"/><path d="M5.5 16c.7-1.7 1.7-2.5 2.5-2.5S9.8 14.3 10.5 16M13 10h5M13 14h4"/>',
  fighter:'<circle cx="12" cy="5" r="2"/><path d="M9 9l3-2 3 2 2 4-3 2-1 6M10 12 7 16l-3-2M14 15l4 3 2-3"/>',
  brandMark:'<path d="M12 2l2.2 6.2L20 10l-5.8 2L12 18l-2.2-6L4 10l5.8-1.8L12 2Z"/><circle cx="12" cy="10" r="2.4"/>',
  federation:'<path d="M12 2 20 6v6c0 5-3.4 8.2-8 10-4.6-1.8-8-5-8-10V6l8-4Z"/><path d="M8 9h8M9 13h6M12 7v9"/>',
  spectator:'<path d="M2.5 12s3.7-5.5 9.5-5.5 9.5 5.5 9.5 5.5-3.7 5.5-9.5 5.5S2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="3"/><path d="M4 20h16"/>',
  professional:'<rect x="4" y="7" width="16" height="12" rx="2"/><path d="M9 7V5h6v2M4 12h16M10 15h4"/>',
  network:'<circle cx="6" cy="12" r="2.3"/><circle cx="18" cy="7" r="2.3"/><circle cx="18" cy="17" r="2.3"/><path d="m8 11 7.7-3M8 13l7.7 3"/>',
  spotlight:'<path d="M5 4h14l-2 7H7L5 4Z"/><path d="M9 11v5M15 11v5M6 20h12M12 16v4"/>',
  receipt:'<path d="M6 3h12v18l-3-2-3 2-3-2-3 2V3Z"/><path d="M9 8h6M9 12h6M9 16h4"/>',
  checkin:'<path d="M4 4h16v16H4z"/><path d="m8 12 2.5 2.5L16 9"/>',
  arrowUpRight:'<path d="M7 17 17 7M9 7h8v8"/>',
  globe:'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18"/>',
  lock:'<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
  mail:'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m4 7 8 6 8-6"/>',
  key:'<circle cx="8" cy="15" r="4"/><path d="m11 12 8-8M16 7l2 2M14 9l2 2"/>',
  bookmark:'<path d="M6 3h12v18l-6-4-6 4V3Z"/>',
  bookmarkCheck:'<path d="M6 3h12v18l-6-4-6 4V3Z"/><path d="m9 10 2 2 4-4"/>',
  eyeOff:'<path d="M3 3l18 18M10.6 6.2A10.8 10.8 0 0 1 12 6c6 0 9.5 6 9.5 6a17 17 0 0 1-3 3.7M6.3 6.3C3.8 8.2 2.5 12 2.5 12s3.5 6 9.5 6a9.6 9.6 0 0 0 3-.5M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
  filter:'<path d="M4 6h16M7 12h10M10 18h4"/>',
  sparkles:'<path d="m12 3 1.3 3.7L17 8l-3.7 1.3L12 13l-1.3-3.7L7 8l3.7-1.3L12 3Z"/><path d="m19 15 .8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8L19 15ZM5 14l.7 1.8L7.5 16l-1.8.7L5 18.5l-.7-1.8L2.5 16l1.8-.2L5 14Z"/>'
};

export function icon(name,{size=20,className=''}={}){
  const body=paths[name]||paths.activity;
  return `<svg class="uw-icon ${className}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${body}</svg>`;
}

export const navIcon = (id) => icon({dashboard:'home',catalog:'layers',groups:'users',members:'user',enrollments:'userPlus',sessions:'calendar',attendance:'checkin',progress:'chart',finance:'wallet',reminders:'bell',communications:'megaphone',tracking:'clipboard',material:'package',notifications:'bell',users:'users',settings:'settings',diagnostics:'activity',certification:'shieldCheck',profile:'idCard',requests:'plus',documents:'folder',archive:'archive',install:'download',community:'dojo',social:'network',showcase:'spotlight','platform-admin':'key',scopes:'shieldCheck',events:'calendar',help:'fileText',more:'more'}[id]||'activity');


const featurePaths={
  club:`<path class="fi-main" d="M12 51h40M16 51V26l16-12 16 12v25M22 51V35h20v16M14 27h36"/><path class="fi-accent" d="M25 23h14M30 35v16M20 31h24"/><circle class="fi-node" cx="32" cy="13" r="3"/>`,
  identity:`<rect class="fi-main" x="10" y="15" width="44" height="34" rx="7"/><circle class="fi-accent" cx="24" cy="30" r="7"/><path class="fi-main" d="M15 44c2.5-6 5.5-9 9-9s6.5 3 9 9M37 26h11M37 33h9M37 40h7"/><path class="fi-accent" d="M44 12v7M40.5 15.5h7"/>`,
  fighter:`<circle class="fi-accent" cx="32" cy="12" r="6"/><path class="fi-main" d="M24 24l8-7 8 7 6 12-8 5-3 15M28 31 18 42l-8-7M38 42l10 9 6-8"/><path class="fi-accent" d="M24 25 15 29M40 25l9 5"/>`,
  brand:`<path class="fi-main" d="M32 8 38 24l16 6-16 6-6 16-6-16-16-6 16-6 6-16Z"/><circle class="fi-accent" cx="32" cy="30" r="7"/><path class="fi-accent" d="m46 12 2 6 6 2-6 2-2 6-2-6-6-2 6-2 2-6Z"/>`,
  federation:`<path class="fi-main" d="M32 8 52 17v14c0 12-8 20-20 25-12-5-20-13-20-25V17L32 8Z"/><path class="fi-accent" d="M22 25h20M25 34h14M32 20v25"/><circle class="fi-node" cx="32" cy="17" r="2.5"/>`,
  spectator:`<path class="fi-main" d="M8 32s9-15 24-15 24 15 24 15-9 15-24 15S8 32 8 32Z"/><circle class="fi-accent" cx="32" cy="32" r="8"/><path class="fi-main" d="M14 54h36"/><path class="fi-accent" d="M22 54v-5M32 54v-7M42 54v-5"/>`,
  professional:`<rect class="fi-main" x="10" y="19" width="44" height="32" rx="6"/><path class="fi-accent" d="M24 19v-6h16v6M10 31h44M27 36h10v6H27z"/><path class="fi-main" d="M18 51v4M46 51v4"/>`
};
export function featureIcon(name,{size=64,className=''}={}){
  const body=featurePaths[name]||featurePaths.identity;
  return `<svg class="feature-icon ${className}" width="${size}" height="${size}" viewBox="0 0 64 64" fill="none" aria-hidden="true" focusable="false">${body}</svg>`;
}
