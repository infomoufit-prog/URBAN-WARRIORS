import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const fail=m=>{console.error('FAIL 20050 ACCOUNT SECURITY:',m);process.exit(1)};
const ok=(c,m)=>{if(!c)fail(m)};

const supa=read('web/js/core/supabase.js');
const backend=read('web/js/core/backend.js');
const security=read('web/js/modules/account-security.js');
const admin=read('web/js/modules/admin.js');
const portal=read('web/js/modules/portal.js');
const hub=read('web/js/modules/club-kombax-hub.js');
const gateway=read('web/js/modules/gateway.js');
const cfg=read('web/config.js');
const idx=read('web/index.html');
const sw=read('web/service-worker.js');
const gradle=read('android/app/build.gradle');
const pkg=read('package.json');

ok(backend.includes('changeOwnPassword')&&backend.includes('await client.signIn(email,current)'),'backend reautentica con contraseña actual');
ok(backend.includes("String(auth?.user?.id||'')!==expectedUserId"),'backend impide cambiar contraseña de una identidad distinta');
ok(backend.includes('await client.updatePassword(next)'),'backend cambia contraseña solo después de reautenticar');
ok(backend.includes('La contraseña actual no es correcta'),'error de contraseña actual tiene UX explícita');
ok(backend.includes('await client.signOut()')&&backend.includes('persistSession(null)'),'sesión se cierra después de cambio correcto');
ok(security.includes("name:'current_password'")&&security.includes("name:'new_password'")&&security.includes("name:'new_password_repeat'"),'formulario solicita actual, nueva y confirmación');
ok(security.includes('next.length<8')&&security.includes('current===next')&&security.includes('next!==values.new_password_repeat'),'cliente valida mínimo, diferencia y confirmación');
ok(security.includes("autocomplete','current-password'")&&security.includes("autocomplete','new-password'"),'campos usan autocomplete semántico seguro');
ok(admin.includes('Seguridad y acceso')&&admin.includes('change-account-password'),'perfil personal expone cambio de contraseña');
ok(portal.includes('portal-change-password')&&portal.includes('openAuthenticatedPasswordChange'),'portal Alumno expone cambio de contraseña');
ok(hub.includes("card('security','Seguridad y acceso'")&&hub.includes("a==='security'"),'Gestor/Coordinación lo encuentran desde Perfil del Club');
ok(gateway.includes('kx-global-change-password')&&gateway.includes('openAuthenticatedPasswordChange'),'cuenta KOMBAX global expone cambio de contraseña');
ok(!security.includes('service_role')&&!backend.includes('SUPABASE_SERVICE_ROLE_KEY'),'cambio de contraseña no usa secretos privilegiados');

const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0),android=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
ok(build>=20050,'config build 20050+');
ok(android>=20050,'Android versionCode 20050+');
ok(Number(idx.match(/\?v=(\d+)/)?.[1]||0)>=20050,'cache busting web 20050+');
ok(Number(sw.match(/rc13-(\d+)/)?.[1]||0)>=20050,'service worker 20050+');
ok(pkg.includes('test-kombax-20050-account-security.mjs'),'suite principal incluye regresión 20050');

// Behavioral REST contract: current password must be verified before PUT /user.
const memory=new Map();
globalThis.localStorage={getItem:k=>memory.has(k)?memory.get(k):null,setItem:(k,v)=>memory.set(k,String(v)),removeItem:k=>memory.delete(k)};
const calls=[];
globalThis.fetch=async(url,options={})=>{
  calls.push({url:String(url),method:options.method||'GET',headers:options.headers||{},body:options.body||''});
  const u=new URL(String(url));
  if(u.pathname.endsWith('/auth/v1/token')&&u.searchParams.get('grant_type')==='password')return new Response(JSON.stringify({access_token:'fresh-access',refresh_token:'fresh-refresh',expires_in:3600,user:{id:'same-user',email:'test@example.com'}}),{status:200,headers:{'content-type':'application/json'}});
  if(u.pathname.endsWith('/auth/v1/user'))return new Response(JSON.stringify({id:'same-user',email:'test@example.com'}),{status:200,headers:{'content-type':'application/json'}});
  if(u.pathname.endsWith('/auth/v1/logout'))return new Response(null,{status:204});
  return new Response(JSON.stringify({message:'unexpected path'}),{status:500,headers:{'content-type':'application/json'}});
};
const {SupabaseClient}=await import('../web/js/core/supabase.js');
const c=new SupabaseClient({url:'https://example.supabase.test',anonKey:'publishable-test'});
await c.signIn('test@example.com','current-password');
await c.updatePassword('new-password-20050');
await c.signOut();
const token=calls.find(x=>x.url.includes('/auth/v1/token?grant_type=password'));
const user=calls.find(x=>x.url.endsWith('/auth/v1/user'));
const logout=calls.find(x=>x.url.endsWith('/auth/v1/logout'));
ok(token?.method==='POST'&&String(token.body).includes('current-password'),'contraseña actual se verifica contra Auth');
ok(user?.method==='PUT'&&user.headers.Authorization==='Bearer fresh-access'&&String(user.body).includes('new-password-20050'),'nueva contraseña se actualiza con sesión recién reautenticada');
ok(logout?.method==='POST'&&logout.headers.Authorization==='Bearer fresh-access','sesión recién usada se revoca al finalizar');
ok(c.session===null,'cliente queda sin sesión tras cambio');
console.log('KOMBAX BUILD 20050 · authenticated password change: PASS');
