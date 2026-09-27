import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
let pass=0, fail=0;
const ok=(cond,msg)=>{if(cond){console.log('PASS',msg);pass++}else{console.error('FAIL',msg);fail++}};
const catPath=path.join(root,'artifacts/guides/territories/KOMBAX_TERRITORIAL_CATALOG_2026.json');
const searchPath=path.join(root,'artifacts/catalogs/KOMBAX_GUIDES_TERRITORIAL_SEARCH_INDEX_2026.json');
ok(fs.existsSync(catPath),'territorial catalog exists');
ok(fs.existsSync(searchPath),'territorial search index exists');
const cat=JSON.parse(fs.readFileSync(catPath,'utf8'));
const search=JSON.parse(fs.readFileSync(searchPath,'utf8'));
ok(cat.policy?.no_invention===true,'no-invention policy explicit');
ok(Array.isArray(cat.territories)&&cat.territories.length===19,'19 territorial units');
ok(search.selectors?.some(x=>x.id==='territory'&&x.values?.length===19),'search selector has 19 territories');
ok(String(search.composition_rule||'').includes('verified'),'search composition distinguishes verified data');
ok(String(search.consulting_cta?.body||'').includes('no sustituye asesoramiento profesional'),'consulting CTA states boundary');
const codes=new Set();
for(const t of cat.territories||[]){
  codes.add(t.code);
  ok((t.source_count||0)>=2,`${t.code} has >=2 official source references`);
  ok((t.verified_items||0)>=2,`${t.code} has >=2 verified differentials`);
  ok((t.case_specific_items||0)>=1,`${t.code} contains case-specific verification boundary`);
  ok(Array.isArray(t.consulting_triggers)&&t.consulting_triggers.length>=2,`${t.code} consulting triggers`);
  const md=path.join(root,'docs/10_GUIDES_TERRITORIES',`${t.code}_${t.slug}.md`);
  ok(fs.existsSync(md),`${t.code} markdown exists`);
  if(fs.existsSync(md)){
    const txt=fs.readFileSync(md,'utf8');
    ok(txt.includes('KOMBAX Consultoría'),`${t.code} has consulting handoff`);
    ok(txt.includes('Fuentes oficiales'),`${t.code} has official sources section`);
    ok(txt.includes('KOMBAX no rellena huecos normativos con supuestos'),`${t.code} carries no-invention statement`);
  }
  const prefix=`KOMBAX_GUIAS_TERRITORIO_${t.code}_`;
  const pdf=fs.readdirSync(path.join(root,'artifacts/guides/territories')).find(x=>x.startsWith(prefix)&&x.endsWith('.pdf'));
  ok(Boolean(pdf),`${t.code} PDF exists`);
}
ok(codes.size===19,'territory codes are unique');
ok(fs.existsSync(path.join(root,'artifacts/guides/territories/KOMBAX_GUIAS_TERRITORIOS_ESPANA_2026.pdf')),'territorial master PDF exists');
ok(fs.existsSync(path.join(root,'docs/10_GUIDES_TERRITORIES/TERRITORIAL_SOURCES_MATRIX.md')),'source matrix exists');
ok(fs.existsSync(path.join(root,'docs/10_GUIDES_TERRITORIES/TERRITORIAL_DIFFERENTIAL_MATRIX.md')),'human differential matrix exists');
console.log(`KOMBAX PREBLOCK TERRITORIES: ${pass}/${pass+fail} PASS`);
if(fail) process.exit(1);
