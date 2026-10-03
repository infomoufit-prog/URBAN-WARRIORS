import {existsSync,readdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {homedir} from 'node:os';
import {spawnSync} from 'node:child_process';

export function androidEnvironment(base=process.env){
  const env={...base};
  const javaName=process.platform==='win32'?'java.exe':'java';
  const probe=home=>{
    const command=home?resolve(home,'bin',javaName):'java';
    const result=spawnSync(command,['-version'],{encoding:'utf8',env,timeout:15000});
    const version=Number((result.stderr||result.stdout||'').match(/version "(\d+)/)?.[1]);
    return result.status===0&&version>=17&&version<=23;
  };
  if(!probe(env.JAVA_HOME)){
    const jdks=resolve(homedir(),'.jdks');
    const candidates=existsSync(jdks)?readdirSync(jdks,{withFileTypes:true}).filter(e=>e.isDirectory()).map(e=>resolve(jdks,e.name)):[];
    const compatible=candidates.find(probe);
    if(compatible)env.JAVA_HOME=compatible;
  }
  if(env.JAVA_HOME)env.PATH=resolve(env.JAVA_HOME,'bin')+(process.platform==='win32'?';':':')+(env.PATH||'');
  if(!env.ANDROID_HOME&&!env.ANDROID_SDK_ROOT&&process.platform==='win32'){
    const sdk=resolve(homedir(),'AppData/Local/Android/Sdk');
    if(existsSync(sdk))env.ANDROID_HOME=sdk;
  }
  return env;
}

export function runAndroidGradle(args,android){
  const env=androidEnvironment();
  const result=process.platform==='win32'
    ?spawnSync(env.ComSpec||env.COMSPEC||'cmd.exe',['/d','/s','/c',['call','gradlew.bat',...args].join(' ')],{cwd:android,env,stdio:'inherit'})
    :spawnSync('sh',['./gradlew',...args],{cwd:android,env,stdio:'inherit'});
  if(result.error)throw result.error;
  if(result.status!==0)process.exit(result.status??1);
}
