import fs from 'node:fs';

function edit(path, transforms){
  let text=fs.readFileSync(path,'utf8');
  for(const [from,to] of transforms){
    if(!text.includes(from))throw new Error(`Missing marker in ${path}: ${from.slice(0,90)}`);
    text=text.replace(from,to);
  }
  fs.writeFileSync(path,text,'utf8');
}

edit('web/js/modules/finance-premium.js',[
  ["import { paymentCenterSummaryHtml, bindPaymentCenter, openPaymentCenter } from './payments-center.js';", "import { paymentCenterSummaryHtml, bindPaymentCenter, openPaymentCenter } from './payments-center.js';\nimport { mountFinanceGuide } from './finance-guide.js';"],
  ["    for(const [id,k] of [['f-year'", "    mountFinanceGuide({premium:true});\n\n    for(const [id,k] of [['f-year'"],
]);

console.log('R108 finance guide hooks applied');
