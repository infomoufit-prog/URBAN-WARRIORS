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
    const {repos}=await import('/js/core/repositories.js'),{state}=await import('/js/core/state.js'),{setAppHtml,closeModal}=await import('/js/ui/components.js');
    const {openHistoricalFinance}=await import('/js/modules/historical-finance.js');
    state.session={id:'qa',club_id:'qa-club',rol:'direccion'};setAppHtml('<main id="main-view"></main>');
    const checks=[],calls=[];let reloads=0;const ok=(n,v)=>{if(!v)throw Error(n);checks.push(n)};
    repos.finance.historical=async(p,id)=>{calls.push({p,id});return {cuota_id:'qa-fee'}};
    openHistoricalFinance([{id:'qa-member',nombre:'QA',apellidos:'Student'}],async()=>reloads++);
    let form=document.querySelector('#modal-form');const field=n=>form.elements.namedItem(n);
    ok('pending mode hides payment controls',field('fecha_pago').disabled&&!field('fecha_pago').required&&getComputedStyle(field('fecha_pago').closest('.field')).display==='none');
    field('socio_id').value='qa-member';field('concepto').value='Karate';field('importe').value='50';field('periodo').value='2020-01-01';field('vencimiento').value='2020-01-10';
    form.requestSubmit();await new Promise(r=>setTimeout(r,360));
    ok('pending submit records historical period',calls[0]?.p.periodo==='2020-01-01'&&calls[0].p.estado==='pendiente');
    ok('pending never invents payment date',calls[0].p.fecha_pago===null);
    openHistoricalFinance([{id:'qa-member',nombre:'QA',apellidos:'Student'}],async()=>reloads++);
    form=document.querySelector('#modal-form');field('estado').value='pagado';field('estado').dispatchEvent(new Event('change'));
    ok('paid mode requires actual payment date',!field('fecha_pago').disabled&&field('fecha_pago').required);
    field('socio_id').value='qa-member';field('concepto').value='Karate';field('importe').value='50';field('periodo').value='2020-01-01';field('vencimiento').value='2020-01-10';
    form.requestSubmit();ok('missing payment date blocks submission',calls.length===1);
    field('fecha_pago').value='2020-01-09';form.requestSubmit();await new Promise(r=>setTimeout(r,360));
    ok('paid submit preserves payment date',calls[1]?.p.fecha_pago==='2020-01-09');ok('each new record receives distinct request id',calls[0].id!==calls[1].id);ok('refresh after recording',reloads===2);
    ok('no horizontal overflow',document.documentElement.scrollWidth<=innerWidth+2);closeModal();return {checks};
   });checks.push(...result.checks.map(x=>`${width}: ${x}`));assert.equal(errors.length,0,errors.join('\n'));await page.close();
  }
  fs.mkdirSync('docs/qa/results',{recursive:true});fs.writeFileSync('docs/qa/results/historical-finance-browser-fix20.json',JSON.stringify({checks,passed:checks.length,transport:'mocked; no production writes'},null,2));console.log(`PASS ${checks.length} historical finance browser checks`);
 }finally{await browser.close()}
})().catch(e=>{console.error(e.message);process.exitCode=1});
