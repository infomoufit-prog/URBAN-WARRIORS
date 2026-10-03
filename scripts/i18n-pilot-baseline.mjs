import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';

const root=resolve(import.meta.dirname,'..');
const baseline=JSON.parse(readFileSync(resolve(import.meta.dirname,'i18n-pilot-baseline.json'),'utf8'));
const key=row=>JSON.stringify([row.file,row.value,[...(row.missing||[])].sort()]);

// Freeze the exact inherited untranslated phrases, rather than accepting an
// arbitrary number of new phrases or ignoring an audit failure.
export function inheritedI18nOnly(kind){
  const spec=baseline[kind];
  const report=JSON.parse(readFileSync(resolve(root,spec.report),'utf8'));
  const actual=report[spec.rows];
  if(!Array.isArray(actual)||actual.length!==report.unresolved)return false;
  const known=new Set(spec.entries.map(key));
  return actual.length>0&&actual.every(row=>known.has(key(row)));
}
