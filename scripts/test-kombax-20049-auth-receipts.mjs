import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const fail=m=>{console.error('FAIL 20049 AUTH + RECEIPTS:',m);process.exit(1)};
const ok=(c,m)=>{if(!c)fail(m)};

const supa=read('web/js/core/supabase.js');
const backend=read('web/js/core/backend.js');
const recovery=read('web/js/modules/auth-recovery.js');
const app=read('web/js/app.js');
const gateway=read('web/js/modules/gateway.js');
const finance=read('web/js/modules/finance.js');
const components=read('web/js/ui/components.js');
const mig=read('supabase/migrations/096_kombax_multiclub_receipt_branding_20049.sql');
const verify=read('supabase/verification/verify_096_kombax_multiclub_receipt_branding_20049.sql');
const template=read('supabase/auth_templates/recovery_otp_20049.html');
const templateReadme=read('supabase/auth_templates/README_20049.md');
const cfg=read('web/config.js');
const idx=read('web/index.html');
const sw=read('web/service-worker.js');
const gradle=read('android/app/build.gradle');

// Password recovery: Supabase native recovery OTP, no user creation and no privileged key.
ok(supa.includes("'/auth/v1/recover'")&&supa.includes('requestPasswordRecovery'),'cliente solicita recovery nativo');
ok(supa.includes("'/auth/v1/verify'")&&supa.includes("type:'recovery'")&&supa.includes('verifyPasswordRecovery'),'cliente verifica OTP recovery');
ok(supa.includes("'/auth/v1/user'")&&supa.includes("method:'PUT'")&&supa.includes('updatePassword'),'cambio de contraseña usa sesión temporal autenticada');
ok(!recovery.includes('service_role')&&!backend.includes('SUPABASE_SERVICE_ROLE_KEY'),'recuperación no usa secretos privilegiados en frontend');
ok(backend.includes('requestPasswordRecovery')&&backend.includes('user.*not found')&&backend.includes('accepted:true'),'solicitud evita enumeración de cuentas');
ok(backend.includes("if(!/^\\d{6}$/.test(code))")&&backend.includes('next.length<8'),'backend valida OTP de 6 dígitos y contraseña mínima');
ok(backend.includes('await client.signOut()')&&backend.includes('persistSession(null)'),'sesión temporal se cierra después del proceso');
ok(recovery.includes('Si existe una cuenta con ese correo')&&recovery.includes('Reenviar código'),'UX usa respuesta neutra y permite reenvío');
ok(app.includes('forgot-password-btn')&&app.includes('openPasswordRecovery'),'login de Club expone recuperar contraseña');
ok(gateway.includes('He olvidado mi contraseña')&&gateway.includes('openPasswordRecovery'),'login KOMBAX global expone recuperar contraseña');
ok(template.includes('{{ .Token }}')&&!template.includes('{{ .ConfirmationURL }}'),'plantilla recovery entrega código OTP, no depende de enlace');
ok(templateReadme.includes('Authentication → Email Templates → Reset password'),'paquete documenta configuración hosted de plantilla');

// Financial receipt branding: immutable issuer snapshot and club-specific numbering.
ok(mig.includes('add column if not exists recibo_prefijo')&&mig.includes("slug='urban-warriors' then 'UW'"),'cada club dispone de prefijo estable y Urban conserva UW');
ok(mig.includes('emisor_nombre')&&mig.includes('emisor_logo_url')&&mig.includes('emisor_cif')&&mig.includes('emisor_direccion'),'recibo guarda snapshot de emisor');
ok(mig.includes("coalesce(nullif(c.logo_url,''),nullif(p.logo_url,''))"),'logo de recibo resuelve branding Club o perfil público');
ok(mig.includes('before insert on public.recibos_cuota')&&mig.includes('new.numero:=v_prefix'),'trigger aplica snapshot y numeración antes de emitir');
ok(mig.includes('Backfill')&&mig.includes('where r.club_id=c.id'),'históricos reciben branding sin renumerarse');
ok(verify.includes('historicos_backfill_ok')&&verify.includes('trigger_branding_ok'),'verificación SQL cubre snapshot histórico y trigger');
ok(finance.includes('receiptIssuer')&&finance.includes('r?.emisor_logo_url')&&finance.includes("'./assets/kombax-symbol.png'"),'renderer usa snapshot y fallback KOMBAX');
ok(!finance.includes('urban-warriors-logo.png'),'recibo ya no contiene fallback Warriors');
ok(components.includes('KOMBAX_BRAND.symbol')&&!components.includes("'./assets/urban-warriors-logo.png'"),'shell multiclub tampoco hereda logo Warriors');
ok(!components.includes("||'UW'"),'iniciales genéricas ya no usan UW');

const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0),android=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
ok(build>=20049,'config build conserva 20049 o posterior');
ok(android>=20049,'Android versionCode conserva 20049 o posterior');
ok(idx.includes(`?v=${build}`),'cache busting coincide con build actual');
ok(sw.includes(`uw2-2.0.0-rc13-${build}`),'service worker coincide con build actual');
console.log('KOMBAX BUILD 20049 · password recovery OTP + multi-club receipts: PASS');

// Behavioral contract for the custom GoTrue REST client. No network is used.
const memory=new Map();
globalThis.localStorage={getItem:k=>memory.has(k)?memory.get(k):null,setItem:(k,v)=>memory.set(k,String(v)),removeItem:k=>memory.delete(k)};
const calls=[];
globalThis.fetch=async(url,options={})=>{
  calls.push({url:String(url),method:options.method||'GET',headers:options.headers||{},body:options.body||''});
  const path=new URL(String(url)).pathname;
  if(path.endsWith('/auth/v1/recover'))return new Response('{}',{status:200,headers:{'content-type':'application/json'}});
  if(path.endsWith('/auth/v1/verify'))return new Response(JSON.stringify({access_token:'recovery-access',refresh_token:'recovery-refresh',expires_in:3600,user:{id:'test-user',email:'test@example.com'}}),{status:200,headers:{'content-type':'application/json'}});
  if(path.endsWith('/auth/v1/user'))return new Response(JSON.stringify({id:'test-user',email:'test@example.com'}),{status:200,headers:{'content-type':'application/json'}});
  if(path.endsWith('/auth/v1/logout'))return new Response(null,{status:204});
  return new Response(JSON.stringify({message:'unexpected path'}),{status:500,headers:{'content-type':'application/json'}});
};
const {SupabaseClient}=await import('../web/js/core/supabase.js');
const authClient=new SupabaseClient({url:'https://example.supabase.test',anonKey:'publishable-test'});
await authClient.requestPasswordRecovery('test@example.com');
await authClient.verifyPasswordRecovery('test@example.com','123456');
await authClient.updatePassword('password-20049');
await authClient.signOut();
const recoverCall=calls.find(x=>x.url.endsWith('/auth/v1/recover'));
const verifyCall=calls.find(x=>x.url.endsWith('/auth/v1/verify'));
const userCall=calls.find(x=>x.url.endsWith('/auth/v1/user'));
const logoutCall=calls.find(x=>x.url.endsWith('/auth/v1/logout'));
ok(recoverCall?.method==='POST'&&!recoverCall.headers.Authorization,'recovery se solicita sin sesión previa');
ok(verifyCall?.method==='POST'&&!verifyCall.headers.Authorization&&String(verifyCall.body).includes('"type":"recovery"'),'OTP recovery se verifica sin token previo');
ok(userCall?.method==='PUT'&&userCall.headers.Authorization==='Bearer recovery-access','cambio de contraseña exige la sesión recovery verificada');
ok(logoutCall?.method==='POST'&&logoutCall.headers.Authorization==='Bearer recovery-access','sesión recovery se revoca al terminar');
ok(authClient.session===null&&!memory.has('uw2_supabase_session'),'sesión temporal no queda persistida tras el cambio');
console.log('KOMBAX BUILD 20049 · behavioral auth REST contract: PASS');
