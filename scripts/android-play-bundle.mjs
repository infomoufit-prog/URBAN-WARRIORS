import { spawnSync } from 'node:child_process';
import { existsSync, statSync, mkdirSync, copyFileSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import process from 'node:process';

const root=resolve(import.meta.dirname,'..');
const android=resolve(root,'android');
const run=(cmd,args,cwd=root)=>{
  console.log(`> ${cmd} ${args.join(' ')}`);
  const out=spawnSync(cmd,args,{cwd,stdio:'inherit',shell:false});
  if(out.error){console.error(`\nERROR al ejecutar ${cmd}: ${out.error.message}`);process.exit(1);}
  if(out.status!==0)process.exit(out.status??1);
};
const runGradle=(args)=>{
  if(process.platform==='win32'){
    const comspec=process.env.ComSpec||process.env.COMSPEC||'cmd.exe';
    run(comspec,['/d','/s','/c',['call','gradlew.bat',...args].join(' ')],android);
  }else run('sh',['./gradlew',...args],android);
};

const gradle=readFileSync(resolve(android,'app/build.gradle'),'utf8');
const versionCode=gradle.match(/^\s*versionCode\s+(\d+)\s*$/m)?.[1];
if(!versionCode)throw new Error('No se pudo leer versionCode de android/app/build.gradle');
run(process.execPath,['scripts/release-legal-gate.mjs']);
run(process.execPath,['scripts/release-netlify-r104-3.mjs']);
run(process.execPath,['scripts/android-release-preflight.mjs']);
runGradle(['clean',':app:assembleRelease',':app:bundleRelease']);
const aab=resolve(android,'app/build/outputs/bundle/release/app-release.aab');
const apk=resolve(android,'app/build/outputs/apk/release/app-release.apk');
if(!existsSync(aab) || statSync(aab).size<1024){console.error(`\nERROR: no se encontró AAB válido en ${aab}`);process.exit(1);}
if(!existsSync(apk) || statSync(apk).size<1024){console.error(`\nERROR: no se encontró APK válido en ${apk}`);process.exit(1);}
const artifacts=resolve(root,'artifacts');
mkdirSync(artifacts,{recursive:true});
const namedAab=resolve(artifacts,`KOMBAX_${versionCode}_R104_3_PILOT_GOOGLE_PLAY.aab`);
const namedApk=resolve(artifacts,`KOMBAX_${versionCode}_R104_3_PILOT_SIGNED.apk`);
copyFileSync(aab,namedAab);
copyFileSync(apk,namedApk);
console.log(`\nOK · KOMBAX R104.3 build ${versionCode} · Android release`);
console.log('AAB Gradle: android/app/build/outputs/bundle/release/app-release.aab');
console.log(`AAB Play: ${namedAab}`);
console.log(`APK firmada: ${namedApk}`);

// Historical QA artifact marker retained for R52.1/R52.2 regression: KOMBAX_20101_R52_2_SOCIAL_ANDROID_POSTER_FIX_GOOGLE_PLAY.aab

// Historical release artifact marker retained for R60/R62.8 regression: KOMBAX_20110_R62_8_SHOWCASE_EVENTS_COMMERCIAL_PILOT_QA_GOOGLE_PLAY.aab

// Historical release marker: KOMBAX_20142_R89_PILOT_GOOGLE_PLAY.aab
