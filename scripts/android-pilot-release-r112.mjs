import {spawnSync} from 'node:child_process';
import {existsSync, readFileSync, statSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';

const root=resolve(import.meta.dirname,'..');
const android=resolve(root,'android');
const run=(cmd,args,cwd=root)=>spawnSync(cmd,args,{cwd,encoding:'utf8',stdio:'inherit',shell:false});

const pre=run(process.execPath,['scripts/android-release-preflight.mjs']);
if(pre.status!==0){
  console.error('\nBLOCKED Android pilot release: resuelve todos los PENDIENTE del preflight.');
  process.exit(pre.status||2);
}

const wrapper=process.platform==='win32'?'gradlew.bat':'./gradlew';
const gradle=run(wrapper,['--no-daemon','clean','assembleRelease','bundleRelease'],android);
if(gradle.status!==0){
  console.error('\nBLOCKED Android pilot release: Gradle no terminó correctamente.');
  process.exit(gradle.status||3);
}

const gradleText=readFileSync(resolve(android,'app/build.gradle'),'utf8');
const code=Number(gradleText.match(/versionCode\s+(\d+)/)?.[1]||0);
const name=gradleText.match(/versionName\s+'([^']+)'/)?.[1]||'';
const apk=resolve(android,'app/build/outputs/apk/release/app-release.apk');
const aab=resolve(android,'app/build/outputs/bundle/release/app-release.aab');
for(const [kind,file] of [['APK',apk],['AAB',aab]]){
  if(!existsSync(file)||statSync(file).size<1024){
    console.error(`BLOCKED Android pilot release: ${kind} no generado o vacío: ${file}`);
    process.exit(4);
  }
  const sha=createHash('sha256').update(readFileSync(file)).digest('hex');
  console.log(`${kind} PASS · build ${code} · ${name} · ${statSync(file).size} bytes · SHA-256 ${sha}`);
}
console.log('ANDROID PILOT RELEASE: PASS · APK + AAB release generados y firmados por la configuración existente.');
