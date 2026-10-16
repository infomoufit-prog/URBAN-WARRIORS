import owner from './owner-master-r278.json' with {type:'json'};
import master from './usage-help-master-r278.json' with {type:'json'};
export function ownerKnowledge(message:string){
 const normalize=(v:string)=>String(v).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
 const words=normalize(message).split(/\W+/).filter(w=>w.length>3);
 const selected=master.articles.map(a=>({a,score:words.reduce((n,w)=>n+(normalize(a.title+' '+a.meaning).includes(w)?1:0),0)})).filter(x=>x.score>0).sort((a,b)=>b.score-a.score).slice(0,3).map(({a})=>({title:a.title,meaning:a.meaning,checks:a.checks.slice(0,3),rules:a.prerequisites.slice(0,3)}));
 return JSON.stringify({owner:owner.topics,platform:selected});
}
