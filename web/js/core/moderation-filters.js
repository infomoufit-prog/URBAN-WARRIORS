// Calendar bounds use the browser timezone; the server receives a half-open UTC range.
export function moderationDateBounds(period,date){
 if(!period)return {from:null,until:null};
 if(!['day','week'].includes(period)||!/^\d{4}-\d{2}-\d{2}$/.test(date||''))throw new Error('INVALID_DATE');
 const [y,m,d]=date.split('-').map(Number),start=new Date(y,m-1,d);
 if(start.getFullYear()!==y||start.getMonth()!==m-1||start.getDate()!==d)throw new Error('INVALID_DATE');
 if(period==='week')start.setDate(start.getDate()-((start.getDay()+6)%7));
 const end=new Date(start);end.setDate(end.getDate()+(period==='week'?7:1));
 return {from:start.toISOString(),until:end.toISOString()};
}
