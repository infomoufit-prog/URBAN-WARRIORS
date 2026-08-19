import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const social=read('web/js/modules/kombax-social.js');
const icons=read('web/js/ui/icons.js');
const repo=read('web/js/core/repositories.js');
const mig=read('supabase/migrations/062_kombax_social_showcase_audit_hardening.sql');
const cfg=read('web/config.js');
const gradle=read('android/app/build.gradle');
const checks=[
 ['heart icon',icons.includes("heart:'")&&social.includes("icon('heart'" )&&!social.includes("icon('sparkles',{size:17})<span>${Number(p.likes_count||0)}</span>" )],
 ['comment profile links',social.includes('kx-comment-author-open')&&social.includes('kx-comment-author-name')&&social.includes("openKombaxPublicProfile(el.dataset.socialProfileOpen)" )],
 ['comments repository',repo.includes("kombax.social.comentar")&&repo.includes('app_kombax_social_comentarios_v053')],
 ['social publish media',repo.includes("social_media_id")&&repo.includes('uploadMedia')],
 ['showcase upload path',repo.includes('/showcase/${brandId}/')||repo.includes('showcase/${brandId}/')],
 ['showcase RLS depth fixed',mig.includes("array_length(storage.foldername(name),1)>=3")&&!mig.includes("array_length(storage.foldername(name),1)>=4")],
 ['comment parent guard',mig.includes('KOMBAX_COMMENT_PARENT_POST_MISMATCH')&&mig.includes('KOMBAX_COMMENT_REPLY_DEPTH_LIMIT')],
 ['build 20035+',/build:\s*200(?:3[5-9]|[4-9]\d)/.test(cfg)&&/versionCode\s+200(?:3[5-9]|[4-9]\d)/.test(gradle)]
];
const failed=checks.filter(([,ok])=>!ok);
for(const [name,ok] of checks)console.log(`${ok?'PASS':'FAIL'} ${name}`);
if(failed.length)process.exit(1);
console.log('KOMBAX 20035 SOCIAL + SHOWCASE AUDIT: PASS');
