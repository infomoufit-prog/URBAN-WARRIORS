import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const migration=read('supabase/migrations/185_kombax_showcase_urban_warriors_demo_products_20101_r19.sql');
const verification=read('supabase/verification/verify_185_kombax_showcase_urban_warriors_demo_products_20101_r19.sql');
const showcase=read('web/js/modules/showcase.js');
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const names=[
  'urban-warriors-casco-integral-pro.webp',
  'urban-warriors-guantes-integrales-elite.webp',
  'urban-performance-whey-recovery.webp'
];
const slugs=[
  'urban-warriors-casco-integral-pro-r19-demo',
  'urban-warriors-guantes-integrales-elite-r19-demo',
  'urban-performance-whey-recovery-r19-demo'
];
const assetRoots=[
  'web/assets/demo-showcase/urban-warriors',
  'dist/assets/demo-showcase/urban-warriors',
  'android/app/src/main/assets/www/assets/demo-showcase/urban-warriors'
];
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const webFiles=names.map(n=>path.join(root,assetRoots[0],n));
const allCopiesMatch=assetRoots.every(dir=>names.every(n=>{
  const target=path.join(root,dir,n);
  const source=path.join(root,assetRoots[0],n);
  return fs.existsSync(target)&&hash(target)===hash(source);
}));
const checks=[
  ['three local Showcase product assets exist',webFiles.every(fs.existsSync)],
  ['three local product images are distinct',new Set(webFiles.map(hash)).size===3],
  ['three product assets copied to dist and Android',allCopiesMatch],
  ['migration targets the existing Urban Warriors club brand',migration.includes("m.club_id='11111111-1111-4111-8111-111111111111'::uuid")&&migration.includes("m.slug='club-urban-warriors'")&&migration.includes("m.sujeto_tipo='club'")],
  ['migration resolves categories by slug',migration.includes("slug='protecciones'")&&migration.includes("slug='equipamiento'")&&migration.includes("slug='nutricion'")],
  ['exactly three R19 demo slugs are seeded',slugs.every(s=>migration.includes(s))&&(migration.match(/on conflict \(marca_id,slug\)/g)||[]).length===3],
  ['prices are the approved reference values',migration.includes("79.90,'EUR'")&&migration.includes("64.90,'EUR'")&&migration.includes("49.90,'EUR'")],
  ['all three products use in-app contact CTA',(migration.match(/'contact','Me interesa'/g)||[]).length===3],
  ['nutrition demo avoids invented label macros and carries legal warning',migration.includes('No se atribuyen valores nutricionales concretos')&&migration.includes('no sustituye una dieta equilibrada')],
  ['Showcase contact CTA remains product-linked',showcase.includes("if(type==='contact'&&item.proveedor_social_id){return openShowcaseContact(item);}")&&showcase.includes('la conversación quedará vinculada a este producto o servicio')],
  ['Showcase preserves legacy external CTA or later KOMBAX commerce evolution',showcase.includes('La contratación o compra, cuando exista, se realiza directamente con el club, la marca o su web externa.')||(showcase.includes('KOMBAX proporciona la infraestructura tecnológica')&&showcase.includes('Comprar en KOMBAX'))],
  ['verification checks Urban ownership and uniqueness',verification.includes('count(distinct e.imagen_url) as unique_images')&&verification.includes("m.club_id='11111111-1111-4111-8111-111111111111'::uuid")],
  ['cache bumped to R19',revisionAtLeast(index,19)&&revisionAtLeast(sw,19,'media-r')],
  ['R18 Urban realism preserved',fs.existsSync(path.join(root,'supabase/migrations/184_kombax_events_urban_realism_20101_r18.sql'))&&fs.existsSync(path.join(root,'scripts/test-kombax-20101-urban-realism-r18.mjs'))]
];
let bad=0;
for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);
console.log('OK KOMBAX 20.101 R19 Urban Warriors Showcase Products');
