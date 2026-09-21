import http from 'k6/http';
import {check,sleep} from 'k6';
import {Rate,Trend} from 'k6/metrics';
import {SharedArray} from 'k6/data';

const errors=new Rate('kombax_errors');
const directoryLatency=new Trend('kombax_directory_ms',true);
const headerLatency=new Trend('kombax_header_ms',true);
const feedLatency=new Trend('kombax_feed_ms',true);
const showcaseLatency=new Trend('kombax_showcase_ms',true);
const contactsLatency=new Trend('kombax_contacts_ms',true);
const chatLatency=new Trend('kombax_chat_ms',true);

const target=Number(__ENV.KOMBAX_CONCURRENT_TARGET||100);
const allowed=[100,250,500,1000,2500,5000,7500,10000];
if(!allowed.includes(target))throw new Error(`KOMBAX_CONCURRENT_TARGET debe ser ${allowed.join(', ')}.`);
const hold=String(__ENV.KOMBAX_LOAD_DURATION||'5m');
const ramp=String(__ENV.KOMBAX_RAMP_DURATION||'2m');
const base=String(__ENV.SUPABASE_URL||'').replace(/\/$/,'');
const anon=String(__ENV.SUPABASE_ANON_KEY||'');
const fixturePath=String(__ENV.KOMBAX_AUTH_FIXTURE||'').trim();

const fixtures=new SharedArray('kombax-auth-fixture',()=>{
  if(fixturePath){
    const raw=open(fixturePath);
    return raw.split(/\r?\n/).map(x=>x.trim()).filter(x=>x&&!x.startsWith('#')).map(line=>{
      const [token,club_id,contacto_id='']=line.split('|').map(x=>x.trim());
      return {token,club_id,contacto_id};
    }).filter(x=>x.token&&x.club_id);
  }
  const tokens=String(__ENV.KOMBAX_AUTH_TOKENS||'').split(',').map(x=>x.trim()).filter(Boolean);
  const clubs=String(__ENV.KOMBAX_CLUB_IDS||'').split(',').map(x=>x.trim()).filter(Boolean);
  const contacts=String(__ENV.KOMBAX_CONTACT_IDS||'').split(',').map(x=>x.trim());
  return tokens.slice(0,Math.min(tokens.length,clubs.length)).map((token,i)=>({token,club_id:clubs[i],contacto_id:contacts[i]||''}));
});

export const options={
  scenarios:{
    mixed_read:{
      executor:'ramping-vus',
      startVUs:Math.min(25,target),
      stages:[
        {duration:ramp,target},
        {duration:hold,target},
        {duration:'1m',target:0}
      ],
      gracefulRampDown:'30s'
    }
  },
  thresholds:{
    http_req_failed:['rate<0.01'],
    kombax_errors:['rate<0.01'],
    kombax_directory_ms:['p(95)<600'],
    kombax_header_ms:['p(95)<600'],
    kombax_feed_ms:['p(95)<900'],
    kombax_showcase_ms:['p(95)<700'],
    kombax_contacts_ms:['p(95)<800'],
    kombax_chat_ms:['p(95)<600']
  }
};

const headers=token=>({'apikey':anon,'Authorization':`Bearer ${token||anon}`,'Content-Type':'application/json'});
const postRpc=(name,body,token='')=>http.post(`${base}/rest/v1/rpc/${name}`,JSON.stringify(body),{headers:headers(token),tags:{rpc:name}});
const record=(trend,response,label,extra=()=>true)=>{
  trend.add(response.timings.duration);
  const ok=check(response,{[`${label} 200`]:r=>r.status===200,[`${label} shape`]:r=>extra(r)});
  errors.add(!ok);
};
const json=r=>{try{return JSON.parse(r.body)}catch{return null}};

export function setup(){
  if(!base||!anon)throw new Error('Configura SUPABASE_URL y SUPABASE_ANON_KEY.');
  if(target>=1000&&fixtures.length<Math.min(100,target/10))console.warn(`Solo ${fixtures.length} identidades QA: la prueba ejercitará muchas sesiones compartiendo token. Para certificar, usa un fixture de tokens más amplio.`);
  return {fixtureCount:fixtures.length};
}

export default function(){
  const row=fixtures.length?fixtures[(__VU-1)%fixtures.length]:null;
  const roll=Math.random();

  if(!row||roll<0.18){
    const res=postRpc('app_buscar_clubes_kombax_v040',{p_query:__ITER%5===0?'boxeo':'',p_limit:30});
    record(directoryLatency,res,'directory',r=>Array.isArray(json(r))&&json(r).length<=30);
  }else if(roll<0.42){
    const res=postRpc('app_kombax_social_feed_v085',{p_cursor:null,p_cursor_id:null,p_limit:20},row.token);
    record(feedLatency,res,'feed',r=>Array.isArray(json(r))&&json(r).length<=20);
  }else if(roll<0.62){
    const res=postRpc('app_kombax_header_summary_v106',{p_club_id:row.club_id},row.token);
    record(headerLatency,res,'header',r=>Array.isArray(json(r))&&json(r).length<=1);
  }else if(roll<0.76){
    const res=postRpc('app_kombax_showcase_list_v054',{p_query:'',p_categoria:null,p_cursor:null,p_cursor_id:null,p_limit:24},row.token);
    record(showcaseLatency,res,'showcase',r=>Array.isArray(json(r))&&json(r).length<=24);
  }else if(roll<0.90){
    const res=postRpc('app_kombax_contactos_v106',{},row.token);
    record(contactsLatency,res,'contacts',r=>Array.isArray(json(r))&&json(r).length<=200);
  }else if(row.contacto_id){
    const res=postRpc('app_kombax_contact_mensajes_v106',{p_contacto_id:row.contacto_id,p_before_ordinal:null,p_after_ordinal:null,p_limit:30},row.token);
    record(chatLatency,res,'chat',r=>Array.isArray(json(r))&&json(r).length<=30);
  }else{
    const res=postRpc('app_kombax_header_summary_v106',{p_club_id:row.club_id},row.token);
    record(headerLatency,res,'header-fallback',r=>Array.isArray(json(r))&&json(r).length<=1);
  }

  sleep(2+Math.random()*5);
}
