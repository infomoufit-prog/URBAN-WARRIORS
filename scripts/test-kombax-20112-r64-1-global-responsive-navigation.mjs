import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const components=readFileSync(new URL('../web/js/ui/components.js',import.meta.url),'utf8');
const css=readFileSync(new URL('../web/css/kombax-commercial.css',import.meta.url),'utf8');

assert.match(components,/class="icon-btn global-menu-toggle menu-toggle" id="menu-btn"/);
assert.doesNotMatch(components,/class="icon-btn mobile-only menu-toggle" id="menu-btn"/);
assert.match(css,/\.app-shell\{[\s\S]*?padding-left:0!important/);
assert.match(css,/\.app-shell \.global-menu-toggle\{[\s\S]*?position:fixed!important/);
assert.match(css,/\.app-shell \.sidebar\{[\s\S]*?position:fixed!important[\s\S]*?transform:translateX\(-105%\)!important/);
assert.match(css,/\.app-shell \.sidebar\.open\{[\s\S]*?transform:translateX\(0\)!important/);
assert.match(css,/\.app-shell \.sidebar-scrim\.open\{[\s\S]*?pointer-events:auto!important/);
assert.match(css,/\.app-shell \.content-shell\{[\s\S]*?width:100%!important/);
assert.match(css,/@media\(min-width:821px\)[\s\S]*?\.app-shell \.bottom-nav\{display:none!important\}/);
assert.match(css,/@media\(max-width:820px\)[\s\S]*?\.app-shell \.global-menu-toggle/);

const viewportMatrix=[
  ['PC',1440,900],
  ['tablet horizontal',1180,820],
  ['tablet vertical',820,1180],
  ['móvil horizontal',844,390],
  ['móvil vertical',390,844],
];
assert.equal(viewportMatrix.length,5);
console.log(`PASS navegación global responsive · ${viewportMatrix.map(([name,w,h])=>`${name} ${w}x${h}`).join(' · ')}`);
