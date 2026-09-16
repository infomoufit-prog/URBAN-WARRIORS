import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const finance=fs.readFileSync(path.join(root,'web/js/modules/finance-premium.js'),'utf8');
const manifest=fs.readFileSync(path.join(root,'android/app/src/main/AndroidManifest.xml'),'utf8');
const gradle=fs.readFileSync(path.join(root,'android/app/build.gradle'),'utf8');
const config=fs.readFileSync(path.join(root,'web/config.js'),'utf8');
const index=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'web/service-worker.js'),'utf8');
const checks=[
 ['mobile KPI grid is vertical/reflow, not horizontal carousel',/@media\(max-width:720px\)[\s\S]*?\.fv2-kpis\{display:grid;grid-template-columns:repeat\(2,minmax\(0,1fr\)\);overflow:visible;scroll-snap-type:none/],
 ['mobile charts remove forced min width',/@media\(max-width:720px\)[\s\S]*?\.fv2-chart-svg,\.fv2-hist-svg\{width:100%;min-width:0;height:auto/],
 ['mobile chart wrapper does not force page horizontal scrolling',/@media\(max-width:720px\)[\s\S]*?\.fv2-chart-wrap\{overflow:hidden;width:100%;max-width:100%\}/],
 ['mobile compact histogram exists',/histogramResponsive\(D\.months,6\)/],
 ['desktop 12 month histogram retained',/histogram\(D\.months\)/],
 ['landscape phone/tablet reflow exists',/@media\(max-width:820px\) and \(orientation:landscape\)/],
 ['landscape dashboard uses responsive columns',/orientation:landscape\)[\s\S]*?\.fv2-dashboard-grid,\.fv2-breakdowns\{grid-template-columns:repeat\(2,minmax\(0,1fr\)\)/],
 ['explorer controls stack on mobile',/@media\(max-width:720px\)[\s\S]*?\.fv2-explorer-tools\{grid-template-columns:1fr;width:100%\}/],
 ['financial tabs reflow on mobile',/@media\(max-width:720px\)[\s\S]*?\.fv2-tabs\{display:grid;grid-template-columns:repeat\(3,minmax\(0,1fr\)\)/],
 ['android rotation is not portrait locked',/android:screenOrientation="unspecified"/],
 ['android versionCode >= 20088',/versionCode\s+(?:2008[89]|20(?:0[9-9]\d|[1-9]\d{2,}))/],
 ['web build >= 20088',/build:\s*(?:2008[89]|20(?:0[9-9]\d|[1-9]\d{2,}))/],
 ['cache busting current',/v=20\d{3}/],
 ['service worker current',/20\d{3}/]
];
for(const [name,re] of checks){const source=name.includes('android rotation')?manifest:name.includes('versionCode')?gradle:name.includes('web build')?config:name.includes('cache busting')?index:name.includes('service worker')?sw:finance;if(!re.test(source)){console.error('FAIL',name);process.exit(1)}console.log('PASS',name)}
if(/@media\(max-width:720px\)[^`]*?\.fv2-kpis\{display:flex;overflow-x:auto/.test(finance)){console.error('FAIL legacy mobile KPI horizontal carousel still present');process.exit(1)}
if(/@media\(max-width:720px\)[^`]*?\.fv2-chart-svg\{min-width:620px/.test(finance)){console.error('FAIL legacy forced mobile chart width still present');process.exit(1)}
console.log('PASS KOMBAX 20088 finance mobile responsive + rotation');
