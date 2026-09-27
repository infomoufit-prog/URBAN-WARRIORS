import { t } from '../i18n/index.js';
import { esc, money } from '../core/utils.js';
import { openDetail, toast } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const STORAGE_KEY='kombax_showcase_cart_v2';
const safeNumber=v=>Number.isFinite(Number(v))?Number(v):0;
const cleanQuantity=(value,stock=null)=>{
  const qty=Math.max(1,Math.floor(safeNumber(value)||1));
  return stock==null?qty:Math.min(qty,Math.max(1,Math.floor(safeNumber(stock)||1)));
};
const variantLabel=(variant,index=0)=>{
  if(!variant||typeof variant!=='object')return `${t('commerce.variant')} ${index+1}`;
  const direct=variant.label||variant.name||variant.nombre||variant.value||variant.code||variant.sku||variant.id;
  if(direct)return String(direct);
  const parts=[variant.size||variant.talla,variant.color,variant.material].filter(Boolean);
  return parts.length?parts.join(' · '):`${t('commerce.variant')} ${index+1}`;
};
export function productVariants(item){return Array.isArray(item?.variantes)?item.variantes.filter(v=>v&&typeof v==='object'):[];}
export function variantOptionsHtml(item){
  const variants=productVariants(item);if(!variants.length)return '';
  return `<label class="kx-cart-option"><span>${esc(t('commerce.variant'))}</span><select id="showcase-variant">${variants.map((v,i)=>`<option value="${i}">${esc(variantLabel(v,i))}</option>`).join('')}</select></label>`;
}
function read(){
  try{const raw=JSON.parse(localStorage.getItem(STORAGE_KEY)||'[]');return Array.isArray(raw)?raw.filter(x=>x&&x.product_id&&x.seller_provider_id):[];}catch{return [];}
}
function write(rows){
  try{localStorage.setItem(STORAGE_KEY,JSON.stringify(rows));}catch{}
  if(typeof window!=='undefined')window.dispatchEvent(new CustomEvent('kombax:showcase-cart-change',{detail:{count:rows.reduce((n,x)=>n+safeNumber(x.quantity),0)}}));
  return rows;
}
export function cartRows(){return read();}
export function cartCount(){return read().reduce((n,x)=>n+safeNumber(x.quantity),0);}
export function clearShowcaseCart(){write([]);}
export function purchaseSelection(item,root=document){
  const rawQty=root?.querySelector?.('#showcase-quantity')?.value||1;
  const variants=productVariants(item),variantIndex=Math.max(0,Number(root?.querySelector?.('#showcase-variant')?.value||0));
  const variant=variants.length?variants[variantIndex]||variants[0]:null;
  const variantStock=variant&&variant.stock!=null?Number(variant.stock):null;
  const stock=item?.stock==null?variantStock:variantStock==null?Number(item.stock):Math.min(Number(item.stock),variantStock);
  return {quantity:cleanQuantity(rawQty,stock),variant};
}
export function addShowcaseCartItem(item,{quantity=1,variant=null}={}){
  if(!item?.id||!item?.marca_id)throw new Error(t('commerce.cartInvalidProduct'));
  let rows=read();
  const other=rows.find(x=>String(x.seller_provider_id)!==String(item.marca_id));
  if(other)throw new Error(t('commerce.singleSellerOnly'));
  const variantKey=variant?JSON.stringify(variant):'';
  const existing=rows.find(x=>String(x.product_id)===String(item.id)&&String(x.variant_key||'')===variantKey);
  const requested=cleanQuantity(quantity,item.stock);
  if(existing)existing.quantity=cleanQuantity(safeNumber(existing.quantity)+requested,item.stock);
  else rows.push({product_id:item.id,name:item.nombre||t('commerce.product'),seller_provider_id:item.marca_id,seller_name:item.marca_nombre||'',unit_amount:Number(item.precio_venta||0),currency:item.moneda||'EUR',quantity:requested,variant:variant||null,variant_key:variantKey,stock:item.stock==null?null:Number(item.stock),image_url:item.imagen_url||'',fulfillment:item.fulfillment||''});
  rows=write(rows);toast(t('commerce.addedToCart'));return rows;
}
export function cartBadgeHtml(){const count=cartCount();return `${icon('shoppingBag',{size:17})} ${esc(t('commerce.cart'))}${count?` <b class="kx-cart-badge">${count}</b>`:''}`;}

export function openShowcaseCart({onCheckout}={}){
  let rows=read();
  const paint=(wrap)=>{
    const total=rows.reduce((sum,row)=>sum+safeNumber(row.unit_amount)*safeNumber(row.quantity),0);
    const seller=rows[0]?.seller_name||'';
    wrap.querySelector('.modal-body').innerHTML=rows.length?`<div class="kx-showcase-cart"><div class="kx-cart-head"><div><span>${esc(t('commerce.seller'))}</span><strong>${esc(seller)}</strong></div><small>${esc(t('commerce.singleSellerNotice'))}</small></div><div class="kx-cart-lines">${rows.map((row,index)=>`<article class="kx-cart-line" data-cart-index="${index}">${row.image_url?`<img src="${esc(row.image_url)}" alt="">`:`<div class="kx-cart-placeholder">${icon('package',{size:22})}</div>`}<div><strong>${esc(row.name)}</strong>${row.variant?`<small>${esc(variantLabel(row.variant,index))}</small>`:''}<span>${money(row.unit_amount)}</span></div><label><span>${esc(t('commerce.quantity'))}</span><input type="number" min="1" ${row.stock!=null?`max="${Math.max(1,Number(row.stock))}"`:''} value="${Number(row.quantity)||1}" data-cart-qty="${index}"></label><button type="button" class="btn btn-ghost btn-sm" data-cart-remove="${index}">${esc(t('commerce.remove'))}</button></article>`).join('')}</div><div class="kx-cart-total"><span>${esc(t('commerce.total'))}</span><strong>${money(total)}</strong></div><div class="kx-cart-checkout-note">${esc(t('commerce.checkoutNotice'))}</div></div>`:`<div class="kx-cart-empty">${icon('shoppingBag',{size:30})}<strong>${esc(t('commerce.emptyCart'))}</strong><p>${esc(t('commerce.emptyCartBody'))}</p></div>`;
    const actions=wrap.querySelector('.modal-actions');
    if(actions)actions.innerHTML=rows.length?`<button type="button" class="btn btn-primary" id="showcase-cart-checkout">${esc(t('commerce.checkout'))}</button><button type="button" class="btn btn-ghost" id="showcase-cart-clear">${esc(t('commerce.clearCart'))}</button>`:'';
    wrap.querySelectorAll('[data-cart-qty]').forEach(input=>input.addEventListener('change',()=>{const i=Number(input.dataset.cartQty);if(!rows[i])return;rows[i].quantity=cleanQuantity(input.value,rows[i].stock);rows=write(rows);paint(wrap);}));
    wrap.querySelectorAll('[data-cart-remove]').forEach(button=>button.addEventListener('click',()=>{rows.splice(Number(button.dataset.cartRemove),1);rows=write(rows);paint(wrap);}));
    wrap.querySelector('#showcase-cart-clear')?.addEventListener('click',()=>{rows=write([]);paint(wrap);});
    wrap.querySelector('#showcase-cart-checkout')?.addEventListener('click',async()=>{if(typeof onCheckout!=='function')return;const button=wrap.querySelector('#showcase-cart-checkout');button.disabled=true;try{await onCheckout(rows.map(({variant_key,...row})=>row));}finally{if(button.isConnected)button.disabled=false;}});
  };
  const {wrap}=openDetail({title:t('commerce.cart'),subtitle:t('commerce.cartSubtitle'),className:'kx-showcase-cart-modal',body:'<div class="loading-card"></div>',actions:'',width:'920px'});
  paint(wrap);return wrap;
}
