-- Rollback conservador de 024: retira la capa derivada sin eliminar columnas ni datos.

begin;
drop view if exists public.v_finanzas_metricas_anuales;
drop view if exists public.v_finanzas_metricas_mensuales;
drop view if exists public.v_finanzas_detalle;
drop index if exists public.idx_pagos_club_cuota_validacion;
drop index if exists public.idx_cuotas_club_periodo_origen_estado;
commit;
