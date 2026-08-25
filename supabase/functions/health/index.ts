import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const json=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{
  status,
  headers:{
    'content-type':'application/json; charset=utf-8',
    'cache-control':'no-store, max-age=0',
    'x-content-type-options':'nosniff'
  }
});

Deno.serve(async(req:Request)=>{
  if(req.method!=='GET'&&req.method!=='HEAD') return json(405,{ok:false,status:'method_not_allowed'});
  const base=(Deno.env.get('SUPABASE_URL')||'').replace(/\/+$/,'');
  const key=Deno.env.get('SUPABASE_ANON_KEY')||'';
  if(!base||!key) return json(503,{ok:false,status:'degraded',build:20086,db:'unavailable'});
  let db='unavailable';
  try{
    const r=await fetch(`${base}/rest/v1/rpc/app_kombax_showcase_categorias_v042`,{
      method:'POST',
      headers:{apikey:key,authorization:`Bearer ${key}`,'content-type':'application/json'},
      body:'{}',
      signal:AbortSignal.timeout(3500)
    });
    db=r.ok?'ok':'unavailable';
  }catch{ db='unavailable'; }
  const ok=db==='ok';
  const body={ok,status:ok?'ok':'degraded',build:20086,db,checked_at:new Date().toISOString()};
  if(req.method==='HEAD') return new Response(null,{status:ok?200:503,headers:{'cache-control':'no-store','x-kombax-health':ok?'ok':'degraded','x-kombax-build':'20086'}});
  return json(ok?200:503,body);
});
