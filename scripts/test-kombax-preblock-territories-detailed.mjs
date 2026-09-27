import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
let passed=0, failed=0;
const ok=(cond,msg)=>{if(cond){console.log(`PASS ${msg}`);passed++;}else{console.error(`FAIL ${msg}`);failed++;}};
const exists=(p)=>fs.existsSync(path.join(root,p));
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');

const indexPath='docs/11_GUIDES_TERRITORIES_DETAILED/territories_detailed_index.json';
ok(exists(indexPath),'detailed territory index exists');
const idx=JSON.parse(read(indexPath));
ok(Array.isArray(idx.territories)&&idx.territories.length===19,'19 territorial units indexed');
ok(idx.review_date==='21/09/2026','review date pinned');

const requiredSections=[
  '## 1. Qué ofrece este dossier',
  '## 2. Mapa de decisión antes de empezar',
  '## 3. Diferenciales territoriales verificados',
  '## 4. Ruta práctica - crear y operar una entidad deportiva',
  '## 5. Ruta práctica - organizar una velada, evento o interclub',
  '## 6. Las 15 materias KOMBAX aplicadas a este territorio',
  '## 7. Ejemplo operativo',
  '## 8. Checklist antes de publicar o ejecutar',
  '## 9. Cuándo pasar a KOMBAX Consultoría',
  '## 10. Qué KOMBAX Consultoría no debe prometer',
  '## 11. Fuentes oficiales territoriales',
  '## 12. Fuentes estatales comunes',
  '## 13. Límite de actualización'
];

for(const t of idx.territories){
  ok(exists(t.markdown),`${t.code} markdown exists`);
  ok(exists(t.pdf),`${t.code} PDF exists`);
  const md=read(t.markdown);
  ok(requiredSections.every(s=>md.includes(s)),`${t.code} complete professional section set`);
  ok(md.includes('KOMBAX Consultoría')&&md.includes('no debe prometer'),`${t.code} consulting boundary present`);
  ok(/https:\/\/(www\.)?boe\.es|https:\/\//.test(md),`${t.code} official/source URLs present`);
  ok(!/\bTODO\b|\bTBD\b|LOREM IPSUM/i.test(md),`${t.code} no placeholder content`);
  const pdfSize=fs.statSync(path.join(root,t.pdf)).size;
  ok(pdfSize>100000,`${t.code} PDF substantive size`);
}

const master='artifacts/guides/territories-detailed/KOMBAX_GUIAS_TERRITORIOS_ESPANA_DOSSIER_PROFESIONAL_DETALLADO_2026.pdf';
ok(exists(master),'detailed territorial master PDF exists');
ok(fs.statSync(path.join(root,master)).size>1000000,'detailed master PDF substantive size');
ok(exists('docs/11_GUIDES_TERRITORIES_DETAILED/METODOLOGIA_Y_LIMITES_EDICION_DETALLADA.md'),'methodology/limits document exists');

const promptMd='docs/01_CURRENT_RELEASE/PROMPT_MAESTRO_CONTINUACION_KOMBAX_BLOQUE1_FASES_1_5.md';
const promptPdf='artifacts/guides/PROMPT_MAESTRO_CONTINUACION_KOMBAX_BLOQUE1_FASES_1_5.pdf';
ok(exists(promptMd),'master continuation prompt MD exists');
ok(exists(promptPdf),'master continuation prompt PDF exists');
const prompt=read(promptMd);
ok(prompt.includes('KOMBAX_20134_R81_PREBLOCK_TERRITORIAL_GUIDES_DETAILED_MASTERPROMPT_ACCUMULATIVE_FINAL.zip'),'prompt pins exact next base ZIP');
ok(['FASE 1','FASE 2','FASE 3','FASE 4','FASE 5'].every(x=>prompt.includes(x)),'prompt contains phases 1-5');
ok(prompt.includes('KOMBAX Formación')&&prompt.includes('NO la hagas pública'),'prompt preserves private training constraint');
ok(prompt.includes('prohibido inventar requisitos'),'prompt preserves no-invention editorial rule');

const consult='artifacts/catalogs/KOMBAX_CONSULTORIA_SERVICES_SEED_2026.json';
ok(exists(consult),'consulting catalog exists');
if(exists(consult)){
  const data=JSON.parse(read(consult));
  const raw=JSON.stringify(data);
  const prices=[...raw.matchAll(/"price_minor":(null|\d+)/g)].map(m=>m[1]);
  ok(prices.length>0 && prices.every(v=>v==='null'),'consulting prices remain unset; no invented pricing');
}

console.log(`KOMBAX DETAILED TERRITORIES + MASTER PROMPT: ${passed}/${passed+failed} PASS`);
if(failed) process.exit(1);
