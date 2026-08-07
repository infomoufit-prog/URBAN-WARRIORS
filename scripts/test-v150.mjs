import fs from 'node:fs';
const sql=fs.readFileSync('supabase/migrations/010_family_multisport_firebase_final.sql','utf8');
const gradle=fs.readFileSync('android/app/build.gradle','utf8');
const service=fs.readFileSync('android/app/src/main/java/com/urbanwarriors/app/UrbanWarriorsMessagingService.java','utf8');
const config=fs.readFileSync('web/config.js','utf8');
const checks=[
  ['se elimina restricción antigua',sql.includes('drop constraint if exists socio_disciplinas_club_id_socio_id_disciplina_id_key')],
  ['matrícula alumno-disciplina-grupo',sql.includes('uq_socio_disciplina_grupo_activa')],
  ['aprobación no desactiva otras disciplinas',!sql.includes('disciplina_id<>p.disciplina_id')],
  ['solicitud de nueva matrícula',sql.includes('app_solicitar_nueva_matricula')],
  ['Firebase Messaging Android',gradle.includes('firebase-messaging')],
  ['servicio FCM',service.includes('FirebaseMessagingService')],
  ['versión compatible 1.5.x',/version:\s*'1\.5\.[0-9]+'/.test(config)]
];
for(const [name,ok] of checks){ if(!ok) throw new Error(`FALLO: ${name}`); console.log(`OK: ${name}`); }
