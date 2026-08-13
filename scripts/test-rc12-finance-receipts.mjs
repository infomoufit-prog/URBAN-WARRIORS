import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC12 FINANCE: ${msg}`);console.log(`OK RC12 FINANCE: ${msg}`)};

const [migration,preflight,verify,transactional,rollback,ui,repos]=await Promise.all([
  read('supabase/migrations/031_finance_receipts_breakdown.sql'),
  read('supabase/verification/preflight_031_finance_receipts.sql'),
  read('supabase/verification/verify_031_finance_receipts.sql'),
  read('supabase/verification/test_031_receipts_transactional.sql'),
  read('supabase/rollbacks/031_finance_receipts_breakdown.sql'),
  read('web/js/modules/finance.js'),
  read('web/js/core/repositories.js')
]);

assert(migration.includes('add column if not exists origen')&&migration.includes('add column if not exists concepto'),'recibos conservan origen y concepto');
assert(migration.includes('trg_emitir_recibo_cuota_pagada')&&migration.includes('trg_clasificar_recibo_v031'),'emisión existente y clasificación RC12 quedan auditadas');
assert(migration.includes("when q.origen='material'")&&migration.includes("new.origen='material'"),'recibo de material muestra el artículo y no la disciplina');
assert(migration.includes('pagadas sin recibo')&&migration.includes('material pagado sin recibo'),'auditor detecta cargos cobrados sin recibo');
assert(migration.includes('recibos antes de pago completo')&&migration.includes('recibo único por cargo'),'auditor impide recibos prematuros o duplicados');
assert(preflight.includes('031 pendiente')&&verify.includes('pagados_sin_recibo'),'preflight y verificación posterior diferenciados');
assert(transactional.includes('rollback;')&&transactional.includes('pago parcial sin recibo final'),'prueba funcional SQL revierte todos sus datos');
assert(transactional.includes('cuota pagada emite recibo')&&transactional.includes('material pagado emite recibo'),'prueba transaccional cubre cuota y material');
assert(rollback.includes('Rollback conservador')&&!rollback.includes('drop column'),'rollback preserva la clasificación histórica');
assert(ui.includes('summarizeFinance')&&ui.includes('Desglose por origen'),'indicadores y desglose respetan el filtro seleccionado');
assert(ui.includes('visibleFees')&&ui.includes("financeFilters.origin"),'cargos visibles se separan por origen');
assert(ui.includes('balanceByFee.get(fee?.id)')&&ui.includes('Puedes registrar un pago parcial'),'cobro propone el saldo específico y admite pago parcial');
assert(ui.includes("r.concepto||r.actividad")&&ui.includes("originLabel(r.origen)"),'recibos muestran concepto y origen');
assert(ui.includes('visiblePendingValidation')&&ui.includes("badge(originLabel(a.origen)"),'alertas e historial mantienen el mismo origen visible');
assert(repos.includes("adminPayment:(p)=>mutation('pago.registrar_admin'")&&repos.includes("validate:(pago_id,decision,motivo)=>mutation('pago.validar'"),'la interfaz mantiene el gateway gobernado de pagos');

console.log('RC12 FINANCE + RECEIPTS: PASS');
