import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
const root=path.resolve(new URL('..',import.meta.url).pathname);
for(const n of [143,144,145,146,147,148,149]){const files=fs.readdirSync(path.join(root,'supabase/migrations')).filter(f=>f.startsWith(`${n}_`));assert.equal(files.length,1,`migration ${n}`);}
const idx=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'web/service-worker.js'),'utf8');
const cfg=fs.readFileSync(path.join(root,'web/config.js'),'utf8');
const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0);assert.ok(build>=20084);assert.ok(idx.includes(`./js/app.js?v=${build}`));assert.ok(idx.includes(`finance-premium-bootstrap.js?v=${build}`));
assert.ok(sw.includes(String(build)));
for(const f of ['docs/SECURITY_GO_LIVE_20084.md','docs/PILOT_QA_2_CLUBS_20_USERS_20084.md','docs/INCIDENT_RESPONSE_MINIMUM_20084.md','docs/SECURITY_ADVISOR_TRIAGE_20084.md','docs/AUTH_SECURITY_20084.md','docs/APPLY_20084_FULL_REPO.md','docs/SECRET_SCAN_20084.md','docs/THREAT_MODEL_20084.md','docs/PILOT_ACTIVATION_RUNBOOK_20084.md','SECURITY.md','android-security-20084/ANDROID_PATCH_20084.diff','android-security-20084/app/src/main/res/xml/network_security_config.xml','netlify.security-headers.20084.toml'])assert.ok(fs.existsSync(path.join(root,f)),f);
console.log('OK 20084 cumulative release contract');
