import { spawnSync } from 'node:child_process';
import { existsSync, statSync, mkdirSync, copyFileSync } from 'node:fs';
import { resolve } from 'node:path';
import process from 'node:process';

const root=resolve(import.meta.dirname,'..');
const android=resolve(root,'android');

const run=(cmd,args,cwd=root)=>{
  console.log(`> ${cmd} ${args.join(' ')}`);
  const out=spawnSync(cmd,args,{cwd,stdio:'inherit',shell:false});
  if(out.error){
    console.error(`\nERROR al ejecutar ${cmd}: ${out.error.message}`);
    process.exit(1);
  }
  if(out.status!==0)process.exit(out.status??1);
};

const runGradle=(args)=>{
  if(process.platform==='win32'){
    // En Windows, los .bat deben ejecutarse a través de cmd.exe.
    const comspec=process.env.ComSpec||process.env.COMSPEC||'cmd.exe';
    run(comspec,['/d','/s','/c',['call','gradlew.bat',...args].join(' ')],android);
  }else{
    // No dependemos del permiso ejecutable preservado por el ZIP.
    run('sh',['./gradlew',...args],android);
  }
};

// 1) Misma fuente para Web/PWA y Android.
run(process.execPath,['scripts/build.mjs']);
// 2) Build limpio.
runGradle(['clean','assembleDebug']);
// 3) Cierre real: exigir APK y copiarlo con un nombre inequívoco de revisión.
const apk=resolve(android,'app/build/outputs/apk/debug/app-debug.apk');
if(!existsSync(apk) || statSync(apk).size<1024){
  console.error(`\nERROR: Gradle terminó pero no se encontró un APK válido en ${apk}`);
  process.exit(1);
}
const artifacts=resolve(root,'artifacts');
mkdirSync(artifacts,{recursive:true});
const namedApk=resolve(artifacts,'KOMBAX_20110_R62_8_SHOWCASE_EVENTS_COMMERCIAL_PILOT_QA_DEBUG.apk');
copyFileSync(apk,namedApk);
console.log('\nOK · KOMBAX R62.8 Showcase Events Commercial Pilot QA Android');
console.log('APK Gradle: android/app/build/outputs/apk/debug/app-debug.apk');
console.log('APK QA: artifacts/KOMBAX_20110_R62_8_SHOWCASE_EVENTS_COMMERCIAL_PILOT_QA_DEBUG.apk');
console.log('Android R62.8: versionCode 20110 · versionName 2.0.0-rc.13-r62.8-pilot');

// Historical QA artifact marker retained for R52.1/R52.2 regression: KOMBAX_20101_R52_2_SOCIAL_ANDROID_POSTER_FIX_DEBUG.apk
