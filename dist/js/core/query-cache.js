const entries=new Map();
const metrics=[];

export async function cached(key,loader,{ttl=15000,force=false}={}){
  const now=Date.now();const current=entries.get(key);
  if(!force&&current&&current.expires>now)return current.value;
  if(!force&&current?.promise)return current.promise;
  const started=performance.now();
  const promise=Promise.resolve().then(loader).then(value=>{
    entries.set(key,{value,expires:Date.now()+Math.max(0,Number(ttl)||0)});
    recordMetric(key,performance.now()-started,true);return value;
  }).catch(error=>{entries.delete(key);recordMetric(key,performance.now()-started,false);throw error;});
  entries.set(key,{promise,expires:0,value:current?.value});
  return promise;
}

export function cacheValue(key,value,ttl=15000){entries.set(key,{value,expires:Date.now()+Math.max(0,Number(ttl)||0)});return value}
export function peekCache(key){return entries.get(key)?.value}
export function invalidateCache(prefix=''){for(const key of entries.keys())if(!prefix||key.startsWith(prefix))entries.delete(key)}

function recordMetric(label,ms,ok){
  metrics.unshift({label:String(label),ms:Math.round(ms),ok,at:new Date().toISOString()});
  metrics.splice(120);
}

export function performanceSnapshot(){
  const rows=[...metrics];
  const sorted=rows.map(x=>x.ms).sort((a,b)=>a-b);
  const percentile=p=>sorted.length?sorted[Math.min(sorted.length-1,Math.max(0,Math.ceil(sorted.length*p)-1))]:0;
  return {count:rows.length,p50:percentile(.5),p95:percentile(.95),slow:rows.filter(x=>x.ms>5000).length,errors:rows.filter(x=>!x.ok).length,rows};
}
