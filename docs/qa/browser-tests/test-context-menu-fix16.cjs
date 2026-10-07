const {chromium}=require('C:/Users/Bryan Work/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs');
(async()=>{const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});try{
const page=await browser.newPage({viewport:{width:390,height:844},serviceWorkers:'block'});
await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.fulfill({status:200,body:'[]',contentType:'application/json'}));await page.goto('http://127.0.0.1:4175/');
const checks=await page.evaluate(async()=>{
 const {state}=await import('/js/core/state.js');
 const {setAppHtml}=await import('/js/ui/components.js');
 const {setPersonalWorkspaceNavigation,clearPersonalWorkspaceNavigation}=await import('/js/ui/personal-navigation.js');
 const checks=[],ok=(n,v)=>{if(!v)throw Error(n);checks.push(n);};
 state.session={id:'qa',scope:'kombax',nombre:'QA'};
 for(const type of ['marca','federacion','profesional','media','competidor','espectador']){
  clearPersonalWorkspaceNavigation();setAppHtml('<main>Account</main>');
  ok(type+' account retains general notices and inbox',document.querySelector('[data-kx-team-inbox]')&&document.querySelector('[data-kx-moderation-notices]'));
  let selected=null;
  setPersonalWorkspaceNavigation({profileId:type,name:type,navigationHtml:'<button data-module="overview">Inicio</button><button data-module="public_profile">Perfil público</button>',onModule:m=>{selected=m;}});
  setAppHtml('<main>Identity</main>');
  ok(type+' excludes general account tools',!document.querySelector('[data-kx-team-inbox],[data-kx-moderation-notices]'));
  ok(type+' retains account and logout',document.querySelector('[data-kx-personal-nav=workspace]')&&document.querySelector('[data-kx-personal-nav=logout]'));
  document.querySelector('[data-module=public_profile]').click();ok(type+' public profile uses identity callback',selected==='public_profile');
  clearPersonalWorkspaceNavigation();setAppHtml('<main>Account</main>');ok(type+' restores general account tools',document.querySelector('[data-kx-team-inbox]')&&document.querySelector('[data-kx-moderation-notices]'));
 }
 return checks;
});fs.writeFileSync('outputs/QA_CONTEXTO_MENU_FIX16.json',JSON.stringify({passed:checks.length,checks,transport:'Browser with synthetic session; no real accounts changed'},null,2));console.log('PASS',checks.length,'shared identity menu checks');
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1)});
