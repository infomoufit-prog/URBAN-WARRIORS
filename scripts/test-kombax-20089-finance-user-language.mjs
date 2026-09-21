import fs from 'node:fs';
const finance=fs.readFileSync(new URL('../web/js/modules/finance-premium.js',import.meta.url),'utf8');
const boot=fs.readFileSync(new URL('../web/js/modules/finance-premium-bootstrap.js',import.meta.url),'utf8');
const forbidden=[
  'QA 20083','20.083 añade','finance_pilot_live_enabled','Recurring:','Pilot live:','Ejecutar Shadow QA','Aprobar Shadow QA','Shadow QA completado','Aprobación QA revocada','La interfaz y el backend KOMBAX no están en la misma versión'
];
for(const term of forbidden){if(finance.includes(term)||boot.includes(term))throw new Error(`Visible technical text leaked: ${term}`)}
for(const required of ['COMPROBACIÓN DE AUTOMATIZACIONES','Ejecutar comprobación','Generación automática','Finanzas Premium necesita una actualización']){
  if(!finance.includes(required)&&!boot.includes(required))throw new Error(`Missing human-facing replacement: ${required}`)
}
const config=fs.readFileSync(new URL('../web/config.js',import.meta.url),'utf8');const build=Number(config.match(/build:\s*(\d+)/)?.[1]||0);if(build<20089)throw new Error('web build regressed below 20089');
const gradle=fs.readFileSync(new URL('../android/app/build.gradle',import.meta.url),'utf8');const versionCode=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);if(versionCode<20089)throw new Error('android versionCode regressed below 20089');
console.log('PASS 20089 finance user-language audit');
