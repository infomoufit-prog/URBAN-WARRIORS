import fs from 'node:fs';
import assert from 'node:assert/strict';

const read=file=>fs.readFileSync(file,'utf8');
const config=read('web/config.js'),gradle=read('android/app/build.gradle'),sw=read('web/service-worker.js');
const finance=read('web/js/modules/finance.js'),premium=read('web/js/modules/finance-premium.js'),guide=read('web/js/modules/finance-guide.js');
const admin=read('web/js/modules/admin.js'),help=read('web/js/modules/help-legal.js'),poster=read('web/js/modules/club-poster.js');
const index=JSON.parse(read('web/assets/guides/runtime-index.json'));
const checks=[
  ['build web R108',config.includes("version: '2.0.0-rc.13-r108-finance-guide-poster'")&&config.includes('build: 20161')],
  ['build Android R108',gradle.includes('versionCode 20161')&&gradle.includes("versionName '2.0.0-rc.13-r108-finance-guide-poster'")],
  ['service worker R108',sw.includes('kombax-build-20161')&&sw.includes('20161-r108-finance-guide-poster')],
  ['PDF disponible',fs.existsSync('web/assets/guides/finance/KOMBAX_GUIA_FINANZAS_CLUB.pdf')&&fs.statSync('web/assets/guides/finance/KOMBAX_GUIA_FINANZAS_CLUB.pdf').size>50000],
  ['guía registrada',index.finance_guide?.id==='r108-finance-club'&&index.finance_guide?.active===true&&index.finance_guide?.pdf.includes('KOMBAX_GUIA_FINANZAS_CLUB.pdf')],
  ['ayuda en Finanzas',finance.includes('mountFinanceGuide({premium:!portal})')&&finance.includes('mountFinanceGuide({premium:true})')],
  ['ayuda en Finanzas Premium',premium.includes('mountFinanceGuide({premium:true})')],
  ['acciones PDF',guide.includes('openBundledPdf')&&guide.includes('saveBundledPdf')&&guide.includes('data-finance-guide-download')],
  ['cartel sustituido',fs.existsSync('web/assets/docs/Cartel_Descarga_KOMBAX_Club.png')&&fs.statSync('web/assets/docs/Cartel_Descarga_KOMBAX_Club.png').size>500000],
  ['descarga e impresión cartel',poster.includes('downloadClubPoster')&&poster.includes('printClubPoster')&&admin.includes('data-club-poster-print')&&help.includes('data-club-poster-download')],
];
let failed=0;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} ${name}`);if(!ok)failed++}assert.equal(failed,0);console.log(`PASS R108 · ${checks.length} comprobaciones`);
