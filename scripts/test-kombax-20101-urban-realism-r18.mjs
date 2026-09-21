import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const js=read('web/js/modules/kombax-events.js');
const migration=read('supabase/migrations/184_kombax_events_urban_realism_20101_r18.sql');
const dir=path.join(root,'web/assets/demo-events/urban-warriors-jiujitsu-interclub/fighters-realistic');
const fighters=['malik-benitez','bruno-sato','aina-torres','hana-ribeiro','daniel-ortiz','marc-vidal','laia-costa','emma-leon','leo-martin','hugo-rios'];
const files=fighters.map(x=>`${x}.webp`);
const insertCount=(migration.match(/insert into public\.kombax_evento_combates_publicos/g)||[]).length;
const mainTrue=(migration.match(/'programado',true,true,v_uid/g)||[]).length;
const mainFalse=(migration.match(/'programado',true,false,v_uid/g)||[]).length;
const checks=[
  ['10 realistic portrait assets exist', files.every(f=>fs.existsSync(path.join(dir,f)))],
  ['10 portrait files are unique filenames', new Set(files).size===10],
  ['frontend maps the 10 active fighters to realistic portraits', fighters.every(f=>js.includes(`fighters-realistic/${f}.webp`))],
  ['demo album mirrors fighter bank', js.includes('const demoUrbanAlbumMedia=') && js.includes('demo-urban-album-') && js.includes('local_url:url')],
  ['album hydration supports packaged local media', js.includes("const local=card.dataset.kxLocalMedia||''") && js.includes("local?{url:local,external:false,mime_type:'image/webp'")],
  ['album lightbox supports packaged local media', js.includes('row.local_url?{url:row.local_url,external:false}')],
  ['demo portraits stay presentation-only while manager uses persisted media', !js.includes('const demoAlbum=fresh.slug===URBAN_WARRIORS_JIUJITSU_DEMO_SLUG') && js.includes('const media=Array.isArray(fresh.media)?fresh.media:[];') && js.includes('photosUsed=Number(quota?.fotos_usadas??fallbackPhotos)')],
  ['seed removes two surplus demo fighters', migration.includes("nombre_publico in ('Nico Serra','Ian Cruz')")],
  ['seed defines five fights', insertCount===5],
  ['seed defines exactly one true Main Event', mainTrue===1 && mainFalse===4],
  ['seed reports 10-photo realism album', migration.includes("'demo_album_photo_count',10") && migration.includes("'unique_photo_count'")],
];
let bad=0;
for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);
console.log('OK KOMBAX 20.101 R18 Urban Warriors Realism Pass');
