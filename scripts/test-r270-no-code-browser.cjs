const {chromium}=require(process.env.KOMBAX_PLAYWRIGHT_PATH||'C:/Users/Bryan Work/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});const checks=[];try{
for(const width of [390,1280]){const page=await browser.newPage({viewport:{width,height:900},serviceWorkers:'block'});
await page.route('**/*',async r=>{const u=new URL(r.request().url());if(u.hostname!=='127.0.0.1')return r.fulfill({status:200,contentType:'application/json',body:'[]'});
if(u.pathname==='/')return r.fulfill({contentType:'text/html',body:'<!doctype html><html><meta name="viewport" content="width=device-width,initial-scale=1"><script src="/config.js"></script><link rel="stylesheet" href="/css/app.css"><body><div id="app"></div></body></html>'});
const file=path.resolve('web','.'+u.pathname);if(!file.startsWith(path.resolve('web')+path.sep)||!fs.existsSync(file))return r.fulfill({status:404,body:''});
let body=fs.readFileSync(file);if(u.pathname==='/js/modules/gateway.js')body=Buffer.from(body.toString()+'\nexport {openMemberClubLink as qaOpenMemberClubLink};');
return r.fulfill({body,contentType:u.pathname.endsWith('.js')?'text/javascript':u.pathname.endsWith('.css')?'text/css':undefined});});
await page.goto('http://127.0.0.1:4189/');await page.evaluate(async()=>{const {state}=await import('/js/core/state.js'),{repos}=await import('/js/core/repositories.js'),{qaOpenMemberClubLink}=await import('/js/modules/gateway.js');state.session={scope:'kombax',id:'qa'};window.qaCalls=[];repos.kombaxMemberships.pending=async()=>[];repos.kombaxMemberships.active=async()=>[];repos.kombaxMemberships.contactClub=async(...args)=>{window.qaCalls.push(args);return {already_pending:false}};await qaOpenMemberClubLink({id:'qa-club',nombre:'Club QA'},{})});
assert.equal(await page.locator('#f-request_kind').inputValue(),'member');checks.push(`${width}: default member selected`);
await page.locator('#f-request_kind').selectOption('family');await page.locator('#f-mensaje').fill('Solicito acceso como familiar para mi hijo.');
assert.equal(await page.locator('#modal-submit').textContent(),'Enviar solicitud al club');checks.push(`${width}: current request button`);
assert.equal(await page.locator('input[name*="code"]').count(),0);checks.push(`${width}: no invitation code required`);
const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+2);assert.equal(overflow,false);checks.push(`${width}: no horizontal overflow`);
fs.mkdirSync('docs/qa/r270-netlify',{recursive:true});await page.screenshot({path:`docs/qa/r270-netlify/no-code-${width}.png`,fullPage:true});
await page.locator('#modal-submit').click();await page.waitForFunction(()=>window.qaCalls.length===1);assert.deepEqual(await page.evaluate(()=>window.qaCalls[0]),['qa-club','Solicito acceso como familiar para mi hijo.','family']);checks.push(`${width}: correct club and family intent submitted`);
await page.close();}
fs.writeFileSync('docs/qa/r270-netlify/browser.json',JSON.stringify({passed:checks.length,checks,transport:'mocked; no real accounts, requests or payments'},null,2));console.log(`PASS ${checks.length} browser checks`);
}finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1});
