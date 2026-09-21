import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const js=read('web/js/modules/kombax-events.js');
const migration=read('supabase/migrations/183_kombax_events_single_main_event_demo_hardening_20101_r18.sql');
const checks=[
 ['strict fight boolean parser exists',js.includes("const strictFlag=value=>value===true||value===1||value==='1'||value==='true'||value==='t';")],
 ['Fight Card featured class uses strictFlag',js.includes("strictFlag(f.destacado)?'featured':''")],
 ['Fight Card Main Event label uses strictFlag',js.includes("strictFlag(f.destacado)?'MAIN EVENT':'FIGHT CARD'")],
 ['pickMainFight uses strictFlag',js.includes('pool.find(x=>strictFlag(x.destacado))')],
 ['seed normalizes single Main Event',migration.includes('set destacado=(c.id=v_main_fight)')],
 ['current demo repair included',migration.includes('set destacado=(c.id=(select id from main))')],
 ['seed reports main_event_count',migration.includes("'main_event_count'")],
 ['seed execute not granted to anon',migration.includes('revoke all on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() from public, anon;')],
];
let bad=0;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);
console.log('OK KOMBAX 20.101 R18 single Main Event hardening');
