import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const root=process.cwd();
let pass=0, fail=0;
function check(cond,msg){if(cond){console.log('PASS',msg);pass++;}else{console.error('FAIL',msg);fail++;}}
function file(p){return fs.existsSync(path.join(root,p));}
function sha(p){return crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex');}
const approved={
'artifacts/assets/sources-approved/kombax-training-hero-source.png':'6130e1630aef7e8259c4954f938e2e8183505ab88d5393ed0f105b56cde6f408',
'artifacts/assets/sources-approved/kombax-training-card-source.png':'6a5d1573bacc9072616fb117d337f820536a31b9389ac19b229c10e8250ac9d1',
'artifacts/assets/sources-approved/kombax-consulting-hero-source.png':'7756bd4cd84e1c73227be0ada24b4ebd31cda4a61392edfbb37b524d13b68c46',
'artifacts/assets/sources-approved/kombax-guides-hero-source.png':'814a5d137b2796276a826c85c92704e10b8deea64b123df1917e406eb9d25a85',
'artifacts/assets/sources-approved/kombax-guides-card-source.png':'8e3d7daab74c028ca6fc0f256bc8d4039299770193c24a5af19cf936b68164d4',
'artifacts/assets/sources-approved/kombax-consulting-card-source.png':'be3a7292601db7c80fd78b3f6f60fb5ee8f0aee229b86653329632b8189cdd4b'};
for(const [p,h] of Object.entries(approved))check(file(p)&&sha(p)===h,`approved source locked: ${path.basename(p)}`);
for(const family of ['guides','consulting','training'])for(const v of ['hero','tablet','card'])check(file(`artifacts/assets/kombax-${family}-${v}.webp`),`${family} ${v} asset`);
const srcDir=path.join(root,'docs/09_GUIDES_SOURCE');
const md=fs.readdirSync(srcDir).filter(x=>/^\d\d_.*\.md$/.test(x));
check(md.length===15,'15 guide Markdown sources');
for(const x of md){const t=fs.readFileSync(path.join(srcDir,x),'utf8');check(t.includes('## Cuándo pasar a KOMBAX Consultoría'),`${x} consulting trigger`);check(t.includes('## Fuentes oficiales consultadas'),`${x} official sources`);check(t.includes('## Límites de la guía'),`${x} limits`);}
const pdfDir=path.join(root,'artifacts/guides');
const pdfs=fs.readdirSync(pdfDir).filter(x=>x.endsWith('.pdf'));
const guidePdfs=pdfs.filter(x=>/^KOMBAX_GUIA_\d{2}_/.test(x));
const masterPdf=pdfs.includes('KOMBAX_GUIAS_ESPANA_CATALUNA_COLECCION_INICIAL_2026.pdf');
check(guidePdfs.length===15 && masterPdf,'15 individual PDFs + 1 master');
const idx=JSON.parse(fs.readFileSync(path.join(srcDir,'guides_index.json'),'utf8'));
check(idx.guides?.length===15,'structured guide index has 15 guides');
check(idx.regional_layer==='Cataluña','first regional layer explicitly Cataluña');
const services=JSON.parse(fs.readFileSync(path.join(root,'artifacts/catalogs/KOMBAX_CONSULTORIA_SERVICES_SEED_2026.json'),'utf8'));
check(services.status==='PREPARATORY_NOT_LIVE','consulting catalog is not live');
check(services.services.every(s=>s.price_minor===null),'consulting seed contains no invented prices');
check(file('docs/01_CURRENT_RELEASE/PREBLOCK_RESEARCH_VERIFICATION_LOG_2026-09-21.md'),'research verification log');
check(file('docs/01_CURRENT_RELEASE/PREBLOCK_TRAINING_PRIVATE_LAYER_ARCHITECTURE.md'),'private training architecture');
check(file('docs/01_CURRENT_RELEASE/PHASE0_R81_BUILD_20134_PENDING_MASTER_PLAN.md'),'master plan preserved');
console.log(`KOMBAX PREBLOCK DESIGN + CONTENT: ${pass}/${pass+fail} PASS`);
if(fail)process.exit(1);
