import { access, readFile } from 'node:fs/promises';
import { constants } from 'node:fs';
import { isAbsolute, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { androidEnvironment } from './android-toolchain.mjs';

const root=resolve(import.meta.dirname,'..');
const android=resolve(root,'android');
const checks=[];
const add=(ok,label,detail='')=>checks.push({ok,label,detail});
const exists=async path=>{try{await access(path,constants.R_OK);return true}catch{return false}};

const gradle=await readFile(resolve(android,'app/build.gradle'),'utf8');
const webConfig=await readFile(resolve(root,'web/config.js'),'utf8');
const activity=await readFile(resolve(android,'app/src/main/java/com/urbanwarriors/app/MainActivity.java'),'utf8');
add(/applicationId 'com\.urbanwarriors\.app'/.test(gradle),'Identidad Android estable','com.urbanwarriors.app');
const versionCode=Number(gradle.match(/^\s*versionCode\s+(\d+)\s*$/m)?.[1]||0);
add(versionCode>=20021,'Versionado de actualización',`versionCode ${versionCode||'no detectado'}`);
add(new RegExp(`build: ${versionCode}\\b`).test(webConfig)&&activity.includes(`KOMBAXApp/2.0.0-rc.13/${versionCode}`),
  'Misma versión en web y Android','config.js y User-Agent');
add(await exists(resolve(android,'app/src/main/assets/www/index.html')),'Aplicación web embebida','assets/www presente');
const gradlewPath=resolve(android,process.platform==='win32'?'gradlew.bat':'gradlew');
const gradlewExecutable=await exists(gradlewPath);
add(gradlewExecutable,'Gradle wrapper disponible',process.platform==='win32'?'gradlew.bat presente':'android/gradlew disponible; se ejecuta mediante sh');

const toolchain=androidEnvironment();
const javaPath=toolchain.JAVA_HOME?resolve(toolchain.JAVA_HOME,'bin',process.platform==='win32'?'java.exe':'java'):'java';
const java=spawnSync(javaPath,['-version'],{encoding:'utf8',env:toolchain});
const javaVersion=Number((`${java.stderr||''}\n${java.stdout||''}`).match(/version "(\d+)/)?.[1]||0);
add(java.status===0&&javaVersion>=17&&javaVersion<=23,'Java compatible con Gradle 8.11.1',
  javaVersion?`Java ${javaVersion} · selecciona JDK 17 o 21 en Android Studio`:'Java no disponible');
const sdk=toolchain.ANDROID_HOME||toolchain.ANDROID_SDK_ROOT;
add(Boolean(sdk)&&await exists(resolve(sdk,'platforms/android-36/android.jar')),'Android SDK 36',sdk?'SDK localizado':'configura ANDROID_HOME');

const firebasePath=resolve(android,'app/google-services.json');
add(await exists(firebasePath),'Firebase para notificaciones push',
  await exists(firebasePath)?'configuración presente':'copia aquí el google-services.json real antes de compilar');

const propertiesPath=resolve(android,'keystore.properties');
if(await exists(propertiesPath)){
  const entries=Object.fromEntries((await readFile(propertiesPath,'utf8')).split(/\r?\n/)
    .map(line=>line.trim()).filter(line=>line&&!line.startsWith('#')&&line.includes('='))
    .map(line=>{const i=line.indexOf('=');return [line.slice(0,i).trim(),line.slice(i+1).trim()]}));
  const envKeys={storeFile:'UW_KEYSTORE_PATH',storePassword:'UW_KEYSTORE_PASSWORD',keyAlias:'UW_KEY_ALIAS',keyPassword:'UW_KEY_PASSWORD'};
  for(const key of Object.keys(envKeys)){
    const configured=Boolean((entries[key]&&!entries[key].includes('REEMPLAZAR'))||process.env[envKeys[key]]);
    add(configured,`Firma: ${key}`,configured?'configurado (valor oculto)':'pendiente');
  }
  const storeFile=(entries.storeFile&&!entries.storeFile.includes('REEMPLAZAR'))?entries.storeFile:process.env.UW_KEYSTORE_PATH;
  if(storeFile){
    const keystorePath=isAbsolute(storeFile)?storeFile:resolve(android,storeFile);
    add(await exists(keystorePath),'Archivo de firma accesible',await exists(keystorePath)?'encontrado':'revisa storeFile');
  }
}else if(['UW_KEYSTORE_PATH','UW_KEYSTORE_PASSWORD','UW_KEY_ALIAS','UW_KEY_PASSWORD'].every(key=>Boolean(process.env[key]))){
  const keystorePath=isAbsolute(process.env.UW_KEYSTORE_PATH)?process.env.UW_KEYSTORE_PATH:resolve(android,process.env.UW_KEYSTORE_PATH);
  add(await exists(keystorePath),'Firma mediante variables UW_*',await exists(keystorePath)?'configurada (valores ocultos)':'archivo no encontrado');
}else{
  add(false,'Firma local','configura android/keystore.properties o las variables UW_*');
}

console.log(`\nUrban Warriors · preflight Android RC13 build ${versionCode||'desconocido'}\n`);
for(const check of checks)console.log(`${check.ok?'OK':'PENDIENTE'} · ${check.label}${check.detail?` — ${check.detail}`:''}`);
const pending=checks.filter(check=>!check.ok).length;
console.log(`\nResultado: ${checks.length-pending}/${checks.length} comprobaciones preparadas.`);
if(pending)console.log('No generes la release definitiva hasta resolver los elementos PENDIENTE.');
process.exitCode=pending?2:0;
