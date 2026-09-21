export const summarizeFinance=(rows=[])=>{
  const total_generado=rows.reduce((sum,x)=>sum+Number(x.importe||0),0);
  const total_cobrado=rows.reduce((sum,x)=>sum+Math.min(Number(x.pagado_validado||0),Number(x.importe||0)),0);
  const total_pendiente=rows.reduce((sum,x)=>sum+Number(x.saldo||0),0);
  const total_vencido=rows.reduce((sum,x)=>sum+(x.estado==='vencida'?Number(x.saldo||0):0),0);
  const alumnos_con_deuda=new Set(rows.filter(x=>Number(x.saldo||0)>0).map(x=>x.socio_id).filter(Boolean)).size;
  return {total_generado,total_cobrado,total_pendiente,total_vencido,alumnos_con_deuda,porcentaje_cobro:total_generado>0?100*total_cobrado/total_generado:0};
};

export const groupFinance=(rows,key,order=[])=>{
  const groups=new Map();
  rows.forEach(row=>{const value=String(row[key]??'');if(!groups.has(value))groups.set(value,[]);groups.get(value).push(row)});
  return [...groups.entries()].map(([value,items])=>({value,...summarizeFinance(items)})).sort((a,b)=>{const ai=order.indexOf(a.value),bi=order.indexOf(b.value);if(ai>=0||bi>=0)return (ai<0?999:ai)-(bi<0?999:bi);return Number(a.value)-Number(b.value)});
};
