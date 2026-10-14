# Fase 3 — Antigüedad, finanzas históricas y anulación segura de cargos

Fecha: 2026-10-14. Base: KOMBAX R120 FIX22 + Fase 0 + Fase 1 + Fase 2. Frontend interno: `2.0.0-rc.13-r118-pilot-stabilization-2` / build 20178. Se conserva intencionadamente el versionado previo hasta coordinar cachés, compilación Android y release.

## Auditoría

- `socios.fecha_alta` ya representa incorporación real al club; puede ser anterior a la cuenta de KOMBAX. La edición está en Mi Club → Alumnos.
- `app_kombax_historical_finance_fix20` ya permite registrar deuda/pago histórico y pausa recordatorios. Mantener esos flujos, no duplicarlos.
- `v_estado_cuenta_socio` y `v_finanzas_detalle` inicialmente calculaban saldo e importe aunque un cargo se anulara. Se modificaron para representar como cero los cargos `anulada/cancelada` sin borrar el importe histórico de `cuotas`.
- Se mantiene el filtrado de informes existente por periodo/año, sin inventar una contabilidad bancaria externa ni agregar un interruptor redundante.

## Implementación fase 3

1. Nueva función `app_kombax_fee_void_r264`: anulación de cargo de cuota administrativa exclusivamente cuando está pendiente o vencido, no tiene pagos de ningún estado, no tiene recibos, no tiene `stripe_payment_intent_id` ni marca `pagada_en`.
2. Autorización exclusivamente mediante `tiene_rol_club` para `direccion` o `economia`; endurecimiento `coalesce(...,false) IS NOT TRUE`. La función se ejecuta como SECURITY DEFINER con `search_path=''` y está revocada a `anon`.
3. Tabla `kombax_fee_void_audit_r264` sin permisos de acceso directo, RLS habilitada. Guarda ID idempotente, club, cargo, usuario, fecha, motivo y valores anteriores, preservando original en `cuotas`.
4. Ninguna eliminación física de `cuotas`, `pagos` o `recibos_cuota`; sin devoluciones bancarias.
5. Vistas `security_invoker` financieras mantienen las columnas originales y representan deuda / importe cero para cargos anulados. Los informes agregados derivan del detalle modificado.
6. Frontend: acción «Anular cargo erróneo» en Finanzas, solo para Dirección/Tesorería y cargos aparentemente elegibles, con motivo obligatorio de 8–500 caracteres. El backend vuelve a validar absolutamente todas las condiciones.
7. Frontend: no ofrece cobros ni recordatorios para cargos anulados; identifica cargos históricos por `snapshot_regla.tipo='historico_manual'` y evita sumarlos a los totales activos si están anulados.
8. Se actualizan cinco módulos en `web`, `dist`, Android y se incorpora una suite de pruebas específica.

## Estado de Supabase comprobado

- Migración aplicada: `20261014110805 kombax_fee_void_audit_r264`.
- Migración adicional de endurecimiento aplicada: `20261014111044 kombax_fee_void_permission_hardening_r264`.
- Función existe. `anon`: EXECUTE false. `authenticated`: EXECUTE true. Guard de permisos que trata NULL como FALSE: confirmado.
- `v_estado_cuenta_socio` y `v_finanzas_detalle`: `security_invoker=true` confirmado.
- Se verificó que ningún estado anulado tenía importe/saldo distinto de cero en las vistas.
- Antes/después de aplicar: 39 cuotas; 0 anulaciones en la nueva tabla. **No se ejecutó ninguna anulación real**.
- La nomenclatura local de scripts `20261014123000_...` y `20261014123500_...` no coincide con los IDs de migración que asigna el servicio. Se documentan ambos; se debe conciliar el mecanismo de migración al futuro deploy del repositorio.

## Calidad

- Fase 3: 49/49 pruebas unitarias y estáticas (no E2E).
- Fase 2: 32/32.
- Fase 1 selector: 26/26; scope finanzas: 17/17.
- Inventario R89: 52/52.
- Estabilización R118, release metadata, sintaxis de módulos JS y mirrors web/dist/Android: PASS.
- Cualquier suite antigua PGlite no ejecutada continúa pendiente: no se infiere su éxito.

## Límites de esta fase

- La **anulación de pagos ya registrados**, sus posibles devoluciones, las rectificaciones de recibos fiscales y la conciliación externa quedan pendientes para una fase específica con reglas contables aprobadas.
- No se probaron cambios reales mediante usuarios piloto autenticados; pruebas negativas del RPC con JWT reales todavía pendientes.
- No se verificó UX visual real en móviles/tablets ni se compiló APK/AAB.
- La interpretación «cobro histórico registrado» no equivale a cobro nuevo, y la exportación o segmentación avanzada por fecha de registro frente a periodo económico aún necesita evaluación contable antes de tocar informes.
- No se realizó GitHub push ni despliegue Netlify. El nuevo frontend no está publicado.
