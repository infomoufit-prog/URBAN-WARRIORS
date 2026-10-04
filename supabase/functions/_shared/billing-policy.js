export function subscriptionIdForEvent(event){
 const o=event?.data?.object||{};
 if(String(event?.type||'').startsWith('customer.subscription.'))return o.id;
 if(String(event?.type||'').startsWith('invoice.'))return typeof o.subscription==='string'?o.subscription:o.parent?.subscription_details?.subscription;
 if(event?.type==='checkout.session.completed'&&o.mode==='subscription')return typeof o.subscription==='string'?o.subscription:o.subscription?.id;
 return '';
}
export function validateRecurringPrice(price,prepared){
 if(!price?.active||price.type!=='recurring'||price.recurring?.interval!=='month'||price.recurring?.interval_count!==1||price.unit_amount!==prepared.amount_minor||price.currency!==prepared.currency||price.livemode!==prepared.livemode)throw new Error('STRIPE_PRICE_MISMATCH');
}
export async function verifyBillingSignature(raw,header,secret,now=Date.now()){
 const parts=String(header||'').split(',').map(x=>x.trim().split('=')),stamp=parts.find(x=>x[0]==='t')?.[1];
 if(!/^\d+$/.test(stamp||'')||Math.abs(now/1000-Number(stamp))>300)return false;
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
 const data=new TextEncoder().encode(`${stamp}.${raw}`);
 for(const [,sig] of parts.filter(x=>x[0]==='v1'))if(/^[0-9a-f]{64}$/i.test(sig||'')){
  const bytes=new Uint8Array(sig.match(/../g).map(x=>parseInt(x,16)));if(await crypto.subtle.verify('HMAC',key,bytes,data))return true;
 }
 return false;
}
