import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,existsSync,readdirSync,unlinkSync,rmdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
const root=resolve(import.meta.dirname,'..');
const fixture=mkdtempSync(join(tmpdir(),'kombax-syntax-protocol-test-'));
const preload=join(fixture,'instrumentation.cjs');
const options=()=>[process.env.NODE_OPTIONS,`--require ${JSON.stringify(preload)}`].filter(Boolean).join(' ');
const verify=()=>spawnSync(process.execPath,['scripts/verify-build-compatibility.mjs'],{cwd:root,encoding:'utf8',env:{...process.env,NODE_OPTIONS:options()},timeout:120000,maxBuffer:4*1024*1024});
try{
  writeFileSync(preload,"if(process.argv[1]?.endsWith('check-web-module-syntax.mjs'))console.log('Fixture extra build output');\n");
  const noisy=verify();assert.ifError(noisy.error);assert.equal(noisy.status,0,noisy.stderr);assert.match(noisy.stdout,/PASS compatibility/);
  console.log('PASS extra child-process stdout does not corrupt the module count');
  writeFileSync(preload,"if(process.argv[1]?.endsWith('check-web-module-syntax.mjs'))process.on('exit',()=>require('node:fs').writeFileSync(process.argv[2],JSON.stringify({parsedModules:0})));\n");
  const incomplete=verify();assert.ifError(incomplete.error);assert.notEqual(incomplete.status,0);assert.match(incomplete.stderr,/Not every module was parsed/);
  console.log('PASS incomplete parsing remains a blocking failure');
  const invalid=join(fixture,'invalid.js'),report=join(fixture,'invalid-report.json');writeFileSync(invalid,'export const broken = ;');
  const syntax=spawnSync(process.execPath,['--experimental-vm-modules','--no-warnings','scripts/check-web-module-syntax.mjs',report],{cwd:root,input:JSON.stringify([invalid]),encoding:'utf8',env:{...process.env,NODE_OPTIONS:''},timeout:30000});
  assert.ifError(syntax.error);assert.notEqual(syntax.status,0);assert.match(syntax.stderr,/invalid\.js/);assert.equal(existsSync(report),false);
  console.log('PASS invalid JavaScript cannot produce a successful parser report');
}finally{
  for(const file of readdirSync(fixture))unlinkSync(join(fixture,file));
  rmdirSync(fixture);
}
