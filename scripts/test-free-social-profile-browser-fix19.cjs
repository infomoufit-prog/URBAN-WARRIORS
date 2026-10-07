const {chromium}=require(process.env.KOMBAX_PLAYWRIGHT_PATH||'playwright');
const fs=require('fs');
(async()=>{const browser=await chromium.launch({executablePath:process.env.KOMBAX_BROWSER_PATH||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});try{
 const page=await browser.newPage({viewport:{width:Number(process.env.QA_WIDTH||390),height:844},serviceWorkers:'block'});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.fulfill({status:200,body:'[]',contentType:'application/json'}));await page.goto('http://127.0.0.1:4175/');
 const result=await page.evaluate(async()=>{
 const {repos}=await import('/js/core/repositories.js'),{state}=await import('/js/core/state.js'),{backend}=await import('/js/core/backend.js'),{setAppHtml}=await import('/js/ui/components.js'),{renderKombaxSocial}=await import('/js/modules/kombax-social.js');
 setAppHtml('<main id="main-view"></main>');state.session={id:'qa-fix19',scope:'kombax',rol:'global',roles:['global'],email:'qa@example.invalid'};sessionStorage.removeItem('kombax_social_view');
 const checks=[];let profiles=[],writes=0;const ok=(name,v)=>{if(!v)throw Error(name);checks.push(name);};
 repos.kombaxSocial.status=async()=>({status:'inactiva',eligible:true});repos.kombaxSocial.myProfiles=async()=>profiles;repos.kombaxSocial.networkProfiles=async()=>profiles;repos.kombaxSocial.minorConsentStatus=async()=>({mine:[],approvals:[]});repos.kombaxSocial.feed=async()=>[];repos.kombaxSocial.promotions=async()=>[];repos.kombaxSocial.audiences=async()=>[];repos.kombaxSocial.quota=async()=>({active_posts:0,active_limit:30});
 repos.kombaxProfiles.mine=async()=>[];repos.kombaxProfiles.applications=async()=>[];repos.kombaxProfiles.clubs=async()=>[];repos.kombaxProfiles.workspaceSettings=async()=>[];repos.kombaxMemberships.active=async()=>[];repos.kombaxIdentity.memberPublicProfile=async()=>({});backend.accountClubs=async()=>[];repos.kombaxProfiles.save=async()=>{writes++;throw Error('UNEXPECTED_WRITE');};
 await renderKombaxSocial();ok('no profile shows voluntary invitation',!!document.querySelector('[data-public-profile-invitation]'));ok('no misleading active profile',!document.querySelector('.kx-social-composer'));ok('no automatic activation',!document.querySelector('#kombax-social-activate'));ok('no public-profile creation on reading',writes===0);ok('no publishing without identity',!document.querySelector('#kombax-social-publish'));
 document.querySelector('#kx-social-create-profile').click();await new Promise(r=>setTimeout(r,700));
 ok('invitation opens existing profile picker',!!document.querySelector('[data-kx-pick="espectador"]'));ok('free account keeps Social entry',!!document.querySelector('#kx-open-social'));ok('free account keeps Showcase entry',!!document.querySelector('#kx-open-showcase'));ok('free account keeps Events entry',!!document.querySelector('#kx-open-events'));ok('choosing is voluntary; opening picker makes no write',writes===0);
 const {closeModal}=await import('/js/ui/components.js');closeModal();setAppHtml('<main id="main-view"></main>');
 for(const item of [{perfil_tipo:'espectador',publication_enabled:false},{perfil_tipo:'espectador',publication_enabled:true},{perfil_tipo:'competidor',publication_enabled:false},{perfil_tipo:'competidor'},{perfil_tipo:'competidor',publication_enabled:true}]){
 profiles=[{id:'social-qa',nombre_publico:'QA',sujeto_tipo:'perfil_directo',...item}];await renderKombaxSocial();const permitted=item.perfil_tipo!=='espectador'&&item.publication_enabled===true;
 ok(JSON.stringify(item)+' publisher matches explicit permission',!!document.querySelector('#kx-social-quick-text')===permitted);
 ok(JSON.stringify(item)+' no duplicate create invitation',!document.querySelector('[data-public-profile-invitation]'));
 if(item.perfil_tipo==='espectador')ok('spectator never prompts member activation',!document.querySelector('#kombax-social-activate'));
 }
 return {checks,writes,transport:'Isolated Edge browser with mocked repositories. Live permission tests are recorded separately.'};
 });if(errors.length)throw Error(errors.join('\n'));
 await page.evaluate(async()=>{const {repos}=await import('/js/core/repositories.js');repos.kombaxSocial.myProfiles=async()=>[];repos.kombaxSocial.networkProfiles=async()=>[];await (await import('/js/modules/kombax-social.js')).renderKombaxSocial();});
 await page.screenshot({path:'outputs/PERFIL_GRATUITO_FIX19_'+(process.env.QA_WIDTH||390)+'.png',fullPage:true});
 fs.writeFileSync('outputs/QA_PERFIL_GRATUITO_FIX19_'+(process.env.QA_WIDTH||390)+'.json',JSON.stringify({...result,pageErrors:errors},null,2));console.log('PASS',result.checks.length,'free profile browser checks');
 }finally{await browser.close();}})().catch(e=>{console.error(e.stack);process.exitCode=1;});
