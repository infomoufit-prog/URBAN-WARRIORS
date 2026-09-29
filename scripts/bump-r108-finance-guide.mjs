import fs from 'node:fs';

const files=['web/config.js','web/service-worker.js','web/index.html','web/delete-account.html','android/app/build.gradle','android/app/src/main/java/com/urbanwarriors/app/MainActivity.java','package.json'];
for(const path of files){
  let text=fs.readFileSync(path,'utf8');
  text=text.replaceAll('2.0.0-rc.13-r107-owner-workspace','2.0.0-rc.13-r108-finance-guide-poster');
  text=text.replaceAll('20160','20161');
  text=text.replaceAll('r107-owner-workspace','r108-finance-guide-poster');
  fs.writeFileSync(path,text,'utf8');
}
const guides='web/js/modules/guides.js';let text=fs.readFileSync(guides,'utf8').replace("runtime-index.json?v=20150","runtime-index.json?v=20161");fs.writeFileSync(guides,text,'utf8');
const financeGuide='web/js/modules/finance-guide.js';text=fs.readFileSync(financeGuide,'utf8').replace("icon('bookOpen',{size:20})","icon('fileText',{size:20})");fs.writeFileSync(financeGuide,text,'utf8');
console.log('R108 build identity applied');
