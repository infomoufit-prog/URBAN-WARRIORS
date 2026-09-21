import { openDetail, toast } from './components.js';
import { esc } from '../core/utils.js';

const PRESETS=Object.freeze({
  fighter:{fit:'cover',focus_x:50,focus_y:24,zoom:1,orientation:'auto'},
  avatar:{fit:'cover',focus_x:50,focus_y:32,zoom:1,orientation:'square'},
  banner:{fit:'cover',focus_x:50,focus_y:50,zoom:1,orientation:'landscape'},
  album:{fit:'balanced',focus_x:50,focus_y:50,zoom:1,orientation:'auto'},
  product:{fit:'contain',focus_x:50,focus_y:50,zoom:1,orientation:'auto'},
  material:{fit:'contain',focus_x:50,focus_y:50,zoom:1,orientation:'auto'},
  social:{fit:'contain',focus_x:50,focus_y:50,zoom:1,orientation:'auto'},
  community:{fit:'contain',focus_x:50,focus_y:50,zoom:1,orientation:'auto'},
  default:{fit:'contain',focus_x:50,focus_y:50,zoom:1,orientation:'auto'}
});
const FITS=new Set(['auto','cover','contain','balanced']);
const ORIENTATIONS=new Set(['auto','portrait','landscape','square']);
const clamp=(v,min,max,fallback)=>{const n=Number(v);return Number.isFinite(n)?Math.max(min,Math.min(max,n)):fallback;};
function source(value){if(value&&typeof value==='object')return value;try{return JSON.parse(String(value||'{}'))||{};}catch{return {};}}
export function mediaPreset(name='default'){return PRESETS[name]||PRESETS.default;}
export function normalizeMediaPresentation(value={},preset='default'){
  const src=source(value),base=mediaPreset(preset);
  const rawFit=String(src.fit||'auto').toLowerCase(),rawOrientation=String(src.orientation||'auto').toLowerCase();
  return {
    fit:FITS.has(rawFit)?rawFit:'auto',
    focus_x:clamp(src.focus_x,0,100,base.focus_x),
    focus_y:clamp(src.focus_y,0,100,base.focus_y),
    zoom:clamp(src.zoom,1,2.5,base.zoom),
    orientation:ORIENTATIONS.has(rawOrientation)?rawOrientation:'auto'
  };
}
export function effectiveMediaPresentation(value={},preset='default'){
  const p=normalizeMediaPresentation(value,preset),base=mediaPreset(preset);
  return {...p,fit:p.fit==='auto'?base.fit:p.fit,orientation:p.orientation==='auto'?base.orientation:p.orientation};
}
export function mediaFrameStyle(value={},preset='default'){
  const p=effectiveMediaPresentation(value,preset),balanced=p.fit==='balanced';
  return `--kx-media-fit:${balanced?'cover':p.fit};--kx-media-base-scale:${balanced?'0.90':'1'};--kx-media-x:${p.focus_x.toFixed(2)}%;--kx-media-y:${p.focus_y.toFixed(2)}%;--kx-media-zoom:${p.zoom.toFixed(2)}`;
}
export function mediaFrameAttrs(value={},preset='default'){
  const p=effectiveMediaPresentation(value,preset);
  return `class="kx-media-frame-img" data-kx-media-orientation="${p.orientation}" style="${mediaFrameStyle(value,preset)}"`;
}

function editorMarkup(src,p,preset,mediaType='image'){
  const effective=effectiveMediaPresentation(p,preset);
  const previewMedia=mediaType==='video'?`<video src="${esc(src)}" muted controls playsinline preload="metadata" style="${mediaFrameStyle(p,preset)}"></video>`:`<img src="${esc(src)}" alt="Vista previa del encuadre" style="${mediaFrameStyle(p,preset)}">`;
  return `<div class="kx-media-framing-editor" data-kx-media-framer data-preset="${esc(preset)}">
    <div class="kx-media-framing-preview" data-kx-framing-preview data-orientation="${esc(effective.orientation)}">${previewMedia}<span class="kx-media-framing-safe">ZONA VISIBLE</span></div>
    <div class="kx-media-framing-controls">
      <label><span>Comportamiento</span><select data-kx-frame-fit><option value="auto">Automático</option><option value="contain">Mostrar completo</option><option value="balanced">Equilibrado</option><option value="cover">Rellenar marco</option></select></label>
      <label><span>Formato de previsualización</span><select data-kx-frame-orientation><option value="auto">Automático</option><option value="portrait">Vertical</option><option value="landscape">Horizontal</option><option value="square">Cuadrado</option></select></label>
      <label><span>Horizontal <b data-kx-frame-x-label></b></span><input data-kx-frame-x type="range" min="0" max="100" step="1"></label>
      <label><span>Vertical <b data-kx-frame-y-label></b></span><input data-kx-frame-y type="range" min="0" max="100" step="1"></label>
      <label><span>Zoom <b data-kx-frame-zoom-label></b></span><input data-kx-frame-zoom type="range" min="1" max="2.5" step="0.05"></label>
    </div>
    <p class="muted">El archivo original no se modifica. KOMBAX guarda únicamente cómo quieres presentarlo en tarjetas y miniaturas. «Mostrar completo» evita recortes; «Equilibrado» llena la miniatura de forma moderada mostrando más imagen; «Rellenar marco» prioriza impacto y puede recortar bordes.</p>
  </div>`;
}

export function openMediaFramingEditor({title='Ajustar encuadre',subtitle='Elige qué parte debe quedar visible.',src,mediaType='image',initial={},preset='default',onSave,secondaryActionLabel='',onSecondaryAction=null}={}){
  if(!src){toast('No hay contenido multimedia disponible para ajustar.','error');return null;}
  let current=normalizeMediaPresentation(initial,preset);
  const secondary=secondaryActionLabel&&typeof onSecondaryAction==='function'?`<button type="button" class="btn btn-ghost" data-kx-frame-secondary>${esc(secondaryActionLabel)}</button>`:'';
  const modal=openDetail({title,subtitle,body:editorMarkup(src,current,preset,mediaType),actions:`<button type="button" class="btn btn-ghost" data-kx-frame-reset>Restablecer</button>${secondary}<button type="button" class="btn btn-primary" data-kx-frame-save>Guardar encuadre</button>`,width:'900px',className:'kx-media-framing-modal'});
  const root=modal.wrap.querySelector('[data-kx-media-framer]'),preview=root?.querySelector('[data-kx-framing-preview]'),media=preview?.querySelector('img,video');
  const fit=root?.querySelector('[data-kx-frame-fit]'),orientation=root?.querySelector('[data-kx-frame-orientation]'),x=root?.querySelector('[data-kx-frame-x]'),y=root?.querySelector('[data-kx-frame-y]'),zoom=root?.querySelector('[data-kx-frame-zoom]');
  const xLabel=root?.querySelector('[data-kx-frame-x-label]'),yLabel=root?.querySelector('[data-kx-frame-y-label]'),zoomLabel=root?.querySelector('[data-kx-frame-zoom-label]');
  const sync=()=>{
    current=normalizeMediaPresentation({fit:fit?.value,orientation:orientation?.value,focus_x:x?.value,focus_y:y?.value,zoom:zoom?.value},preset);
    const eff=effectiveMediaPresentation(current,preset);
    if(media)media.setAttribute('style',mediaFrameStyle(current,preset));
    if(preview)preview.dataset.orientation=eff.orientation;
    if(xLabel)xLabel.textContent=`${Math.round(current.focus_x)}%`;if(yLabel)yLabel.textContent=`${Math.round(current.focus_y)}%`;if(zoomLabel)zoomLabel.textContent=`${current.zoom.toFixed(2)}×`;
  };
  const setControls=value=>{current=normalizeMediaPresentation(value,preset);if(fit)fit.value=current.fit;if(orientation)orientation.value=current.orientation;if(x)x.value=String(current.focus_x);if(y)y.value=String(current.focus_y);if(zoom)zoom.value=String(current.zoom);sync();};
  [fit,orientation,x,y,zoom].forEach(el=>el?.addEventListener('input',sync));
  modal.wrap.querySelector('[data-kx-frame-reset]')?.addEventListener('click',()=>setControls({fit:'auto',orientation:'auto',...mediaPreset(preset)}));
  modal.wrap.querySelector('[data-kx-frame-secondary]')?.addEventListener('click',async e=>{const button=e.currentTarget;button.disabled=true;const old=button.textContent;button.textContent='Añadiendo…';try{await onSecondaryAction?.(current);button.textContent='Añadido al álbum';toast('Contenido añadido al álbum sin duplicar el archivo.');}catch(error){button.disabled=false;button.textContent=old;toast(error?.message||'No se pudo añadir al álbum.','error');}});
  modal.wrap.querySelector('[data-kx-frame-save]')?.addEventListener('click',async e=>{const button=e.currentTarget;button.disabled=true;const old=button.textContent;button.textContent='Guardando…';try{sync();await onSave?.(current);toast('Encuadre guardado');modal.close?.();}catch(error){button.disabled=false;button.textContent=old;toast(error?.message||'No se pudo guardar el encuadre.','error');}});
  setControls(current);
  return modal;
}
