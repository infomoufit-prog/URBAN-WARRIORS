import { toast } from '../ui/components.js';

export const CLUB_POSTER_URL='./assets/docs/Cartel_Descarga_KOMBAX_Club.png';

export async function downloadClubPoster(){
  try{
    const response=await fetch(CLUB_POSTER_URL,{cache:'no-store'});if(!response.ok)throw new Error(`POSTER_${response.status}`);
    const blob=await response.blob(),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='KOMBAX_Cartel_Descarga_Club.png';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1500);
  }catch{window.open(CLUB_POSTER_URL,'_blank','noopener,noreferrer');toast('Se ha abierto el cartel para que puedas guardarlo.','error')}
}

export function printClubPoster(){
  const popup=window.open('','_blank','noopener,noreferrer');
  if(!popup){toast('Permite ventanas emergentes para imprimir el cartel.','error');return}
  const src=new URL(CLUB_POSTER_URL,document.baseURI).href;
  popup.document.write(`<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Cartel KOMBAX para clubes</title><style>@page{size:A4 portrait;margin:0}html,body{margin:0;background:#fff}img{display:block;width:210mm;height:297mm;object-fit:contain;margin:auto}</style></head><body><img src="${src}" alt="Cartel KOMBAX para clubes"><script>addEventListener('load',()=>setTimeout(()=>print(),250));<\/script></body></html>`);
  popup.document.close();
}

export function bindClubPosterActions(root=document){
  root.querySelectorAll('[data-club-poster-download]').forEach(button=>button.addEventListener('click',downloadClubPoster));
  root.querySelectorAll('[data-club-poster-print]').forEach(button=>button.addEventListener('click',printClubPoster));
}
