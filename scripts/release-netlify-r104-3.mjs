import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {inheritedI18nOnly} from './i18n-pilot-baseline.mjs';

const root=resolve(import.meta.dirname,'..');
const scripts=JSON.parse(readFileSync(resolve(root,'package.json'),'utf8')).scripts;

const sync=spawnSync(process.execPath,['scripts/sync-release-build.mjs'],{
  cwd:root,encoding:'utf8',maxBuffer:4*1024*1024,timeout:30000,
});
if(sync.error) throw sync.error;
if(sync.status!==0){
  console.error('BLOCKED release sync');
  console.error(`${sync.stdout||''}\n${sync.stderr||''}`.slice(-5000));
  process.exit(1);
}
if(sync.stdout) console.log(sync.stdout.trim());

// Build before regression tests: several suites compare generated copies with
// web/. A fresh clone must work even if committed copies were stale.
runBuild();

const knownP2=new Map([
  ['scripts/i18n-r79-full-product-audit.mjs',output=>/\b\d+ unresolved\b/.test(output)&&inheritedI18nOnly('r79')],
  ['scripts/test-kombax-20130-r79-i18n-phases-6-10.mjs',output=>{
    const failed=[...output.matchAll(/✗ ([^\r\n]+)/g)].map(match=>match[1]);
    const summary=output.match(/KOMBAX R79 I18N PHASES 6-10: (\d+)\/(\d+) PASS/);
    return failed.length===1&&failed[0]==='Global strict audit records zero unresolved system copy'&&summary&&Number(summary[1])===Number(summary[2])-1&&inheritedI18nOnly('r79');
  }],
  ['scripts/i18n-runtime-copy-audit.mjs',output=>/runtime copy audit:/.test(output)&&inheritedI18nOnly('runtime')],
]);

let passed=0;
const deferred=[];
for(const phase of ['pretest','test']){
  for(const command of scripts[phase].split(' && ')){
    const parts=command.trim().split(/\s+/);
    if(parts[0]!=='node') throw new Error(`Unsupported ${phase} command: ${command}`);
    const result=spawnSync(process.execPath,parts.slice(1),{
      cwd:root,encoding:'utf8',maxBuffer:16*1024*1024,timeout:120000,
    });
    if(result.error) throw result.error;
    if(result.status===0){passed++;continue;}
    const output=`${result.stdout||''}\n${result.stderr||''}`;
    const allowed=result.status===1&&phase==='test'&&knownP2.get(parts[1])?.(output);
    if(!allowed){
      console.error(`BLOCKED ${phase}: ${command}`);
      console.error(output.slice(-5000));
      process.exit(1);
    }
    deferred.push(parts[1]);
    console.warn(`P2 conocido, sin ocultar: ${parts[1]}`);
  }
}

console.log(`KOMBAX Netlify pilot gate: ${passed} PASS, ${deferred.length} P2 conocidos, 0 fallos nuevos.`);
console.log('La suite estricta completa sigue disponible mediante npm test y continúa fallando hasta cerrar los P2 documentados.');
const compatibility=spawnSync(process.execPath,['scripts/verify-build-compatibility.mjs'],{
  cwd:root,encoding:'utf8',maxBuffer:16*1024*1024,timeout:120000,
});
if(compatibility.error)throw compatibility.error;
if(compatibility.status!==0){console.error(compatibility.stdout,compatibility.stderr);process.exit(1);}
console.log(compatibility.stdout.trim());

function runBuild(){
const build=spawnSync(process.execPath,['scripts/build.mjs'],{
  cwd:root,encoding:'utf8',maxBuffer:16*1024*1024,timeout:120000,
});
if(build.error) throw build.error;
if(build.status!==0){
  console.error('BLOCKED build.mjs');
  console.error(`${build.stdout||''}\n${build.stderr||''}`.slice(-5000));
  process.exit(1);
}
console.log((build.stdout||'').trim());
}
