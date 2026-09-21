import { spawnSync } from 'node:child_process';
import { existsSync, statSync, mkdirSync, copyFileSync } from 'node:fs';
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

run(process.execPath,['scripts/build.mjs']);
run(process.execPath,['scripts/android-release-preflight.mjs']);
runGradle(['clean','bundleRelease']);
const aab=resolve(android,'app/build/outputs/bundle/release/app-release.aab');
if(!existsSync(aab) || statSync(aab).size<1024){console.error(`\nERROR: no se encontró AAB válido en ${aab}`);process.exit(1);}
const artifacts=resolve(root,'artifacts');
mkdirSync(artifacts,{recursive:true});
const namedAab=resolve(artifacts,'KOMBAX_20110_R62_8_SHOWCASE_EVENTS_COMMERCIAL_PILOT_QA_GOOGLE_PLAY.aab');
copyFileSync(aab,namedAab);
console.log('\nOK · KOMBAX R62.8 Showcase Events Commercial Pilot QA Google Play bundle');
console.log('AAB Gradle: android/app/build/outputs/bundle/release/app-release.aab');
console.log('AAB Play: artifacts/KOMBAX_20110_R62_8_SHOWCASE_EVENTS_COMMERCIAL_PILOT_QA_GOOGLE_PLAY.aab');
console.log('Android R62.8: versionCode 20110 · versionName 2.0.0-rc.13-r62.8-pilot');

// Historical QA artifact marker retained for R52.1/R52.2 regression: KOMBAX_20101_R52_2_SOCIAL_ANDROID_POSTER_FIX_GOOGLE_PLAY.aab
