import { access, readFile } from 'node:fs/promises';
import { constants } from 'node:fs';
import { isAbsolute, resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const android=resolve(root,'android');
const checks=[];
const add=(ok,label,detail='')=>checks.push({ok,label,detail});
const exists=async path=>{try{await access(path,constants.R_OK);return true}catch{return false}};

const gradle=await readFile(resolve(android,'app/build.gradle'),'utf8');
add(/applicationId 'com\.urbanwarriors\.app'/.test(gradle),'Identidad Android estable','com.urbanwarriors.app');
const versionCode=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
add(versionCode>=20021,'Versionado de actualización',`versionCode ${versionCode||'no detectado'}`);
add(await exists(resolve(android,'app/src/main/assets/www/index.html')),'Aplicación web embebida','assets/www presente');

const firebasePath=resolve(android,'app/google-services.json');
add(await exists(firebasePath),'Firebase para notificaciones push',
  await exists(firebasePath)?'configuración presente':'copia aquí el google-services.json real antes de compilar');

const propertiesPath=resolve(android,'keystore.properties');
if(await exists(propertiesPath)){
  const entries=Object.fromEntries((await readFile(propertiesPath,'utf8')).split(/\r?\n/)
    .map(line=>line.trim()).filter(line=>line&&!line.startsWith('#')&&line.includes('='))
    .map(line=>{const i=line.indexOf('=');return [line.slice(0,i).trim(),line.slice(i+1).trim()]}));
  for(const key of ['storeFile','storePassword','keyAlias','keyPassword']){
    const configured=Boolean(entries[key]&&!entries[key].includes('REEMPLAZAR'));
    add(configured,`Firma: ${key}`,configured?'configurado (valor oculto)':'pendiente');
  }
  if(entries.storeFile&&!entries.storeFile.includes('REEMPLAZAR')){
    const keystorePath=isAbsolute(entries.storeFile)?entries.storeFile:resolve(android,entries.storeFile);
    add(await exists(keystorePath),'Archivo de firma accesible',await exists(keystorePath)?'encontrado':'revisa storeFile');
  }
}else{
  add(false,'Firma local','copia android/keystore.properties.example como android/keystore.properties');
}

console.log(`\nUrban Warriors · preflight Android RC13 build ${versionCode||'desconocido'}\n`);
for(const check of checks)console.log(`${check.ok?'OK':'PENDIENTE'} · ${check.label}${check.detail?` — ${check.detail}`:''}`);
const pending=checks.filter(check=>!check.ok).length;
console.log(`\nResultado: ${checks.length-pending}/${checks.length} comprobaciones preparadas.`);
if(pending)console.log('No generes la release definitiva hasta resolver los elementos PENDIENTE.');
process.exitCode=pending?2:0;
