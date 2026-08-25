import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
const root=path.resolve(new URL('..',import.meta.url).pathname);
const docs=['docs/SECURITY_GO_LIVE_20084.md','docs/PILOT_QA_2_CLUBS_20_USERS_20084.md','docs/INCIDENT_RESPONSE_MINIMUM_20084.md','docs/SECURITY_ADVISOR_TRIAGE_20084.md','android-security-20084/ANDROID_PATCH_20084.diff','netlify.security-headers.20084.toml'];
for(const f of docs)assert.ok(fs.existsSync(path.join(root,f)),f);
const q=fs.readFileSync(path.join(root,'docs/PILOT_QA_2_CLUBS_20_USERS_20084.md'),'utf8');
for(const x of ['club_id','socio_id','cuota_id','contacto_id','Storage privado','0 cruces de tenant'])assert.ok(q.includes(x),x);
console.log('OK 20084 pilot release matrix');

const ad=fs.readFileSync(path.join(root,'android-security-20084/ANDROID_PATCH_20084.diff'),'utf8');
for(const x of ['versionCode 20084','networkSecurityConfig','WebView.setWebContentsDebuggingEnabled(false)','setSafeBrowsingEnabled(true)','block cleartext http'])assert.ok(ad.includes(x),x);
const net=fs.readFileSync(path.join(root,'netlify.security-headers.20084.toml'),'utf8');
for(const x of ['X-Permitted-Cross-Domain-Policies','Origin-Agent-Cluster','no-cache, no-store'])assert.ok(net.includes(x),x);
console.log('OK 20084 Android/Netlify hardening contract');
