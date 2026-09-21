import http from 'k6/http';
import {check,sleep} from 'k6';
import {Rate,Trend} from 'k6/metrics';

const errors=new Rate('kombax_errors');
const directoryLatency=new Trend('kombax_directory_ms',true);
const authenticatedLatency=new Trend('kombax_authenticated_ms',true);
const profile=String(__ENV.KOMBAX_LOAD_PROFILE||'10');
const vus={10:10,50:35,100:70}[profile]||10;
const duration=String(__ENV.KOMBAX_LOAD_DURATION||'5m');
const base=String(__ENV.SUPABASE_URL||'').replace(/\/$/,'');
const anon=String(__ENV.SUPABASE_ANON_KEY||'');
const tokens=String(__ENV.KOMBAX_AUTH_TOKENS||'').split(',').map(x=>x.trim()).filter(Boolean);
const clubs=String(__ENV.KOMBAX_CLUB_IDS||'').split(',').map(x=>x.trim()).filter(Boolean);

export const options={scenarios:{read_mix:{executor:'constant-vus',vus,duration}},thresholds:{http_req_failed:['rate<0.01'],kombax_errors:['rate<0.01'],kombax_directory_ms:['p(95)<2000'],kombax_authenticated_ms:['p(95)<2500']}};

const headers=token=>({'apikey':anon,'Authorization':`Bearer ${token||anon}`,'Content-Type':'application/json'});
function postRpc(name,body,token=''){return http.post(`${base}/rest/v1/rpc/${name}`,JSON.stringify(body),{headers:headers(token),tags:{rpc:name}})}

export function setup(){if(!base||!anon)throw new Error('Configura SUPABASE_URL y SUPABASE_ANON_KEY.');return{};}
export default function(){
  const query=__ITER%4===0?'boxeo':'';const directory=postRpc('app_buscar_clubes_kombax_v040',{p_query:query,p_limit:30});directoryLatency.add(directory.timings.duration);errors.add(!check(directory,{'directory 200':r=>r.status===200,'directory bounded':r=>{try{return JSON.parse(r.body).length<=30}catch{return false}}}));
  if(tokens.length&&clubs.length){const i=__VU%Math.min(tokens.length,clubs.length),token=tokens[i],club=clubs[i];const feed=postRpc('app_kombax_social_feed_v085',{p_cursor:null,p_cursor_id:null,p_limit:20},token);authenticatedLatency.add(feed.timings.duration);errors.add(!check(feed,{'social feed 200':r=>r.status===200}));const notifications=postRpc('app_kombax_header_summary_v106',{p_club_id:club},token);authenticatedLatency.add(notifications.timings.duration);errors.add(!check(notifications,{'notifications 200':r=>r.status===200}));}
  sleep(1);
}
