import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const fail=m=>{console.error('FAIL 20053 CLUB VERIFICATION:',m);process.exit(1)};
const ok=(c,m)=>{if(!c)fail(m)};
const gateway=read('web/js/modules/gateway.js');
const admin=read('web/js/modules/platform-admin.js');
const repos=read('web/js/core/repositories.js');
const migration=read('supabase/migrations/098_kombax_club_verification_20053.sql');
const rollback=read('supabase/rollbacks/098_kombax_club_verification_20053_rollback.sql');
const cfg=read('web/config.js');const sw=read('web/service-worker.js');const idx=read('web/index.html');const gradle=read('android/app/build.gradle');

ok(gateway.includes("name:'telefono',label:'Teléfono oficial · privado',required:true"),'Club exige teléfono oficial en formulario');
ok(gateway.includes("name:'forma_entidad',label:'Tipo de club / entidad · privado'")&&gateway.includes('Opcional en la verificación inicial'),'forma jurídica/CIF no se sobrerregula');
ok(gateway.includes("name:'tipo_acreditacion',label:'Tipo de acreditación'")&&gateway.includes("v.tipo_acreditacion||'Documento acreditativo'"),'acreditación de Club queda tipificada');
ok(/no (?:es obligatorio que sea|tiene que ser) documentación empresarial compleja/i.test(gateway),'ayuda de acreditación admite clubes pequeños/asociaciones/autónomos');

ok(admin.includes('clubVerificationStatus')&&admin.includes('Checklist previo a aprobación'),'Administrador recibe checklist estructurado');
ok(admin.includes('He comprobado que el club existe')&&admin.includes('He comprobado que esta persona puede representar al club')&&admin.includes('He revisado el documento acreditativo'),'Verificar exige comprobaciones administrativas');
ok(admin.includes("value==='verified'&&!clubStatus.complete"),'Verificar se oculta si faltan datos mínimos');
ok(admin.includes('data-verification-doc')&&repos.includes("verificationDocumentUrl:(path)=>backend.signedUrl('kombax-verification-docs'"),'Administrador puede abrir acreditación privada mediante URL firmada');
ok(admin.includes('[Checklist Club: identidad ✓ · representación ✓ · contacto ✓ · documento ✓]'),'checklist queda reflejado en observación/auditoría de revisión');

ok(migration.includes('app_kombax_club_payload_validate_v098')&&migration.includes("array_append(v_need,'telefono')"),'backend exige teléfono y datos mínimos');
ok(migration.includes('perform public.app_kombax_club_payload_validate_v098(v_req.nombre_publico,v_pub,v_ver)'),'submit/review usa validación reforzada');
ok(migration.includes('perform public.app_kombax_club_payload_validate_v098(p_nombre_publico,v_public,v_verify)'),'alta directa también usa validación reforzada');
ok(migration.includes('revoke all on function public.app_kombax_club_payload_validate_v098'),'helper interno no queda expuesto');
ok(rollback.includes('drop function if exists public.app_kombax_club_payload_validate_v098'),'rollback 098 disponible');

const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0),android=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),swBuild=Number(sw.match(/rc13-(\d+)/)?.[1]||0);const refs=[...idx.matchAll(/\?v=(\d+)/g)].map(x=>Number(x[1]));
ok(build>=20053&&android===build&&swBuild===build&&refs.length>0&&refs.every(v=>v===build),'web/PWA/Android conservan coherencia desde build 20053');
console.log('KOMBAX BUILD 20053 · Club verification: PASS');
