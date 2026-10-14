// The UI is advisory; the Supabase RPC independently enforces all conditions.
export const financeCorrectionRoles=Object.freeze(['direccion','economia']);
export const isFeeVoidable=(fee,linkedPayments=[],linkedReceipts=[],role='')=>Boolean(
 fee?.id&&financeCorrectionRoles.includes(role)&&fee.origen==='cuota'&&
 ['pendiente','vencida'].includes(fee.estado)&&
 !fee.stripe_payment_intent_id&&!fee.pagada_en&&
 !linkedPayments.some(p=>p.cuota_id===fee.id)&&
 !linkedReceipts.some(r=>r.cuota_id===fee.id)
);
export const isHistoricalFinanceFee=fee=>fee?.snapshot_regla?.tipo==='historico_manual';
export const activeFinanceRows=rows=>(rows||[]).filter(row=>!['anulada','cancelada'].includes(row.estado));
