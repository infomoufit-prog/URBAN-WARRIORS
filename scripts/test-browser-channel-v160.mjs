import vm from 'node:vm';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const source = await readFile(resolve(root,'web/js/data-store.js'),'utf8');
const memory = new Map();
const localStorage = {
  getItem: (k) => memory.has(k) ? memory.get(k) : null,
  setItem: (k,v) => memory.set(k,String(v)),
  removeItem: (k) => memory.delete(k)
};
const clubId='11111111-1111-4111-8111-111111111111';
const userId='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
localStorage.setItem('uw_phase1_session_v2', JSON.stringify({ id:userId, club_id:clubId, rol:'direccion', roles:['direccion'] }));
localStorage.setItem('uw_supabase_session', JSON.stringify({ access_token:'REAL_USER_JWT', refresh_token:'REFRESH', expires_at:Math.floor(Date.now()/1000)+3600, user:{id:userId} }));
const calls=[];
let mismatch=false;
const fetch = async (url, options={}) => {
  calls.push({url:String(url), options});
  const body = options.body ? JSON.parse(options.body) : {};
  let response;
  if (String(url).endsWith('/rest/v1/rpc/app_runtime_contract_v160')) {
    response = mismatch
      ? {ok:true,backend_version:'9.9.9',schema_epoch:999,mutation_endpoint:'app_mutate_v160',club_id:clubId,user_id:userId,roles:['direccion'],write_ready:true}
      : {ok:true,backend_version:'1.6.0',schema_epoch:160,mutation_endpoint:'app_mutate_v160',club_id:clubId,user_id:userId,roles:['direccion'],write_ready:true};
  } else if (String(url).endsWith('/rest/v1/rpc/app_mutate_v160')) {
    response = {ok:true,backend_version:'1.6.0',operation:body.p_operation,request_id:body.p_request_id,data:{id:'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'}};
  } else if (String(url).endsWith('/rest/v1/rpc/app_write_channel_probe_v160')) {
    response = {ok:true,backend_version:'1.6.0',club_id:clubId,user_id:userId,gateway:true,contract:true};
  } else throw new Error(`Unexpected fetch ${url}`);
  return { ok:true, status:200, text:async()=>JSON.stringify(response) };
};
const cryptoObj = globalThis.crypto || (await import('node:crypto')).webcrypto;
const context = {
  window:{ UW_CONFIG:{ demoMode:false, clubSlug:'urban-warriors', primaryClubId:clubId, appName:'Urban Warriors', supabase:{enabled:true,url:'https://example.supabase.co',anonKey:'sb_publishable_TEST'}, release:{backendVersion:'1.6.0'}, brand:{} } },
  localStorage, fetch, crypto:cryptoObj, globalThis:null, console, setTimeout, clearTimeout, AbortController, Uint8Array, Date, Math, JSON, Error, Promise
};
context.globalThis=context;
vm.createContext(context);
vm.runInContext(source, context, {filename:'data-store.js'});
const store=context.window.UW_STORE;
const result=await store.mutate('disciplina.guardar',{nombre:'Prueba',descripcion:'',color:'#fff',activa:true,orden:1});
if (result.id !== 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') throw new Error('La mutación no devolvió el dato esperado');
if (calls.length !== 2) throw new Error(`Se esperaban contrato+gateway, hubo ${calls.length}`);
for (const call of calls) {
  const h=call.options.headers || {};
  if (h.apikey !== 'sb_publishable_TEST') throw new Error('Falta apikey publishable');
  if (h.Authorization !== 'Bearer REAL_USER_JWT') throw new Error(`Authorization incorrecta: ${h.Authorization}`);
}
if (!calls[1].url.endsWith('/rest/v1/rpc/app_mutate_v160')) throw new Error('La escritura no fue a app_mutate_v160');
const body=JSON.parse(calls[1].options.body);
if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(body.p_request_id)) throw new Error('request_id no es UUID v4');
if (body.p_payload.club_id !== clubId) throw new Error('El gateway no recibió club_id de sesión');

// Una web/backend desalineados deben bloquearse ANTES de intentar escribir.
calls.length=0; mismatch=true; store.backendContract=null;
let blocked=false;
try { await store.mutate('disciplina.guardar',{nombre:'No debe escribirse'}); } catch (e) { blocked=e.code==='BACKEND_CONTRACT'; }
if (!blocked) throw new Error('No se bloqueó el contrato incompatible');
if (calls.some(c=>c.url.endsWith('/rest/v1/rpc/app_mutate_v160'))) throw new Error('Se intentó escribir con backend incompatible');
console.log('OK: canal navegador → contrato → gateway usa apikey publishable + JWT real y bloquea versiones incompatibles.');
