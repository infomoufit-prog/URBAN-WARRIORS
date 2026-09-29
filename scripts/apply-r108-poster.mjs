import fs from 'node:fs';

function edit(path, changes){let text=fs.readFileSync(path,'utf8');for(const [from,to] of changes){if(!text.includes(from))throw new Error(`Missing marker ${path}: ${from.slice(0,100)}`);text=text.replace(from,to)}fs.writeFileSync(path,text,'utf8')}

edit('web/js/modules/admin.js',[
  ["import { isAutoTranslatePublicEnabled, setAutoTranslatePublicEnabled } from '../i18n/user-content-translation.js';", "import { isAutoTranslatePublicEnabled, setAutoTranslatePublicEnabled } from '../i18n/user-content-translation.js';\nimport { bindClubPosterActions } from './club-poster.js';"],
  ["'<a class=\"btn btn-ghost btn-sm\" href=\"./assets/docs/Cartel_Descarga_KOMBAX_Club.png\" target=\"_blank\">Abrir cartel</a>'", "'<div class=\"row-actions\"><a class=\"btn btn-ghost btn-sm\" href=\"./assets/docs/Cartel_Descarga_KOMBAX_Club.png\" target=\"_blank\" rel=\"noopener noreferrer\">Abrir</a><button class=\"btn btn-ghost btn-sm\" type=\"button\" data-club-poster-download>Descargar</button><button class=\"btn btn-ghost btn-sm\" type=\"button\" data-club-poster-print>Imprimir</button></div>'"],
  ["<a class=\"btn btn-ghost\" href=\"./assets/docs/Cartel_Descarga_KOMBAX_Club.png\" target=\"_blank\">${icon('qr',{size:16})} Ver cartel completo</a>", "<div class=\"row-actions\"><a class=\"btn btn-ghost\" href=\"./assets/docs/Cartel_Descarga_KOMBAX_Club.png\" target=\"_blank\" rel=\"noopener noreferrer\">${icon('qr',{size:16})} Ver cartel</a><button class=\"btn btn-ghost\" type=\"button\" data-club-poster-download>Descargar</button><button class=\"btn btn-primary\" type=\"button\" data-club-poster-print>Imprimir A4</button></div>"],
  ["  document.getElementById('install-pwa')?.addEventListener", "  bindClubPosterActions(document.getElementById('main-view')||document);\n  document.getElementById('install-pwa')?.addEventListener"],
]);

edit('web/js/modules/help-legal.js',[
  ["import { platformFeatures } from '../core/platform.js';", "import { platformFeatures } from '../core/platform.js';\nimport { bindClubPosterActions } from './club-poster.js';"],
  ["<a class=\"btn btn-ghost\" href=\"./assets/docs/Cartel_Descarga_KOMBAX_Club.png\" target=\"_blank\" rel=\"noopener noreferrer\">${icon('qr',{size:16})} Abrir cartel</a>", "<div class=\"row-actions\"><a class=\"btn btn-ghost\" href=\"./assets/docs/Cartel_Descarga_KOMBAX_Club.png\" target=\"_blank\" rel=\"noopener noreferrer\">${icon('qr',{size:16})} Abrir cartel</a><button class=\"btn btn-ghost\" type=\"button\" data-club-poster-download>Descargar</button><button class=\"btn btn-primary\" type=\"button\" data-club-poster-print>Imprimir A4</button></div>"],
  ["    document.querySelector('#main-view .page-head')?.insertAdjacentHTML", "    bindClubPosterActions(document.getElementById('main-view')||document);\n    document.querySelector('#main-view .page-head')?.insertAdjacentHTML"],
]);

console.log('R108 club poster actions applied');
