import { getLocale as kxGetLocale } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
/* KOMBAX RC13 build 20.094 · Local Visual Engine + QR. No external image/QR API. */
const THEMES={
 fight:{bg:'#050608',accent:'#f02432',accent2:'#7d0710',text:'#ffffff',muted:'#adb4bd'},
 arena:{bg:'#070812',accent:'#d81b60',accent2:'#5b123c',text:'#ffffff',muted:'#b6b7c5'},
 federation:{bg:'#07101a',accent:'#4f8cff',accent2:'#17315f',text:'#ffffff',muted:'#b5c1d2'},
 seminar:{bg:'#0b0c0f',accent:'#e5b85c',accent2:'#6d511a',text:'#ffffff',muted:'#c8c0ae'}
};
const PLACEHOLDER='./assets/events/templates/fighter-placeholder.svg';
const enc=new TextEncoder();
const gfMul=(x,y)=>{let z=0;for(let i=7;i>=0;i--){z=(z<<1)^((z>>>7)*0x11d);if(((y>>>i)&1)!==0)z^=x;}return z;};
function rsDivisor(degree){const r=new Uint8Array(degree);r[degree-1]=1;let root=1;for(let i=0;i<degree;i++){for(let j=0;j<degree;j++){r[j]=gfMul(r[j],root);if(j+1<degree)r[j]^=r[j+1];}root=gfMul(root,2);}return r;}
function rsRemainder(data,div){const r=new Uint8Array(div.length);for(const b of data){const factor=b^r[0];r.copyWithin(0,1);r[r.length-1]=0;for(let i=0;i<r.length;i++)r[i]^=gfMul(div[i],factor);}return r;}
const pushBits=(arr,val,len)=>{for(let i=len-1;i>=0;i--)arr.push((val>>>i)&1);};
function formatBits(mask=0){const data=(1<<3)|mask;let rem=data;for(let i=0;i<10;i++)rem=(rem<<1)^(((rem>>>9)&1)*0x537);return ((data<<10)|rem)^0x5412;}
export function qrMatrix(text){
 const bytes=enc.encode(String(text));if(bytes.length>106)throw new Error('El enlace es demasiado largo para el QR local.');
 const bits=[];pushBits(bits,4,4);pushBits(bits,bytes.length,8);for(const b of bytes)pushBits(bits,b,8);for(let i=0;i<Math.min(4,864-bits.length);i++)bits.push(0);while(bits.length%8)bits.push(0);
 const data=[];for(let i=0;i<bits.length;i+=8){let v=0;for(let j=0;j<8;j++)v=(v<<1)|(bits[i+j]||0);data.push(v);}for(let p=0;data.length<108;p++)data.push(p%2?0x11:0xec);
 const ecc=Array.from(rsRemainder(Uint8Array.from(data),rsDivisor(26)));const code=data.concat(ecc);const size=37,m=Array.from({length:size},()=>Array(size).fill(false)),fn=Array.from({length:size},()=>Array(size).fill(false));
 const set=(r,c,v,f=true)=>{if(r>=0&&c>=0&&r<size&&c<size){m[r][c]=!!v;if(f)fn[r][c]=true;}};
 const finder=(r,c)=>{for(let dr=-4;dr<=4;dr++)for(let dc=-4;dc<=4;dc++){const d=Math.max(Math.abs(dr),Math.abs(dc));set(r+dr,c+dc,d!==2&&d!==4);}};
 finder(3,3);finder(3,size-4);finder(size-4,3);
 for(let i=8;i<size-8;i++){set(6,i,i%2===0);set(i,6,i%2===0);}
 for(let dr=-2;dr<=2;dr++)for(let dc=-2;dc<=2;dc++)set(30+dr,30+dc,Math.max(Math.abs(dr),Math.abs(dc))!==1);
 const drawFormat=()=>{const fb=formatBits(0);for(let i=0;i<=5;i++)set(i,8,((fb>>>i)&1)!==0);set(7,8,((fb>>>6)&1)!==0);set(8,8,((fb>>>7)&1)!==0);set(8,7,((fb>>>8)&1)!==0);for(let i=9;i<15;i++)set(8,14-i,((fb>>>i)&1)!==0);for(let i=0;i<8;i++)set(8,size-1-i,((fb>>>i)&1)!==0);for(let i=8;i<15;i++)set(size-15+i,8,((fb>>>i)&1)!==0);set(size-8,8,true);};
 drawFormat();let bi=0;for(let right=size-1;right>=1;right-=2){if(right===6)right--;const upward=((right+1)&2)===0;for(let vert=0;vert<size;vert++){const r=upward?size-1-vert:vert;for(let j=0;j<2;j++){const c=right-j;if(fn[r][c])continue;let v=false;if(bi<code.length*8)v=((code[bi>>>3]>>>(7-(bi&7)))&1)!==0;bi++;if((r+c)%2===0)v=!v;m[r][c]=v;}}}drawFormat();return m;
}
export function qrSvg(text,{size=320,margin=4}={}){const q=qrMatrix(text),n=q.length,total=n+margin*2,scale=size/total;let path='';for(let r=0;r<n;r++)for(let c=0;c<n;c++)if(q[r][c])path+=`M${(c+margin)*scale} ${(r+margin)*scale}h${scale}v${scale}h-${scale}z`;return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" role="img" aria-label="Código QR KOMBAX"><rect width="100%" height="100%" rx="24" fill="#fff"/><path d="${path}" fill="#050608"/></svg>`;}
export function shareUrl(event,fight=null){const u=new URL(location.origin+location.pathname);u.searchParams.set('event',event.slug);if(fight?.id)u.searchParams.set('fight',fight.id);return u.toString();}
const loadImage=(src)=>new Promise(resolve=>{const img=new Image();img.decoding='async';if(/^https?:/i.test(String(src||'')))img.crossOrigin='anonymous';img.onload=()=>resolve(img);img.onerror=()=>resolve(null);img.src=src;});
const loadBitmap=async url=>(await loadImage(url||PLACEHOLDER))||(url!==PLACEHOLDER?await loadImage(PLACEHOLDER):null);
const fitText=(ctx,text,maxWidth,start,min=26)=>{let s=start;ctx.font=`900 ${s}px Arial, sans-serif`;while(s>min&&ctx.measureText(text).width>maxWidth){s-=2;ctx.font=`900 ${s}px Arial, sans-serif`;}return s;};
const roundedPath=(ctx,x,y,w,h,r=28)=>{const rr=Math.min(r,w/2,h/2);ctx.beginPath();if(typeof ctx.roundRect==='function'){ctx.roundRect(x,y,w,h,rr);return;}ctx.moveTo(x+rr,y);ctx.lineTo(x+w-rr,y);ctx.quadraticCurveTo(x+w,y,x+w,y+rr);ctx.lineTo(x+w,y+h-rr);ctx.quadraticCurveTo(x+w,y+h,x+w-rr,y+h);ctx.lineTo(x+rr,y+h);ctx.quadraticCurveTo(x,y+h,x,y+h-rr);ctx.lineTo(x,y+rr);ctx.quadraticCurveTo(x,y,x+rr,y);ctx.closePath();};
const photo=(ctx,img,x,y,w,h,flip=false)=>{ctx.save();roundedPath(ctx,x,y,w,h,28);ctx.clip();if(img){const k=Math.max(w/img.width,h/img.height),dw=img.width*k,dh=img.height*k;if(flip){ctx.translate(x+w,y);ctx.scale(-1,1);ctx.drawImage(img,(w-dw)/2,(h-dh)/2,dw,dh);}else ctx.drawImage(img,x+(w-dw)/2,y+(h-dh)/2,dw,dh);}ctx.restore();};
export async function generateEventGraphic({event,fight=null,kind='event',format='square'}={}){
 const W=1080,H=format==='story'?1920:1080,canvas=document.createElement('canvas');canvas.width=W;canvas.height=H;const ctx=canvas.getContext('2d');const t=THEMES[event?.tema_visual]||THEMES.fight;
 const g=ctx.createLinearGradient(0,0,W,H);g.addColorStop(0,t.bg);g.addColorStop(.55,'#090b10');g.addColorStop(1,t.accent2);ctx.fillStyle=g;ctx.fillRect(0,0,W,H);
 ctx.globalAlpha=.16;for(let i=-H;i<W;i+=110){ctx.fillStyle=i%220===0?t.accent:'#fff';ctx.save();ctx.translate(i,H*.1);ctx.rotate(-.35);ctx.fillRect(0,0,2,H*1.4);ctx.restore();}ctx.globalAlpha=1;
 const halo=ctx.createRadialGradient(W*.5,H*.42,10,W*.5,H*.42,W*.6);halo.addColorStop(0,t.accent+'55');halo.addColorStop(1,'transparent');ctx.fillStyle=halo;ctx.fillRect(0,0,W,H);
 ctx.fillStyle=t.text;ctx.font='900 34px Arial';ctx.fillText('KOMBAX · EVENTS',70,80);ctx.fillStyle=t.accent;ctx.fillRect(70,104,160,7);
 if(kind==='fight'||kind==='result'){
   const a=await loadBitmap(fight?.a_foto_url),b=await loadBitmap(fight?.b_foto_url);const top=format==='story'?300:220,ph=format==='story'?850:600,pw=W*.43;photo(ctx,a,35,top,pw,ph,false);photo(ctx,b,W-pw-35,top,pw,ph,true);
   ctx.fillStyle=t.text;ctx.textAlign='center';ctx.font='900 86px Arial';ctx.fillText('VS',W/2,top+ph*.52);ctx.textAlign='left';
   const y=top+ph+75;ctx.fillStyle=t.text;fitText(ctx,String(fight?.a_nombre||'PELEADOR A').toUpperCase(),W*.43,52);ctx.fillText(String(fight?.a_nombre||'PELEADOR A').toUpperCase(),45,y);ctx.textAlign='right';fitText(ctx,String(fight?.b_nombre||'PELEADOR B').toUpperCase(),W*.43,52);ctx.fillText(String(fight?.b_nombre||'PELEADOR B').toUpperCase(),W-45,y);ctx.textAlign='left';
   if(kind==='result'){ctx.fillStyle=t.accent;ctx.font='900 44px Arial';ctx.textAlign='center';ctx.fillText('RESULTADO OFICIAL',W/2,y+90);ctx.fillStyle=t.text;ctx.font='800 34px Arial';ctx.fillText(String(fight?.resultado||'Combate finalizado'),W/2,y+140);ctx.textAlign='left';}
 }else{
   ctx.fillStyle=t.text;fitText(ctx,String(event?.nombre||'KOMBAX EVENTO').toUpperCase(),W-140,78);ctx.fillText(String(event?.nombre||'KOMBAX EVENTO').toUpperCase(),70,format==='story'?360:300);ctx.fillStyle=t.muted;ctx.font='700 34px Arial';ctx.fillText(String(event?.resumen||'COMPETE · CONNECT · GROW').slice(0,72),70,format==='story'?430:365);
 }
 const foot=H-115;ctx.fillStyle='rgba(0,0,0,.52)';ctx.fillRect(0,H-165,W,165);ctx.fillStyle=t.text;ctx.font='800 28px Arial';ctx.fillText([event?.lugar_nombre,event?.municipio].filter(Boolean).join(' · ')||'KOMBAX',70,foot);ctx.textAlign='right';ctx.fillStyle=t.accent;ctx.fillText(event?.fecha_inicio?new Intl.DateTimeFormat(kxLocaleTag(kxGetLocale()),{day:'2-digit',month:'short',year:'numeric'}).format(new Date(event.fecha_inicio)).toUpperCase():'PRÓXIMAMENTE',W-70,foot);ctx.textAlign='left';
 const blob=await new Promise((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(new Error('No se pudo generar la imagen.')),'image/png',.95));return new File([blob],`kombax-${kind}-${event?.slug||'evento'}-${format}.png`,{type:'image/png'});
}
export async function shareGraphic(file,{title='KOMBAX Eventos',text='',url=''}={}){if(navigator.share&&navigator.canShare?.({files:[file]})){await navigator.share({files:[file],title,text,url});return 'shared';}const a=document.createElement('a');a.href=URL.createObjectURL(file);a.download=file.name;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),5000);if(url&&navigator.clipboard)await navigator.clipboard.writeText(url).catch(()=>{});return 'downloaded';}
