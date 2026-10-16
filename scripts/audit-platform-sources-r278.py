from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1];rows=[]
for p in sorted((root/'web/js').rglob('*.js')):
 text=p.read_text(encoding='utf-8');functions=[]
 for m in re.finditer(r'\b(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(',text):functions.append({'name':m.group(1),'line':text[:m.start()].count('\n')+1})
 calls=[]
 for m in re.finditer(r"['\"]((?:app_|api_)[a-zA-Z0-9_]+)['\"]",text):calls.append({'name':m.group(1),'line':text[:m.start()].count('\n')+1})
 rows.append({'path':p.relative_to(root).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'functions':functions,'rpc_references':calls})
result={'version':'r278','method':'Static inventory and source hashes; not a claim of live execution coverage','files':rows,'file_count':len(rows),'named_function_count':sum(len(x['functions']) for x in rows),'rpc_reference_count':sum(len(x['rpc_references']) for x in rows),'unique_rpc_names':sorted({c['name'] for x in rows for c in x['rpc_references']})}
(root/'docs/AUDITORIA_PLATAFORMA_COMPLETA_R278.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:result[k] for k in ['file_count','named_function_count','rpc_reference_count']}))
