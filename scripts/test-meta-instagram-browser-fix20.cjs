const {chromium}=require(process.env.KOMBAX_PLAYWRIGHT_PATH||'C:/Users/Bryan Work/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.KOMBAX_BROWSER_PATH||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
 const checks=[];try{
  for(const width of [390,1280]){
   const page=await browser.newPage({viewport:{width,height:844},serviceWorkers:'block'}),errors=[];
   page.on('pageerror',e=>errors.push(e.message));
   await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.fulfill({status:200,body:'[]',contentType:'application/json'}));
   await page.goto('http://127.0.0.1:4175/');
   const result=await page.evaluate(async()=>{
    const {backend}=await import('/js/core/backend.js'),{state}=await import('/js/core/state.js'),{setAppHtml,closeModal}=await import('/js/ui/components.js');
    const {openInstagramIntegration,publishPostToInstagram}=await import('/js/modules/instagram-integration.js');
    state.session={id:'qa-user',scope:'kombax',rol:'global'};setAppHtml('<main id="main-view"></main>');
    const checks=[],calls=[];const ok=(n,v)=>{if(!v)throw new Error(n);checks.push(n);};
    const tick=()=>new Promise(r=>setTimeout(r,120));
    const first={id:'40000000-0000-4000-8000-000000000001',nombre_publico:'QA Brand A'},second={id:'40000000-0000-4000-8000-000000000002',nombre_publico:'QA Brand B'};
    backend.invokeFunction=async(name,body)=>{calls.push({name,...body});return body.action==='status'?{status:'connected',username:body.social_id===first.id?'brand_a':'brand_b',publications:[]}:{ok:true,job:{status:'published',media_id:'601'}};};
    window.UW_CONFIG.integrations={instagram:{enabled:false}};
    await openInstagramIntegration(first);ok('disabled rollout makes no backend requests',calls.length===0);ok('configuration pending visible',document.body.textContent.includes('Integración preparada para pruebas'));closeModal();
    window.UW_CONFIG.integrations.instagram.enabled=true;
    await openInstagramIntegration(first);ok('first identity selected exactly',calls.at(-1).social_id===first.id);ok('first connected account visible',document.body.textContent.includes('@brand_a'));closeModal();
    await openInstagramIntegration(second);ok('second identity never falls back to first',calls.at(-1).social_id===second.id);ok('second connected account visible',document.body.textContent.includes('@brand_b'));closeModal();
    const post={id:'50000000-0000-4000-8000-000000000001',autor_id:first.id,texto:'QA <unsafe>'};
    await publishPostToInstagram(post,second);ok('different identity cannot invoke publishing dialog',!document.querySelector('[data-instagram-publish]'));
    await publishPostToInstagram(post,first);ok('external publication needs explicit confirmation',!calls.some(c=>c.action==='publish'));ok('caption escaped',!document.querySelector('unsafe'));
    document.querySelector('[data-instagram-publish]').click();await tick();ok('publishes selected post and identity with confirmation',calls.some(c=>c.action==='publish'&&c.social_id===first.id&&c.post_id===post.id&&c.confirm===true));
    await openInstagramIntegration(second);document.querySelector('[data-instagram-disconnect]').click();await tick();ok('disconnect confirmation shown',document.body.textContent.includes('No elimina publicaciones'));closeModal();
    backend.invokeFunction=async()=>{throw new Error('TOKEN_SQL_PRIVATE_DETAIL');};await openInstagramIntegration(first);ok('technical failure hidden',!document.body.textContent.includes('TOKEN_SQL_PRIVATE_DETAIL'));closeModal();
    ok('mobile layout has no horizontal overflow',document.documentElement.scrollWidth<=innerWidth+2);
    return {checks,calls};
   });
   checks.push(...result.checks.map(x=>`${width}: ${x}`));
   assert.equal(errors.length,0,errors.join('\n'));
   // Exercise the actual return page with only the backend transport replaced.
   const returnSource=fs.readFileSync(path.join(__dirname,'../web/js/meta-instagram-return.js'),'utf8');
   await page.route('**/js/meta-instagram-return.js',r=>r.fulfill({contentType:'text/javascript',body:returnSource.replace("const root=document.getElementById",`backend.restore=async()=>{state.session={id:'qa-user'};};backend.invokeFunction=async(name,body)=>body.action==='finish'?{accounts:[{page_id:'101',page_name:'QA Page A',username:'account_a'},{page_id:'102',page_name:'QA Page B',username:'account_b'}]}:{ok:true};\nconst root=document.getElementById`)}));
   await page.addInitScript(()=>sessionStorage.setItem('kx_meta_flow:70000000-0000-4000-8000-000000000001',JSON.stringify({proof:'a'.repeat(64),expires:Date.now()+600000})));
   await page.goto('http://127.0.0.1:4175/meta-instagram.html?flow=70000000-0000-4000-8000-000000000001&handoff='+'b'.repeat(64));
   await page.locator('#meta-account').waitFor();assert.equal(await page.locator('#meta-account option').count(),2);checks.push(`${width}: callback presents page selection`);
   assert.equal(new URL(page.url()).search,'');checks.push(`${width}: handoff removed from browser history`);
   await page.selectOption('#meta-account','102');await page.click('#meta-confirm');await page.getByText('Instagram conectado. Ya puedes volver').waitFor();checks.push(`${width}: selected account can be confirmed`);
   assert.equal(errors.length,0,errors.join('\n'));await page.close();
  }
  const output={checks,transport:'Isolated Edge browser with mocked backend transports. No real Meta calls or publications.'};
  fs.mkdirSync(path.join(__dirname,'../docs/qa/results'),{recursive:true});fs.writeFileSync(path.join(__dirname,'../docs/qa/results/meta-instagram-browser-fix20.json'),JSON.stringify(output,null,2));console.log('PASS',checks.length,'browser checks');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
