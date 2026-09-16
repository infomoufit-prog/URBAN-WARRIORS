import fs from 'node:fs';
const css=fs.readFileSync('web/css/app.css','utf8');
const checks=[
  ['mobile breakpoint exists',css.includes('@media(max-width:620px)')],
  ['mobile showcase uses square ratio',css.includes('.showcase-item-visual{height:auto;aspect-ratio:1/1}')],
  ['mobile image preserves cover fit',css.includes('.showcase-item-visual>img{width:100%;height:100%;object-fit:cover}')],
  ['legacy fixed 170px removed',!css.includes('.showcase-item-visual{height:170px}')],
  ['desktop showcase height preserved',css.includes('.showcase-item-visual{height:190px;')],
  ['tablet 2-column layout preserved',css.includes('@media(max-width:980px){.showcase-grid{grid-template-columns:repeat(2,minmax(0,1fr))}')],
];
let fail=0;
for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} ${name}`);if(!ok)fail++;}
console.log(`R45 ${checks.length-fail}/${checks.length} PASS`);
process.exit(fail?1:0);
