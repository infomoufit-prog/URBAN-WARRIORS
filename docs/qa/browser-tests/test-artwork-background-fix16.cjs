const {chromium}=require('C:/Users/Bryan Work/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs');
(async()=>{const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});const checks=[];try{
const page=await browser.newPage({serviceWorkers:'block'});
await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.fulfill({status:200,body:'[]',contentType:'application/json'}));
await page.goto('http://127.0.0.1:4175/');
for(const width of [360,390,780,844,1024,1440])for(const screen of ['onboarding','inicio']){
await page.setViewportSize({width,height:width===780?390:900});
await page.evaluate(async(screen)=>{const{state}=await import('/js/core/state.js');const{setLocale}=await import('/js/i18n/index.js');setLocale('es');if(screen==='onboarding'){state.session=null;const{renderKombaxGateway}=await import('/js/modules/gateway.js');renderKombaxGateway({});}else{state.session={id:'qa-artwork',nombre:'QA'};const{renderKombaxHome}=await import('/js/modules/kombax-home.js');await renderKombaxHome({standalone:true,contextName:'QA'});}},screen);
await page.waitForTimeout(300);
const result=await page.evaluate(async(screen)=>{
const visual=document.querySelector(screen==='onboarding'?'.gateway-entry-visual':'.kx-prepilot-home-stage-media');
const media=document.querySelector(screen==='onboarding'?'.gateway-entry-media img':'.kx-prepilot-home-stage-media');
const copy=document.querySelector(screen==='onboarding'?'.gateway-intro':'.kx-prepilot-home-stage-copy');
const style=getComputedStyle(media),box=media.getBoundingClientRect(),c=copy.getBoundingClientRect().toJSON();
const img=screen==='onboarding'?media:new Image();if(screen!=='onboarding')img.src=new URL('/assets/brand-heroes/gateway-kombax-community.webp',location.href).href;
await img.decode();
const cs=getComputedStyle(copy);c.top+=parseFloat(cs.paddingTop)||0;c.bottom-=parseFloat(cs.paddingBottom)||0;c.left+=parseFloat(cs.paddingLeft)||0;c.right-=parseFloat(cs.paddingRight)||0;const coverScale=Math.max(box.width/img.naturalWidth,box.height/img.naturalHeight);const horizontalCrop=screen==='onboarding'?Math.max(0,1-box.width/(img.naturalWidth*coverScale)):0;const scale=Math.min(box.width/img.naturalWidth,box.height/img.naturalHeight);const w=img.naturalWidth*scale,h=img.naturalHeight*scale;const v={left:box.left+(box.width-w)/2,right:box.left+(box.width+w)/2,top:box.top+(box.height-h)/2,bottom:box.top+(box.height+h)/2,width:w,height:h};
return{horizontalCrop,position:screen==='onboarding'?style.objectPosition:style.backgroundPosition,fit:screen==='onboarding'?style.objectFit:style.backgroundSize,transform:style.transform,ratio:v.width/v.height,naturalRatio:img.naturalWidth/img.naturalHeight,overlap:Math.min(v.right,c.right)>Math.max(v.left,c.left)+1&&Math.min(v.bottom,c.bottom)>Math.max(v.top,c.top)+1,overflow:document.documentElement.scrollWidth>innerWidth+1,mask:getComputedStyle(visual).maskImage};
},screen);
if(result.horizontalCrop>.08||!result.position.endsWith('0%')||result.overflow||result.transform!=='none'||(screen==='onboarding'?result.fit!=='cover':result.fit!=='100% auto'))throw Error(JSON.stringify({width,screen,result}));
checks.push({width,screen,...result});
if([390,780,1440].includes(width))await page.screenshot({path:`outputs/ASSET_${screen.toUpperCase()}_${width}_FIX16.png`,fullPage:true});
}
fs.writeFileSync('outputs/QA_ASSETS_FIX16.json',JSON.stringify({passed:checks.length,checks},null,2));console.log(`PASS ${checks.length} responsive background cases`);
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1)});

