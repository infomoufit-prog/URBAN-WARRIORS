import {createClient} from 'npm:@supabase/supabase-js@2.112.3';
import {makeDocumentHandler} from './handler.mjs';
Deno.serve(makeDocumentHandler(()=>{
 const url=Deno.env.get('SUPABASE_URL'),key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!url||!key)throw new Error('BACKEND_NOT_CONFIGURED');
 return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
}));
