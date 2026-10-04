import {drainCleanup} from './worker.ts';
Deno.test('Storage API receives exact claimed path; failed removal is retried',async()=>{
 const outcomes:boolean[]=[];let calls=0;
 const client={rpc:async(name:string,args:any)=>name==='app_kombax_cleanup_claim_r119'?{data:[{id:'1',bucket:'kombax-public-media',path:'owner/social/image.jpg',token:'t'},{id:'2',bucket:'kombax-public-media',path:'owner/showcase/item.jpg',token:'u'}]}:(outcomes.push(args.p_ok),{data:true}),
 storage:{from:(bucket:string)=>({remove:async(paths:string[])=>{if(bucket!=='kombax-public-media'||paths.length!==1)throw Error('wrong target');calls++;return {error:calls===2?{message:'retry'}:null};}})}};
 const result=await drainCleanup(client);if(result.completed!==1||result.failed!==1||String(outcomes)!=='true,false')throw Error('incorrect completion');
});
