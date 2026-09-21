import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
const [cfg,gradle,index,sw,app,backend,repos,admin,members,mig,verify,edge,pkg]=await Promise.all([
  read('web/config.js'),read('android/app/build.gradle'),read('web/index.html'),read('web/service-worker.js'),
  read('web/js/app.js'),read('web/js/core/backend.js'),read('web/js/core/repositories.js'),read('web/js/modules/admin.js'),
  read('web/js/modules/groups-members.js'),read('supabase/migrations/059_kombax_invitation_codes.sql'),
  read('supabase/verification/verify_059_invitation_codes.sql'),read('supabase/functions/invite-email/index.ts'),read('package.json')
]);
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL KOMBAX 20032: ${msg}`);console.log(`OK KOMBAX 20032: ${msg}`)};
assert(/build:\s*20032/.test(cfg)&&/versionCode 20032/.test(gradle)&&index.includes('?v=20032')&&sw.includes('20032'),'web, caché y Android usan build 20032');
assert(app.includes('Invitación de alumno')&&app.includes('Código de equipo')&&app.includes('app_kombax_invitacion_validar_v059'),'registro separa alumno/equipo y valida código antes de alta');
assert(backend.includes('app_kombax_invitacion_aceptar_equipo_v059')&&backend.includes('invite_code:input.invite_code'),'backend acepta EQP y pasa ALU al registro');
assert(repos.includes('createStudent')&&repos.includes('app_kombax_invitacion_crear_v059')&&repos.includes('invite-email'),'repositorios crean ambos tipos y disparan correo');
assert(admin.includes('EQP')&&admin.includes('Copiar código')&&members.includes('Invitar alumno')&&members.includes('ALU'),'UI del club expone los dos tipos de invitación');
assert(mig.includes("tipo_invitacion in ('alumno','equipo')")&&mig.includes("'ALU-'")&&mig.includes("'EQP-'")&&mig.includes("Solo el Gestor de la app puede invitar miembros del equipo"),'SQL tipa, genera códigos humanos y protege invitaciones de equipo');
assert(mig.includes("if v_age<16")===false,'059 no sustituye ni relaja la regla de edad existente');
assert(mig.includes("app_mutate_v160_pre_invites_059")&&mig.includes("tipo_invitacion='alumno'")&&mig.includes("invite_code"),'registro de alumno consume únicamente invitación ALU');
assert(edge.includes('RESEND_API_KEY')&&edge.includes('KOMBAX_INVITE_FROM')&&edge.includes('Código de invitación'),'Edge Function prepara email con código y enlace sin incluir secretos');
assert(verify.includes('codes_unique_ok')&&verify.includes('student_register_gate_ok'),'verificación cubre unicidad y gate de registro');
assert(pkg.includes('test-kombax-20032-invitations.mjs'),'suite incluye regresión 20032');
console.log('KOMBAX BUILD 20032 INVITATION CODES: PASS');
