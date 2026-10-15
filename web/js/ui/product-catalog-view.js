const MODES=new Set(['compact','large','list']);
const LABELS={compact:'Cuadrícula compacta',large:'Cuadrícula grande',list:'Lista'};
export const normalizeProductView=mode=>MODES.has(mode)?mode:'compact';
export function productViewKey(area,session={}){
  return `kombax_product_view:${session?.id||'guest'}:${area==='material'?'material':'showcase'}:${area==='material'?(session?.club_id||'none'):'public'}`;
}
export function readProductView(area,session={},storage){
  try{const target=storage===undefined?globalThis.localStorage:storage;return normalizeProductView(target?.getItem(productViewKey(area,session)));}catch{return 'compact';}
}
export function writeProductView(area,mode,session={},storage){
  const value=normalizeProductView(mode);try{const target=storage===undefined?globalThis.localStorage:storage;target?.setItem(productViewKey(area,session),value);}catch{}return value;
}
export function productViewToolbar(area,session){
  const scope=area==='material'?'material':'showcase',mode=readProductView(scope,session);
  return `<div class="kx-catalog-view-controls" role="group" aria-label="Vista del catálogo">${Object.entries(LABELS).map(([value,label])=>`<button type="button" class="btn btn-ghost btn-sm" data-catalog-view-area="${scope}" data-catalog-view="${value}" aria-pressed="${mode===value}">${label}</button>`).join('')}</div>`;
}
export function bindProductView(area,session,root=document){
  const scope=area==='material'?'material':'showcase';
  const grids=root.querySelectorAll(`[data-catalog-area="${scope}"]`);
  const buttons=root.querySelectorAll(`[data-catalog-view-area="${scope}"]`);
  const apply=mode=>{for(const grid of grids)grid.dataset.productView=mode;for(const button of buttons)button.setAttribute('aria-pressed',String(button.dataset.catalogView===mode));};
  apply(readProductView(scope,session));
  for(const button of buttons)button.addEventListener('click',()=>apply(writeProductView(scope,button.dataset.catalogView,session)));
}
