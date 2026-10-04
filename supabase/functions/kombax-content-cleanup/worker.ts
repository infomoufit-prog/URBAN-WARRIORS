type Job={id:string;bucket:string;path:string;token:string};
export async function drainCleanup(client:any){
 const claim=await client.rpc('app_kombax_cleanup_claim_r119');if(claim.error)throw new Error('cleanup_claim_failed');
 const jobs:Job[]=claim.data||[];let completed=0,failed=0;
 for(const job of jobs){
  let ok=false;
  try{const removal=await client.storage.from(job.bucket).remove([job.path]);ok=!removal.error;}catch{ok=false;}
  const finish=await client.rpc('app_kombax_cleanup_finish_r119',{p_id:job.id,p_token:job.token,p_ok:ok});
  if(finish.error||!finish.data)throw new Error('cleanup_finish_failed');
  if(ok)completed++;else failed++;
 }
 return {claimed:jobs.length,completed,failed};
}
